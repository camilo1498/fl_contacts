import Contacts

@available(iOS 13.0, *)
/// Labeled phone number.
struct Phone {
    var number: String
    var normalizedNumber: String
    var label: String = "mobile"
    var customLabel: String = ""
    var isPrimary: Bool = false

    /// Rebuilds a phone from its channel map.
    init(fromMap m: [String: Any]) {
        number = MapDecoding.string(m, "number")
        normalizedNumber = MapDecoding.string(m, "normalizedNumber")
        label = MapDecoding.string(m, "label")
        customLabel = MapDecoding.string(m, "customLabel")
        isPrimary = MapDecoding.bool(m, "isPrimary")
    }

    /// Snapshots a labeled phone value.
    init(fromPhone p: CNLabeledValue<CNPhoneNumber>) {
        number = p.value.stringValue
        normalizedNumber = ""
        switch p.label {
        case CNLabelPhoneNumberHomeFax:
            label = "faxHome"
        case CNLabelPhoneNumberOtherFax:
            label = "faxOther"
        case CNLabelPhoneNumberWorkFax:
            label = "faxWork"
        case CNLabelHome:
            label = "home"
        case CNLabelPhoneNumberiPhone:
            label = "iPhone"
        case CNLabelPhoneNumberMain:
            label = "main"
        case CNLabelPhoneNumberMobile:
            label = "mobile"
        case CNLabelPhoneNumberPager:
            label = "pager"
        case CNLabelWork:
            label = "work"
        case CNLabelOther:
            label = "other"
        default:
            if p.label == CNLabelSchool {
                label = "school"
            } else {
                label = "custom"
                customLabel = p.label ?? ""
            }
        }
    }

    /// Serializes the phone.
    func toMap() -> [String: Any] { [
        "number": number,
        "normalizedNumber": normalizedNumber,
        "label": label,
        "customLabel": customLabel,
        "isPrimary": isPrimary,
    ]
    }

    /// Appends the phone number.
    func addTo(_ c: CNMutableContact) {
        var labelInv: String
        switch label {
        case "faxHome":
            labelInv = CNLabelPhoneNumberHomeFax
        case "faxOther":
            labelInv = CNLabelPhoneNumberOtherFax
        case "faxWork":
            labelInv = CNLabelPhoneNumberWorkFax
        case "home":
            labelInv = CNLabelHome
        case "iPhone":
            labelInv = CNLabelPhoneNumberiPhone
        case "main":
            labelInv = CNLabelPhoneNumberMain
        case "mobile":
            labelInv = CNLabelPhoneNumberMobile
        case "pager":
            labelInv = CNLabelPhoneNumberPager
        case "school":
            labelInv = CNLabelSchool
        case "work":
            labelInv = CNLabelWork
        case "other":
            labelInv = CNLabelOther
        case "custom":
            labelInv = customLabel
        default:
            labelInv = label
        }
        c.phoneNumbers.append(
            CNLabeledValue<CNPhoneNumber>(
                label: labelInv,
                value: CNPhoneNumber(stringValue: number)
            )
        )
    }
}
