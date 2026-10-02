import Contacts
import ContactsUI
import Flutter
import UIKit

@available(iOS 13.0, *)
/// Stateless Contacts-framework operations shared by every entry point.
public enum FlContacts {
    /// Fetches raw `CNContact`s with exactly the keys each flag requires.
    static func selectInternal(
        store: CNContactStore,
        id: String?,
        withProperties: Bool,
        withThumbnail: Bool,
        withPhoto: Bool,
        returnUnifiedContacts: Bool,
        includeNotesOnIos13AndAbove: Bool,
        externalIntent: Bool = false
    ) -> [CNContact] {
        var contacts: [CNContact] = []
        var keys: [Any] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactIdentifierKey,
        ]
        if withProperties {
            keys += [
                CNContactGivenNameKey,
                CNContactFamilyNameKey,
                CNContactMiddleNameKey,
                CNContactNamePrefixKey,
                CNContactNameSuffixKey,
                CNContactNicknameKey,
                CNContactPhoneticGivenNameKey,
                CNContactPhoneticFamilyNameKey,
                CNContactPhoneticMiddleNameKey,
                CNContactPhoneNumbersKey,
                CNContactEmailAddressesKey,
                CNContactPostalAddressesKey,
                CNContactOrganizationNameKey,
                CNContactJobTitleKey,
                CNContactDepartmentNameKey,
                CNContactUrlAddressesKey,
                CNContactSocialProfilesKey,
                CNContactInstantMessageAddressesKey,
                CNContactBirthdayKey,
                CNContactDatesKey,
            ]
            keys.append(CNContactPhoneticOrganizationNameKey)
            if includeNotesOnIos13AndAbove {
                keys.append(CNContactNoteKey)
            }
            if externalIntent {
                keys.append(CNContactViewController.descriptorForRequiredKeys())
            }
        }
        if withThumbnail { keys.append(CNContactThumbnailImageDataKey) }
        if withPhoto { keys.append(CNContactImageDataKey) }

        let request = CNContactFetchRequest(keysToFetch: keys.compactMap { $0 as? CNKeyDescriptor })
        request.unifyResults = returnUnifiedContacts
        if let id = id {
            request.predicate = CNContact.predicateForContacts(withIdentifiers: [id])
        }
        do {
            try store.enumerateContacts(
                with: request, usingBlock: { (contact, _) -> Void in
                    contacts.append(contact)
                }
            )
        } catch {
            print("Unexpected error: \(error)")
            return []
        }

