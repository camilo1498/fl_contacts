package co.quis.fl_contacts.properties

/** Labeled phone number. */
data class Phone(
    var number: String,
    var normalizedNumber: String,
    var label: String = "mobile",
    var customLabel: String,
    var isPrimary: Boolean = false
) {
    companion object {
        /** Decodes the model from its channel map. */
        fun fromMap(m: Map<String, Any>): Phone = Phone(
            m["number"] as String,
            m["normalizedNumber"] as String,
            m["label"] as String,
            m["customLabel"] as String,
            m["isPrimary"] as Boolean
        )
    }

    /** Encodes the model for the channel. */
    fun toMap(): Map<String, Any> = mapOf(
        "number" to number,
        "normalizedNumber" to normalizedNumber,
        "label" to label,
        "customLabel" to customLabel,
        "isPrimary" to isPrimary
    )
}
