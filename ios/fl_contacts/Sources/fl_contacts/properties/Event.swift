import Contacts

@available(iOS 13.0, *)
/// Labeled date with an optional year.
struct Event {
    var year: Int?
    var month: Int
    var day: Int
    var label: String = "birthday"
    var customLabel: String = ""

    /// Rebuilds an event from its channel map.
    init(fromMap m: [String: Any?]) {
        year = m["year"] as? Int
        month = MapDecoding.int(m, "month", fallback: 1)
        day = MapDecoding.int(m, "day", fallback: 1)
        label = MapDecoding.string(m, "label")
        customLabel = MapDecoding.string(m, "customLabel")
    }

    /// Snapshots the birthday, discarding sentinel no-year values.
    init(fromContact c: CNContact) {
        guard let birthday = c.birthday else {
            month = 1
            day = 1
            label = "birthday"
            return
        }
        let y = birthday.year
        year = (y == nil || y! < -100_000 || y! > 100_000) ? nil : y
        month = birthday.month ?? 1
        day = birthday.day ?? 1
        label = "birthday"
    }

    /// Snapshots a labeled date value.
    init(fromDate d: CNLabeledValue<NSDateComponents>) {
        let y = d.value.year
        year = (y < -100_000 || y > 100_000) ? nil : y
        month = d.value.month
        day = d.value.day
        switch d.label {
        case CNLabelDateAnniversary:
            label = "anniversary"
        case CNLabelOther:
            label = "other"
        default:
            label = "custom"
            customLabel = d.label ?? ""
        }
    }

    /// Serializes the event.
    func toMap() -> [String: Any?] { [
        "year": year,
        "month": month,
        "day": day,
        "label": label,
        "customLabel": customLabel,
    ]
    }

    /// Writes birthdays or labeled dates.
    func addTo(_ c: CNMutableContact) {
        var dateComponents: DateComponents
        if year == nil {
            dateComponents = DateComponents(month: month, day: day)
        } else {
            dateComponents = DateComponents(year: year, month: month, day: day)
        }
        if label == "birthday" {
            c.birthday = dateComponents
        } else {
            var labelInv: String
            switch label {
            case "anniversary":
                labelInv = CNLabelDateAnniversary
            case "other":
                labelInv = CNLabelOther
            case "custom":
                labelInv = customLabel
            default:
                labelInv = label
            }
            c.dates.append(
                CNLabeledValue(
                    label: labelInv,
                    value: dateComponents as NSDateComponents
                )
            )
        }
    }
}