        return contacts
    }

    /// Fetches contacts as channel maps, enriching groups/accounts on demand.
    static func select(
        id: String?,
        withProperties: Bool,
        withThumbnail: Bool,
        withPhoto: Bool,
        withGroups: Bool,
        withAccounts: Bool,
        returnUnifiedContacts: Bool,
        includeNotesOnIos13AndAbove: Bool,
        filter: [String: Any]? = nil,
        limit: Int? = nil
    ) -> [[String: Any?]] {
        let store = CNContactStore()
        // Native predicates cover IDs, group membership and names; phone and
        // email narrow the hydrated result to honor full-match semantics.
        let filterIds = filter?["ids"] as? [String]
        let filterGroup = filter?["groupId"] as? String
        let filterName = filter?["name"] as? String
        let filterPhone = (filter?["phone"] as? String)?.filter { $0.isNumber }
        let filterEmail = filter?["email"] as? String
        let needsHydratedFilter =
            filterPhone?.isEmpty == false || filterEmail?.isEmpty == false
        let contactsInternal: [CNContact]
        if id == nil && filterIds == nil && filterGroup == nil &&
            filterName == nil && !needsHydratedFilter
        {
            contactsInternal = selectInternal(
                store: store,
                id: nil,
                withProperties: withProperties,
                withThumbnail: withThumbnail,
                withPhoto: withPhoto,
                returnUnifiedContacts: returnUnifiedContacts,
                includeNotesOnIos13AndAbove: includeNotesOnIos13AndAbove
            )
        } else {
            contactsInternal = selectFiltered(
                store: store,
                id: id,
                ids: filterIds,
                groupId: filterGroup,
                name: filterName,
                withProperties: withProperties || needsHydratedFilter,
                withThumbnail: withThumbnail,
                withPhoto: withPhoto,
                returnUnifiedContacts: returnUnifiedContacts,
                includeNotesOnIos13AndAbove: includeNotesOnIos13AndAbove
            )
        }
        var contacts = contactsInternal.map { Contact(fromContact: $0) }
        if withGroups || filterGroup != nil {
            let groups = fetchGroups(store)
            let groupMemberships = fetchGroupMemberships(store, groups)
            for (index, contact) in contacts.enumerated() {
                if let contactGroups = groupMemberships[contact.id] {
                    contacts[index].groups = contactGroups.map { Group(fromGroup: groups[$0]) }
                }
            }
        }
        if withAccounts {
            let containers = fetchContainers(store)
            let containerMemberships = fetchContainerMemberships(store, containers)
            for (index, contact) in contacts.enumerated() {
                if let contactContainers = containerMemberships[contact.id] {
                    contacts[index].accounts = contactContainers.map { Account(fromContainer: containers[$0]) }
                }
            }
        }
        var maps = contacts.map { $0.toMap() }
        if let group = filterGroup {
            maps = maps.filter { contact in
                ((contact["groups"] as? [[String: Any]]) ?? []).contains {
                    ($0["id"] as? String) == group
                }
            }
        }
        if let digits = filterPhone, !digits.isEmpty {
            maps = maps.filter { contact in
                ((contact["phones"] as? [[String: Any]]) ?? []).contains {
                    let number = (($0["number"] as? String) ?? "").filter { $0.isNumber }
                    let normalized = (($0["normalizedNumber"] as? String) ?? "").filter { $0.isNumber }
                    return number.contains(digits) || normalized.contains(digits)
                }
            }
        }
        if let email = filterEmail, !email.isEmpty {
            maps = maps.filter { contact in
                ((contact["emails"] as? [[String: Any]]) ?? []).contains {
                    (($0["address"] as? String) ?? "")
                        .localizedCaseInsensitiveContains(email)
                }
            }
        }
        if let limit = limit, limit >= 0, maps.count > limit {
            maps = Array(maps.prefix(limit))
        }
        return maps
    }

    /// Predicate-driven fetch for filtered selects.
    static func selectFiltered(
        store: CNContactStore,
        id: String?,
        ids: [String]?,
        groupId: String?,
        name: String?,
        withProperties: Bool,
        withThumbnail: Bool,
        withPhoto: Bool,
        returnUnifiedContacts: Bool,
        includeNotesOnIos13AndAbove: Bool
    ) -> [CNContact] {
        // One predicate per fetch; the union covers every filter dimension.
        func fetch(predicate: NSPredicate) -> [CNContact] {
            var keys: [Any] = [
                CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                CNContactIdentifierKey,
            ]
            if withProperties {
                keys += [
                    CNContactGivenNameKey,
                    CNContactFamilyNameKey,
                    CNContactMiddleNameKey,
                    CNContactNamePrefixKey,
                    CNContactNameSuffixKey,
                    CNContactNicknameKey,
                    CNContactPhoneticGivenNameKey,
                    CNContactPhoneticFamilyNameKey,
                    CNContactPhoneticMiddleNameKey,
                    CNContactPhoneNumbersKey,
                    CNContactEmailAddressesKey,
                    CNContactPostalAddressesKey,
                    CNContactOrganizationNameKey,
                    CNContactJobTitleKey,
                    CNContactDepartmentNameKey,
                    CNContactUrlAddressesKey,
                    CNContactSocialProfilesKey,
                    CNContactInstantMessageAddressesKey,
                    CNContactBirthdayKey,
                    CNContactDatesKey,
                    CNContactPhoneticOrganizationNameKey,
                ]
                if includeNotesOnIos13AndAbove {
                    keys.append(CNContactNoteKey)
                }
            }
            if withThumbnail { keys.append(CNContactThumbnailImageDataKey) }
            if withPhoto { keys.append(CNContactImageDataKey) }
            let request = CNContactFetchRequest(
                keysToFetch: keys.compactMap { $0 as? CNKeyDescriptor },
            )
            request.unifyResults = returnUnifiedContacts
            request.predicate = predicate
            var found: [CNContact] = []
            do {
                try store.enumerateContacts(
                    with: request,
                    usingBlock: { contact, _ in found.append(contact) },
                )
            } catch {
                print("Unexpected error: \(error)")
            }
            return found
        }
        var all: [CNContact] = []
        if let id = id {
            all += fetch(predicate: CNContact.predicateForContacts(withIdentifiers: [id]))
        }
        if let ids = ids {
            if ids.isEmpty { return [] }
            all += fetch(predicate: CNContact.predicateForContacts(withIdentifiers: ids))
        }
        if let groupId = groupId {
            all += fetch(predicate: CNContact.predicateForContactsInGroup(withIdentifier: groupId))
        }
        if let name = name, !name.isEmpty {
            all += fetch(predicate: CNContact.predicateForContacts(matchingName: name))
        }
        if all.isEmpty { return [] }
        // De-duplicate across predicates, keeping first-seen order.
        var seen = Set<String>()
        return all.filter { seen.insert($0.identifier).inserted }
    }

    /// Returns every group, tolerating store errors with an empty list.
    static func fetchGroups(_ store: CNContactStore) -> [CNGroup] {
        var groups: [CNGroup] = []
        do {
            try groups = store.groups(matching: nil)
        } catch {
            print("Unexpected error: \(error)")
            return []
        }
        return groups
    }

    /// Maps contact IDs to their group indexes via one fetch per group.
    static func fetchGroupMemberships(_ store: CNContactStore, _ groups: [CNGroup], forContactId contactId: String? = nil) -> [String: [Int]] {
        var memberships = [String: [Int]]()
        for (groupIndex, group) in groups.enumerated() {
            let request = CNContactFetchRequest(keysToFetch: [CNContactIdentifierKey] as [CNKeyDescriptor])
            request.predicate = CNContact.predicateForContactsInGroup(withIdentifier: group.identifier)
            do {
                try store.enumerateContacts(with: request) { (contact, _) -> Void in
                    if contactId == nil || contact.identifier == contactId {
                        if let contactGroups = memberships[contact.identifier] {
                            memberships[contact.identifier] = contactGroups + [groupIndex]
                        } else {
                            memberships[contact.identifier] = [groupIndex]
                        }
                    }
                }
            } catch {
                print("Unexpected error: \(error)")
            }
        }
        return memberships
    }

    /// Returns every container, tolerating store errors with an empty list.
    static func fetchContainers(_ store: CNContactStore) -> [CNContainer] {
        var containers: [CNContainer] = []
        do {
            try containers = store.containers(matching: nil)
        } catch {
            print("Unexpected error: \(error)")
            return []
        }
        return containers
    }

    /// Maps contact IDs to their container indexes.
    static func fetchContainerMemberships(_ store: CNContactStore, _ containers: [CNContainer]) -> [String: [Int]] {
        var memberships = [String: [Int]]()
        for (containerIndex, container) in containers.enumerated() {
            let request = CNContactFetchRequest(keysToFetch: [CNContactIdentifierKey] as [CNKeyDescriptor])
            request.predicate = CNContact.predicateForContactsInContainer(withIdentifier: container.identifier)
            do {
                try store.enumerateContacts(with: request) { (contact, _) -> Void in
                    if let contactContainers = memberships[contact.identifier] {
                        memberships[contact.identifier] = contactContainers + [containerIndex]
                    } else {
                        memberships[contact.identifier] = [containerIndex]
                    }
                }
            } catch {
                print("Unexpected error: \(error)")
            }
        }
        return memberships
    }
}
