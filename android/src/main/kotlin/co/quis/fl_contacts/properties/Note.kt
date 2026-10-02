package co.quis.fl_contacts.properties

/** Free-form note text. */
data class Note(
    var note: String
) {
    companion object {
        /** Decodes the model from its channel map. */
        fun fromMap(m: Map<String, Any>): Note = Note(m["note"] as String)
    }

    /** Encodes the model for the channel. */
    fun toMap(): Map<String, Any> = mapOf("note" to note)
}
