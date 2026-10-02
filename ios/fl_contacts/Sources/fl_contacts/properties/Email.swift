import Contacts

@available(iOS 13.0, *)
/// Labeled email address.
struct Email {
    var address: String
    var label: String = "home"
    var customLabel: String = ""
    var isPrimary: Bool = false

    /// Rebuilds an email from its channel map.
    init(fromMap m: [String: Any]) {
        address = MapDecoding.string(m, "address")
        label = MapDecoding.string(m, "label")
        customLabel = MapDecoding.string(m, "customLabel")
        isPrimary = MapDecoding.bool(m, "isPrimary")
    }

    /// Snapshots a labeled email value.
    init(fromEmail e: CNLabeledValue<NSString>) {
        address = e.value as String
        switch e.label {
        case CNLabelHome:
            label = "home"
        case CNLabelEmailiCloud:
            label = "iCloud"
        case CNLabelWork:
            label = "work"
        case CNLabelOther:
            label = "other"
        default:
            if e.label == CNLabelSchool {
                label = "school"
            } else {
                label = "custom"
                customLabel = e.label ?? ""
            }
        }
    }

    /// Serializes the email.
    func toMap() -> [String: Any] { [
        "address": address,
        "label": label,
        "customLabel": customLabel,
        "isPrimary": isPrimary,
    ]
    }

    /// Appends the email address.
    func addTo(_ c: CNMutableContact) {
        var labelInv: String
        switch label {
        case "home":
            labelInv = CNLabelHome
        case "iCloud":
            labelInv = CNLabelEmailiCloud
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
        c.emailAddresses.append(
            CNLabeledValue<NSString>(
                label: labelInv,
                value: address as NSString
            )
        )
    }
}
