import Contacts
import FlutterMacOS

@available(macOS 10.15, *)
/// Channel-map to contact field mapping.
extension FlContacts {
    /// Resets mutable state before an update rewrite (except notes w/o flag).
    static func clearFields(
        _ contact: CNMutableContact,
        _ includeNotesOnIos13AndAbove: Bool
    ) {
        contact.imageData = nil
        contact.phoneNumbers = []
        contact.emailAddresses = []
        contact.postalAddresses = []
        contact.urlAddresses = []
        contact.socialProfiles = []
        contact.instantMessageAddresses = []
        contact.dates = []
        contact.birthday = nil
        if includeNotesOnIos13AndAbove {
            contact.note = ""
        }
    }

    /// Applies a channel map onto a mutable contact; absent lists are skipped.
    static func addFieldsToContact(
        _ args: [String: Any?],
        _ contact: CNMutableContact,
        _ includeNotesOnIos13AndAbove: Bool
    ) {
        if let name = args["name"] as? [String: Any] {
            Name(fromMap: name).addTo(contact)
        }
        ((args["phones"] as? [[String: Any]]) ?? []).forEach {
            Phone(fromMap: $0).addTo(contact)
        }
        ((args["emails"] as? [[String: Any]]) ?? []).forEach {
            Email(fromMap: $0).addTo(contact)
        }
        ((args["addresses"] as? [[String: Any]]) ?? []).forEach {
            Address(fromMap: $0).addTo(contact)
        }
        if let organization = ((args["organizations"] as? [[String: Any]]) ?? []).first {
            Organization(fromMap: organization).addTo(contact)
        }
        ((args["websites"] as? [[String: Any]]) ?? []).forEach {
            Website(fromMap: $0).addTo(contact)
        }
        ((args["socialMedias"] as? [[String: Any]]) ?? []).forEach {
            SocialMedia(fromMap: $0).addTo(contact)
        }
        ((args["events"] as? [[String: Any]]) ?? []).forEach {
            Event(fromMap: $0).addTo(contact)
        }
        if includeNotesOnIos13AndAbove {
            if let note = ((args["notes"] as? [[String: Any]]) ?? []).first {
                Note(fromMap: note).addTo(contact)
            }
        }
        if let photo = args["photo"] as? FlutterStandardTypedData {
            contact.imageData = photo.data
        }
    }
}
