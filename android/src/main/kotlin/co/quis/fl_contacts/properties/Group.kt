package co.quis.fl_contacts.properties

/** Contact group (iOS) or label (Android). */
data class Group(
    var id: String,
    var name: String
) {

    companion object {
        /** Decodes the model from its channel map. */
        fun fromMap(m: Map<String, Any>): Group = Group(
            m["id"] as String,
            m["name"] as String
        )
    }

    /** Encodes the model for the channel. */
    fun toMap(): Map<String, Any> = mapOf(
        "id" to id,
        "name" to name
    )
}
