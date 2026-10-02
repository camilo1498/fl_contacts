import Contacts

@available(iOS 13.0, *)
/// Create, update and delete operations.
extension FlContacts {
    /// Saves a new contact from its channel map and returns it as stored.
    static func insert(
        _ args: [String: Any?],
        _ includeNotesOnIos13AndAbove: Bool
    ) throws -> [String: Any?] {
        let contact = CNMutableContact()

        addFieldsToContact(args, contact, includeNotesOnIos13AndAbove)

        let saveRequest = CNSaveRequest()
        saveRequest.add(contact, toContainerWithIdentifier: nil)
        try CNContactStore().execute(saveRequest)
        return Contact(fromContact: contact).toMap()
    }

    /// Saves every map sequentially and returns the stored contacts.
    static func insertAll(
        _ list: [[String: Any?]],
        _ includeNotesOnIos13AndAbove: Bool
    ) throws -> [[String: Any?]] {
        try list.map { try insert($0, includeNotesOnIos13AndAbove) }
    }

    /// Rewrites a contact's fields (and optionally group membership).
    static func update(
        _ args: [String: Any?],
        _ withGroups: Bool,
        _ includeNotesOnIos13AndAbove: Bool
    ) throws -> [String: Any?]? {
        guard let id = args["id"] as? String else {
            return nil
        }
        var keys: [Any] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactIdentifierKey,
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
            CNContactThumbnailImageDataKey,
            CNContactImageDataKey,
        ]
        keys.append(CNContactPhoneticOrganizationNameKey)
        if includeNotesOnIos13AndAbove {
            keys.append(CNContactNoteKey)
        }

        let request = CNContactFetchRequest(keysToFetch: keys.compactMap { $0 as? CNKeyDescriptor })
        request.mutableObjects = true
        request.predicate = CNContact.predicateForContacts(withIdentifiers: [id])
        let store = CNContactStore()
        var contacts: [CNContact] = []
        try store.enumerateContacts(with: request, usingBlock: { (contact, _) -> Void in
            contacts.append(contact)
        })

        if let firstContact = contacts.first,
           let contact = firstContact.mutableCopy() as? CNMutableContact {
            clearFields(contact, includeNotesOnIos13AndAbove)
            addFieldsToContact(args, contact, includeNotesOnIos13AndAbove)

            let saveRequest = CNSaveRequest()
            saveRequest.update(contact)
            try store.execute(saveRequest)

            if withGroups {
                let groups = fetchGroups(store)
                let groupMemberships = fetchGroupMemberships(store, groups, forContactId: contact.identifier)
                for groupIndex in groupMemberships[contact.identifier] ?? [] {
                    let deleteRequest = CNSaveRequest()
                    deleteRequest.removeMember(contact, from: groups[groupIndex])
                    try store.execute(deleteRequest)
                }

                let groupIds = Set((args["groups"] as? [[String: Any]] ?? []).map { Group(fromMap: $0).id })
                for group in groups {
                    if groupIds.contains(group.identifier) {
                        let addRequest = CNSaveRequest()
                        addRequest.addMember(contact, to: group)
                        try store.execute(addRequest)
                    }
                }
            }

            return Contact(fromContact: contact).toMap()
        } else {
            return nil
        }
    }

    /// Rewrites every map sequentially and returns the stored contacts.
    static func updateAll(
        _ list: [[String: Any?]],
        _ withGroups: Bool,
        _ includeNotesOnIos13AndAbove: Bool
    ) throws -> [[String: Any?]] {
        try list.compactMap {
            try update($0, withGroups, includeNotesOnIos13AndAbove)
        }
    }

    /// Deletes every listed contact in one save request.
    static func delete(_ ids: [String]) throws {
        let request = CNContactFetchRequest(keysToFetch: [])
        request.mutableObjects = true
        request.predicate = CNContact.predicateForContacts(withIdentifiers: ids)
        let store = CNContactStore()
        var contacts: [CNContact] = []
        try store.enumerateContacts(with: request, usingBlock: { (contact, _) -> Void in
            contacts.append(contact)
        })
        let saveRequest = CNSaveRequest()
        contacts.forEach { contact in
            if let mutableContact = contact.mutableCopy() as? CNMutableContact {
                saveRequest.delete(mutableContact)
            }
        }
        try store.execute(saveRequest)
    }
}
