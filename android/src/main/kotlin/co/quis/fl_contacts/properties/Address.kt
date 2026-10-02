package co.quis.fl_contacts.properties

/** Postal address with formatted text plus structured parts. */
data class Address(
    var address: String,
    var label: String = "home",
    var customLabel: String = "",
    var street: String = "",
    var pobox: String = "",
    var neighborhood: String = "",
    var city: String = "",
    var state: String = "",
    var postalCode: String = "",
    var country: String = "",
    var isoCountry: String = "",
    var subAdminArea: String = "",
    var subLocality: String = ""
) {

    companion object {
        /** Decodes the model from its channel map. */
        fun fromMap(m: Map<String, Any>): Address = Address(
            m["address"] as String,
            m["label"] as String,
            m["customLabel"] as String,
            m["street"] as String,
            m["pobox"] as String,
            m["neighborhood"] as String,
            m["city"] as String,
            m["state"] as String,
            m["postalCode"] as String,
            m["country"] as String,
            m["isoCountry"] as String,
            m["subAdminArea"] as String,
            m["subLocality"] as String
        )
    }

    /** Encodes the model for the channel. */
    fun toMap(): Map<String, Any> = mapOf(
        "address" to address,
        "label" to label,
        "customLabel" to customLabel,
        "street" to street,
        "pobox" to pobox,
        "neighborhood" to neighborhood,
        "city" to city,
        "state" to state,
        "postalCode" to postalCode,
        "country" to country,
        "isoCountry" to isoCountry,
        "subAdminArea" to subAdminArea,
        "subLocality" to subLocality
    )
}
