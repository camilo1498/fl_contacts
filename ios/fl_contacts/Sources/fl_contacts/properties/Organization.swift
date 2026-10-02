import Contacts

@available(iOS 13.0, *)
/// Employer with an optional job title.
struct Organization {
    var company: String = ""
    var title: String = ""
    var department: String = ""
    var jobDescription: String = ""
    var symbol: String = ""
    var phoneticName: String = ""
    var officeLocation: String = ""

    /// Rebuilds an organization from its channel map.
    init(fromMap m: [String: Any]) {
        company = MapDecoding.string(m, "company")
        title = MapDecoding.string(m, "title")
        department = MapDecoding.string(m, "department")
        jobDescription = MapDecoding.string(m, "jobDescription")
        symbol = MapDecoding.string(m, "symbol")
        phoneticName = MapDecoding.string(m, "phoneticName")
        officeLocation = MapDecoding.string(m, "officeLocation")
    }

    /// Snapshots company, title, department and phonetic name.
    init(fromContact c: CNContact) {
        company = c.organizationName
        title = c.jobTitle
        department = c.departmentName
        phoneticName = c.phoneticOrganizationName
    }

    /// Serializes the organization.
    func toMap() -> [String: Any] { [
        "company": company,
        "title": title,
        "department": department,
        "jobDescription": jobDescription,
        "symbol": symbol,
        "phoneticName": phoneticName,
        "officeLocation": officeLocation,
    ]
    }

    /// Writes the organization fields.
    func addTo(_ c: CNMutableContact) {
        c.organizationName = company
        c.jobTitle = title
        c.departmentName = department
        c.phoneticOrganizationName = phoneticName
    }
}
