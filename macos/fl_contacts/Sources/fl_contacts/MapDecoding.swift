import Contacts

@available(macOS 10.15, *)
/// Total channel-map readers.
///
/// The channel contract guarantees complete maps, but a missing or mistyped
/// entry must degrade to a documented default instead of trapping the host
/// app, so every reader below is conditional.
enum MapDecoding {
    /// Reads a string field, defaulting to empty.
    static func string(_ map: [String: Any?], _ key: String) -> String {
        map[key] as? String ?? ""
    }

    /// Reads an integer field, defaulting to [fallback].
    static func int(_ map: [String: Any?], _ key: String, fallback: Int) -> Int {
        map[key] as? Int ?? fallback
    }

    /// Reads a boolean field, defaulting to false.
    static func bool(_ map: [String: Any?], _ key: String) -> Bool {
        map[key] as? Bool ?? false
    }

    /// Reads a nested dictionary, defaulting to empty.
    static func dictionary(_ map: [String: Any?], _ key: String) -> [String: Any] {
        map[key] as? [String: Any] ?? [:]
    }

    /// Reads a list of nested dictionaries, defaulting to empty.
    static func maps(_ map: [String: Any?], _ key: String) -> [[String: Any]] {
        if let typed = map[key] as? [[String: Any]] {
            return typed
        }
        if let optional = map[key] as? [[String: Any?]] {
            return optional.map { $0.compactMapValues { $0 } }
        }
        return []
    }

    /// Reads optional binary data, defaulting to nil.
    static func data(_ map: [String: Any?], _ key: String) -> Data? {
        map[key] as? Data
    }
}
