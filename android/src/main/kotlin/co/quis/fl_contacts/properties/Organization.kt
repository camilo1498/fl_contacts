package co.quis.fl_contacts.properties

/** Employer or affiliation with an optional job title. */
data class Organization(
    var company: String = "",
    var title: String = "",
    var department: String = "",
    var jobDescription: String = "",
    var symbol: String = "",
    var phoneticName: String = "",
    var officeLocation: String = ""
) {
    companion object {
        /** Decodes the model from its channel map. */
        fun fromMap(m: Map<String, Any>): Organization = Organization(
            m["company"] as String,
            m["title"] as String,
            m["department"] as String,
            m["jobDescription"] as String,
            m["symbol"] as String,
            m["phoneticName"] as String,
            m["officeLocation"] as String
        )
    }

    /** Encodes the model for the channel. */
    fun toMap(): Map<String, Any> = mapOf(
        "company" to company,
        "title" to title,
        "department" to department,
        "jobDescription" to jobDescription,
        "symbol" to symbol,
        "phoneticName" to phoneticName,
        "officeLocation" to officeLocation
    )
}
