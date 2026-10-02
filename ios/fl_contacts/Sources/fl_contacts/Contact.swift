import Contacts

@available(iOS 13.0, *)
/// Device contact with channel-map conversion both ways.
struct Contact {
    var id: String = ""
    var displayName: String = ""
    var isStarred: Bool = false
    var name = Name()
    var thumbnail: Data?
    var photo: Data?
    var phones: [Phone] = []
    var emails: [Email] = []
    var addresses: [Address] = []
    var organizations: [Organization] = []
    var websites: [Website] = []
    var socialMedias: [SocialMedia] = []
    var events: [Event] = []
    var notes: [Note] = []
    var accounts: [Account] = []
    var groups: [Group] = []

    /// Rebuilds a contact from its channel map.
    init(fromMap m: [String: Any?]) {
        id = MapDecoding.string(m, "id")
        displayName = MapDecoding.string(m, "displayName")
        name = Name(fromMap: MapDecoding.dictionary(m, "name"))
        thumbnail = MapDecoding.data(m, "thumbnail")
        photo = MapDecoding.data(m, "photo")
        phones = MapDecoding.maps(m, "phones").map { Phone(fromMap: $0) }
        emails = MapDecoding.maps(m, "emails").map { Email(fromMap: $0) }
        addresses = MapDecoding.maps(m, "addresses").map { Address(fromMap: $0) }
        organizations = MapDecoding.maps(m, "organizations").map {
            Organization(fromMap: $0)
        }
        websites = MapDecoding.maps(m, "websites").map { Website(fromMap: $0) }
        socialMedias = MapDecoding.maps(m, "socialMedias").map {
            SocialMedia(fromMap: $0)
        }
        events = MapDecoding.maps(m, "events").map { Event(fromMap: $0) }
        notes = MapDecoding.maps(m, "notes").map { Note(fromMap: $0) }
        accounts = MapDecoding.maps(m, "accounts").map { Account(fromMap: $0) }
        groups = MapDecoding.maps(m, "groups").map { Group(fromMap: $0) }
    }

    /// Snapshots a `CNContact`, reading only keys the fetch requested.
    init(fromContact c: CNContact) {
        id = c.identifier
        displayName = CNContactFormatter.string(
            from: c,
            style: .fullName
        ) ?? ""

        if c.isKeyAvailable(CNContactPhoneticGivenNameKey) {
            name = Name(fromContact: c)
            phones = c.phoneNumbers.map { Phone(fromPhone: $0) }
            emails = c.emailAddresses.map { Email(fromEmail: $0) }
            addresses = c.postalAddresses.map { Address(fromAddress: $0) }
            if !c.organizationName.isEmpty
                || !c.jobTitle.isEmpty
                || !c.departmentName.isEmpty
            {
                organizations = [Organization(fromContact: c)]
            } else if !c.phoneticOrganizationName.isEmpty {
                organizations = [Organization(fromContact: c)]
            }
            websites = c.urlAddresses.map { Website(fromWebsite: $0) }
            socialMedias = c.socialProfiles.map {
                SocialMedia(fromSocialProfile: $0)
            } + c.instantMessageAddresses.map {
                SocialMedia(fromInstantMessage: $0)
            }
            if c.birthday != nil {
                events = [Event(fromContact: c)]
            }
            events += c.dates.map { Event(fromDate: $0) }
            if c.isKeyAvailable(CNContactNoteKey) {
                notes = [Note(fromContact: c)]
            }
        }
        if c.isKeyAvailable(CNContactThumbnailImageDataKey) {
            thumbnail = c.thumbnailImageData
        }
        if c.isKeyAvailable(CNContactImageDataKey) {
            photo = c.imageData
        }
    }

    /// Serializes the contact for the channel.
    func toMap() -> [String: Any?] { [
        "id": id,
        "displayName": displayName,
        "isStarred": isStarred,
        "name": name.toMap(),
        "thumbnail": thumbnail,
        "photo": photo,
        "phones": phones.map { $0.toMap() },
        "emails": emails.map { $0.toMap() },
        "addresses": addresses.map { $0.toMap() },
        "organizations": organizations.map { $0.toMap() },
        "websites": websites.map { $0.toMap() },
        "socialMedias": socialMedias.map { $0.toMap() },
        "events": events.map { $0.toMap() },
        "notes": notes.map { $0.toMap() },
        "accounts": accounts.map { $0.toMap() },
        "groups": groups.map { $0.toMap() },
    ]
    }
}
