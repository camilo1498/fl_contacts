package co.quis.fl_contacts.properties

/** Instant-messaging or social profile. */
data class SocialMedia(
    var userName: String,
    var label: String = "other",
    var customLabel: String = ""
) {
    companion object {
        /** Decodes the model from its channel map. */
        fun fromMap(m: Map<String, Any>): SocialMedia = SocialMedia(
            m["userName"] as String,
            m["label"] as String,
            m["customLabel"] as String
        )
    }

    /** Encodes the model for the channel. */
    fun toMap(): Map<String, Any> = mapOf(
        "userName" to userName,
        "label" to label,
        "customLabel" to customLabel
    )
}
