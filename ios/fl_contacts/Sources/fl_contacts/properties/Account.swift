import Contacts

@available(iOS 13.0, *)
/// Raw account or container behind a contact.
struct Account {
    var rawId: String
    var type: String
    var name: String

    /// Rebuilds an account from its channel map.
    init(fromMap m: [String: Any]) {
        rawId = MapDecoding.string(m, "rawId")
        type = MapDecoding.string(m, "type")
        name = MapDecoding.string(m, "name")
    }

    /// Snapshots a store container.
    init(fromContainer c: CNContainer) {
        rawId = c.identifier
        name = c.name
        switch c.type {
        case .local:
            type = "local"
        case .exchange:
            type = "exchange"
        case .cardDAV:
            type = "cardDAV"
        case .unassigned:
            type = "unassigned"
        default:
            type = "unassigned"
        }
    }

    /// Serializes the account.
    func toMap() -> [String: Any] { [
        "rawId": rawId,
        "type": type,
        "name": name,
        "mimetypes": [String](),
    ]
    }
}
