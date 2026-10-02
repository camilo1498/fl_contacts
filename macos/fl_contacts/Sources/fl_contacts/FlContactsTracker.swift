import Contacts
import FlutterMacOS
import Foundation

@available(macOS 10.15, *)
/// Emits per-contact diffs (`added`/`updated`/`removed` + IDs) to Dart.
///
/// The store only signals *that* something changed, so this tracker keeps a
/// fingerprint snapshot, debounces bursts for 300 ms, then reports the delta.
/// Fingerprints skip photo bytes: re-fetching images on every keystroke would
/// defeat a lightweight listener.
class FlContactsTracker {
    private let sink: FlutterEventSink
    private var baseline: [String: Int] = [:]
    private var pendingWork: DispatchWorkItem?
    private var observer: NSObjectProtocol?
    private let queue = DispatchQueue(
        label: "co.quis.fl_contacts.tracker",
        qos: .utility,
    )

    /// Creates a tracker bound to an event sink.
    init(sink: @escaping FlutterEventSink) {
        self.sink = sink
    }

    /// Snapshots the current state and starts observing.
    func start() {
        queue.async { [weak self] in
            self?.baseline = Self.snapshot()
        }
        observer = NotificationCenter.default.addObserver(
            forName: .CNContactStoreDidChange,
            object: nil,
            queue: nil,
        ) { [weak self] _ in
            self?.schedule()
        }
    }

    /// Stops observing and drops pending work.
    func stop() {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
        pendingWork?.cancel()
        pendingWork = nil
    }

    private func schedule() {
        pendingWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.diffAndEmit()
        }
        pendingWork = work
        queue.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    /// Content fingerprint: identity plus every scalar property.
    static func fingerprint(_ contact: [String: Any?]) -> Int {
        var hasher = Hasher()
        hasher.combine(contact["id"] as? String ?? "")
        hasher.combine(contact["displayName"] as? String ?? "")
        hasher.combine(contact["isStarred"] as? Bool ?? false)
        for key in ["name", "phones", "emails", "addresses", "organizations",
                    "websites", "socialMedias", "events", "notes", "groups"] {
            hasher.combine(String(describing: contact[key] ?? "nil"))
        }
        return hasher.finalize()
    }

    /// Reads the current fingerprint snapshot.
    static func snapshot() -> [String: Int] {
        let maps = FlContacts.select(
            id: nil,
            withProperties: true,
            withThumbnail: false,
            withPhoto: false,
            withGroups: true,
            withAccounts: false,
            returnUnifiedContacts: true,
            includeNotesOnIos13AndAbove: false,
        )
        var out: [String: Int] = [:]
        for map in maps {
            guard let id = map["id"] as? String, !id.isEmpty else { continue }
            out[id] = fingerprint(map)
        }
        return out
    }

    private func diffAndEmit() {
        let current = Self.snapshot()
        var changes: [[String: String]] = []
        for (id, hash) in current {
            if baseline[id] == nil {
                changes.append(["type": "added", "contactId": id])
            } else if baseline[id] != hash {
                changes.append(["type": "updated", "contactId": id])
            }
        }
        for id in baseline.keys where current[id] == nil {
            changes.append(["type": "removed", "contactId": id])
        }
        baseline = current
        if !changes.isEmpty {
            let payload = changes
            DispatchQueue.main.async { [sink] in
                sink(payload)
            }
        }
    }
}
