import Contacts

@available(iOS 13.0, *)
/// Labeled website URL.
struct Website {
    var url: String
    var label: String = "homepage"
    var customLabel: String = ""

    /// Rebuilds a website from its channel map.
    init(fromMap m: [String: Any]) {
        url = MapDecoding.string(m, "url")
        label = MapDecoding.string(m, "label")
        customLabel = MapDecoding.string(m, "customLabel")
    }

    /// Snapshots a labeled URL value.
    init(fromWebsite w: CNLabeledValue<NSString>) {
        url = w.value as String
        switch w.label {
        case CNLabelHome:
            label = "home"
        case CNLabelURLAddressHomePage:
            label = "homepage"
        case CNLabelWork:
            label = "work"
        case CNLabelOther:
            label = "other"
        default:
            if w.label == CNLabelSchool {
                label = "school"
            } else {
                label = "custom"
                customLabel = w.label ?? ""
            }
        }
    }

    /// Serializes the website.
    func toMap() -> [String: Any] { [
        "url": url,
        "label": label,
        "customLabel": customLabel,
    ]
    }

    /// Appends the URL.
    func addTo(_ c: CNMutableContact) {
        var labelInv: String
        switch label {
        case "home":
            labelInv = CNLabelHome
        case "homepage":
            labelInv = CNLabelURLAddressHomePage
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
        c.urlAddresses.append(
            CNLabeledValue<NSString>(
                label: labelInv,
                value: url as NSString
            )
        )
    }
}
