import Contacts

@available(iOS 13.0, *)
/// Group (label) fetch and mutation.
extension FlContacts {
    /// Returns all groups as channel maps.
    static func getGroups() -> [[String: Any]] {
        let store = CNContactStore()
        let groups = fetchGroups(store)
        return groups.map { Group(fromGroup: $0).toMap() }
    }

    /// Creates a group and returns it with its new identifier.
    static func insertGroup(_ args: [String: Any]) throws -> [String: Any] {
        let group = Group(fromMap: args)
        let newGroup = CNMutableGroup()
        newGroup.name = group.name

        let saveRequest = CNSaveRequest()
        saveRequest.add(newGroup, toContainerWithIdentifier: nil)
        try CNContactStore().execute(saveRequest)

        return Group(fromGroup: newGroup).toMap()
    }

    /// Renames the matching group in place.
    static func updateGroup(_ args: [String: Any]) throws -> [String: Any] {
        let group = Group(fromMap: args)

        let store = CNContactStore()
        let groups = fetchGroups(store)

        for g in groups {
            if g.identifier == group.id,
               let updatedGroup = g.mutableCopy() as? CNMutableGroup {
                updatedGroup.name = group.name

                let saveRequest = CNSaveRequest()
                saveRequest.update(updatedGroup)
                try CNContactStore().execute(saveRequest)

                return Group(fromGroup: updatedGroup).toMap()
            }
        }

        return args
    }

    /// Deletes the matching group.
    static func deleteGroup(_ args: [String: Any]) throws {
        let group = Group(fromMap: args)

        let store = CNContactStore()
        let groups = fetchGroups(store)

        for g in groups {
            if g.identifier == group.id,
               let deletedGroup = g.mutableCopy() as? CNMutableGroup {

                let saveRequest = CNSaveRequest()
                saveRequest.delete(deletedGroup)
                try CNContactStore().execute(saveRequest)

                return
            }
        }
    }

    /// Adds contacts to a group without touching the contacts themselves.
    static func addContactsToGroup(groupId: String, contactIds: [String]) throws {
        let store = CNContactStore()
        let indexed = try fetchUnifiedContacts(store: store, ids: contactIds)
        guard let group = fetchGroups(store).first(where: { $0.identifier == groupId }) else {
            return
        }
        let saveRequest = CNSaveRequest()
        for contact in indexed {
            saveRequest.addMember(contact, to: group)
        }
        try store.execute(saveRequest)
    }

    /// Removes contacts from a group.
    static func removeContactsFromGroup(groupId: String, contactIds: [String]) throws {
        let store = CNContactStore()
        let indexed = try fetchUnifiedContacts(store: store, ids: contactIds)
        guard let group = fetchGroups(store).first(where: { $0.identifier == groupId }) else {
            return
        }
        let saveRequest = CNSaveRequest()
        for contact in indexed {
            saveRequest.removeMember(contact, from: group)
        }
        try store.execute(saveRequest)
    }

    /// Returns the groups a contact belongs to as channel maps.
    static func getGroupsOf(contactId: String) -> [[String: Any]] {
        let store = CNContactStore()
        let groups = fetchGroups(store)
        let memberships = fetchGroupMemberships(store, groups, forContactId: contactId)
        return (memberships[contactId] ?? []).map { Group(fromGroup: groups[$0]).toMap() }
    }

    /// Fetches mutable contacts for IDs, skipping missing ones.
    static func fetchUnifiedContacts(store: CNContactStore, ids: [String]) throws -> [CNMutableContact] {
        let request = CNContactFetchRequest(keysToFetch: [CNContactIdentifierKey] as [CNKeyDescriptor])
        request.mutableObjects = true
        request.predicate = CNContact.predicateForContacts(withIdentifiers: ids)
        var found: [CNContact] = []
        try store.enumerateContacts(with: request, usingBlock: { contact, _ in
            found.append(contact)
        })
        return found.compactMap { $0.mutableCopy() as? CNMutableContact }
    }
}
