import Contacts

@available(macOS 10.15, *)
/// Free-form note text.
struct Note {
    var note: String

    /// Rebuilds a note from its channel map.
    init(fromMap m: [String: Any]) {
        note = MapDecoding.string(m, "note")
    }

    /// Snapshots the note when its key was fetched.
    init(fromContact c: CNContact) {
        note = c.note
    }

    /// Serializes the note.
    func toMap() -> [String: Any] { [
        "note": note,
    ]
    }

    /// Writes the note.
    func addTo(_ c: CNMutableContact) {
        c.note = note
    }
}
