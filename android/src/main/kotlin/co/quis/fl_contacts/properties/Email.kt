package co.quis.fl_contacts.properties

/** Labeled email address. */
data class Email(
    var address: String,
    var label: String = "home",
    var customLabel: String = "",
    var isPrimary: Boolean = false
) {
    companion object {
        /** Decodes the model from its channel map. */
        fun fromMap(m: Map<String, Any>): Email = Email(
            m["address"] as String,
            m["label"] as String,
            m["customLabel"] as String,
            m["isPrimary"] as Boolean
        )
    }

    /** Encodes the model for the channel. */
    fun toMap(): Map<String, Any> = mapOf(
        "address" to address,
        "label" to label,
        "customLabel" to customLabel,
        "isPrimary" to isPrimary
    )
}
