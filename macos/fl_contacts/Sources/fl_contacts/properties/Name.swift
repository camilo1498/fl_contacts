import Contacts

@available(macOS 10.15, *)
/// Structured name parts.
struct Name {
    var first: String = ""
    var last: String = ""
    var middle: String = ""
    var prefix: String = ""
    var suffix: String = ""
    var nickname: String = ""
    var firstPhonetic: String = ""
    var lastPhonetic: String = ""
    var middlePhonetic: String = ""

    init() {}

    /// Rebuilds a name from its channel map.
    init(fromMap m: [String: Any]) {
        first = MapDecoding.string(m, "first")
        last = MapDecoding.string(m, "last")
        middle = MapDecoding.string(m, "middle")
        prefix = MapDecoding.string(m, "prefix")
        suffix = MapDecoding.string(m, "suffix")
        nickname = MapDecoding.string(m, "nickname")
        firstPhonetic = MapDecoding.string(m, "firstPhonetic")
        lastPhonetic = MapDecoding.string(m, "lastPhonetic")
        middlePhonetic = MapDecoding.string(m, "middlePhonetic")
    }

    /// Snapshots the name keys of a contact.
    init(fromContact c: CNContact) {
        first = c.givenName
        last = c.familyName
        middle = c.middleName
        prefix = c.namePrefix
        suffix = c.nameSuffix
        nickname = c.nickname
        firstPhonetic = c.phoneticGivenName
        lastPhonetic = c.phoneticFamilyName
        middlePhonetic = c.phoneticMiddleName
    }

    /// Serializes the name.
    func toMap() -> [String: Any] { [
        "first": first,
        "last": last,
        "middle": middle,
        "prefix": prefix,
        "suffix": suffix,
        "nickname": nickname,
        "firstPhonetic": firstPhonetic,
        "lastPhonetic": lastPhonetic,
        "middlePhonetic": middlePhonetic,
    ]
    }

    /// Writes every name part.
    func addTo(_ c: CNMutableContact) {
        c.givenName = first
        c.familyName = last
        c.middleName = middle
        c.namePrefix = prefix
        c.nameSuffix = suffix
        c.nickname = nickname
        c.phoneticGivenName = firstPhonetic
        c.phoneticFamilyName = lastPhonetic
        c.phoneticMiddleName = middlePhonetic
    }
}
