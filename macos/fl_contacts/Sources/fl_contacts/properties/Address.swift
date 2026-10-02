import Contacts

@available(macOS 10.15, *)
/// Postal address with formatted and structured parts.
struct Address {
    var address: String
    var label: String = "home"
    var customLabel: String = ""
    var street: String = ""
    var pobox: String = ""
    var neighborhood: String = ""
    var city: String = ""
    var state: String = ""
    var postalCode: String = ""
    var country: String = ""
    var isoCountry: String = ""
    var subAdminArea: String = ""
    var subLocality: String = ""

    /// Rebuilds an address from its channel map.
    init(fromMap m: [String: Any]) {
        address = MapDecoding.string(m, "address")
        label = MapDecoding.string(m, "label")
        customLabel = MapDecoding.string(m, "customLabel")
        street = MapDecoding.string(m, "street")
        pobox = MapDecoding.string(m, "pobox")
        neighborhood = MapDecoding.string(m, "neighborhood")
        city = MapDecoding.string(m, "city")
        state = MapDecoding.string(m, "state")
        postalCode = MapDecoding.string(m, "postalCode")
        country = MapDecoding.string(m, "country")
        isoCountry = MapDecoding.string(m, "isoCountry")
        subAdminArea = MapDecoding.string(m, "subAdminArea")
        subLocality = MapDecoding.string(m, "subLocality")
    }

    /// Snapshots a postal address with a thread-local formatter.
    init(fromAddress a: CNLabeledValue<CNPostalAddress>) {
        address = CNPostalAddressFormatter().string(from: a.value)
        switch a.label {
        case CNLabelHome:
            label = "home"
        case CNLabelWork:
            label = "work"
        case CNLabelOther:
            label = "other"
        default:
            if a.label == CNLabelSchool {
                label = "school"
            } else {
                label = "custom"
                customLabel = a.label ?? ""
            }
        }
        street = a.value.street
        city = a.value.city
        state = a.value.state
        postalCode = a.value.postalCode
        country = a.value.country
        isoCountry = a.value.isoCountryCode
        subAdminArea = a.value.subAdministrativeArea
        subLocality = a.value.subLocality
    }

    /// Serializes the address.
    func toMap() -> [String: Any] { [
        "address": address,
        "label": label,
        "customLabel": customLabel,
        "street": street,
        "pobox": pobox,
        "neighborhood": neighborhood,
        "city": city,
        "state": state,
        "postalCode": postalCode,
        "country": country,
        "isoCountry": isoCountry,
        "subAdminArea": subAdminArea,
        "subLocality": subLocality,
    ]
    }

    /// Appends the address, falling back to the street field.
    func addTo(_ c: CNMutableContact) {
        let mutableAddress = CNMutablePostalAddress()
        var isAnyFieldPresent = false
        if !street.isEmpty {
            mutableAddress.street = street
            isAnyFieldPresent = true
        }
        if !city.isEmpty {
            mutableAddress.city = city
            isAnyFieldPresent = true
        }
        if !state.isEmpty {
            mutableAddress.state = state
            isAnyFieldPresent = true
        }
        if !postalCode.isEmpty {
            mutableAddress.postalCode = postalCode
            isAnyFieldPresent = true
        }
        if !country.isEmpty {
            mutableAddress.country = country
            isAnyFieldPresent = true
        }
        if !isoCountry.isEmpty {
            mutableAddress.isoCountryCode = isoCountry
            isAnyFieldPresent = true
        }
        if !subAdminArea.isEmpty {
            mutableAddress.subAdministrativeArea = subAdminArea
            isAnyFieldPresent = true
        }
        if !subLocality.isEmpty {
            mutableAddress.subLocality = subLocality
            isAnyFieldPresent = true
        }
        if !isAnyFieldPresent {
            mutableAddress.street = address
        }
        var labelInv: String
        switch label {
        case "home":
            labelInv = CNLabelHome
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
        c.postalAddresses.append(
            CNLabeledValue<CNPostalAddress>(
                label: labelInv,
                value: mutableAddress
            )
        )
    }
}
