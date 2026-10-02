package co.quis.fl_contacts.properties

/** Labeled date such as a birthday or anniversary. */
data class Event(
    var year: Int?,
    var month: Int,
    var day: Int,
    var label: String = "birthday",
    var customLabel: String = ""
) {
    companion object {
        /** Decodes the model from its channel map. */
        fun fromMap(m: Map<String, Any?>): Event = Event(
            m["year"] as Int?,
            m["month"] as Int,
            m["day"] as Int,
            m["label"] as String,
            m["customLabel"] as String
        )
    }

    /** Encodes the model for the channel. */
    fun toMap(): Map<String, Any?> = mapOf(
        "year" to year,
        "month" to month,
        "day" to day,
        "label" to label,
        "customLabel" to customLabel
    )
}
