package co.quis.fl_contacts.properties

/** Raw sync account (Android) or container (iOS) backing a contact. */
data class Account(
    var rawId: String,
    var type: String,
    var name: String,
    var mimetypes: List<String> = listOf<String>()
) {

    companion object {
        /** Decodes the model from its channel map. */
        fun fromMap(m: Map<String, Any>): Account = Account(
            m["rawId"] as String,
            m["type"] as String,
            m["name"] as String,
            m["mimetypes"] as List<String>
        )
    }

    /** Encodes the model for the channel. */
    fun toMap(): Map<String, Any> = mapOf(
        "rawId" to rawId,
        "type" to type,
        "name" to name,
        "mimetypes" to mimetypes
    )
}
