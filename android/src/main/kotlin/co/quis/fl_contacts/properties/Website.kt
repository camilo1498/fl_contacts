package co.quis.fl_contacts.properties

/** Labeled website URL. */
data class Website(
    var url: String,
    var label: String = "homepage",
    var customLabel: String = ""
) {
    companion object {
        /** Decodes the model from its channel map. */
        fun fromMap(m: Map<String, Any>): Website = Website(
            m["url"] as String,
            m["label"] as String,
            m["customLabel"] as String
        )
    }

    /** Encodes the model for the channel. */
    fun toMap(): Map<String, Any> = mapOf(
        "url" to url,
        "label" to label,
        "customLabel" to customLabel
    )
}
