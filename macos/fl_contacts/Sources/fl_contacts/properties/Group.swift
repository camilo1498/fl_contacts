import Contacts

@available(macOS 10.15, *)
/// Contact group reference.
struct Group {
    var id: String
    var name: String

    /// Rebuilds a group from its channel map.
    init(fromMap m: [String: Any]) {
        id = MapDecoding.string(m, "id")
        name = MapDecoding.string(m, "name")
    }

    /// Snapshots a store group.
    init(fromGroup g: CNGroup) {
        id = g.identifier
        name = g.name
    }

    /// Serializes the group.
    func toMap() -> [String: Any] { [
        "id": id,
        "name": name,
    ]
    }
}
