package co.quis.fl_contacts

import android.content.Context
import android.database.Cursor
import android.media.RingtoneManager
import android.net.Uri
import android.provider.MediaStore

/** System ringtones via [RingtoneManager] and [MediaStore] metadata. */
object Ringtones {
    private var preview: android.media.Ringtone? = null

    /** Starts previewing [uriString], stopping any previous preview. */
    fun play(context: Context, uriString: String) {
        stop()
        val ringtone = RingtoneManager.getRingtone(
            context,
            Uri.parse(uriString),
        ) ?: return
        preview = ringtone
        ringtone.play()
    }

    /** Stops an in-progress preview, if any. */
    fun stop() {
        try {
            preview?.stop()
        } catch (e: Exception) {
            // Already released; nothing to stop.
        }
        preview = null
    }

    /** Maps a channel slot name to its [RingtoneManager] type. */
    /** Maps a channel slot name to its [RingtoneManager] type. */
    fun typeFromName(name: String?): Int = when (name) {
        "alarm" -> RingtoneManager.TYPE_ALARM
        "notification" -> RingtoneManager.TYPE_NOTIFICATION
        else -> RingtoneManager.TYPE_RINGTONE
    }

    /** Describes one ringtone URI, optionally with store metadata. */
    fun getRingtoneInfo(
        context: Context,
        uriString: String,
        withMetadata: Boolean
    ): Map<String, Any?>? {
        val uri = Uri.parse(uriString) ?: return null
        val ringtone = RingtoneManager.getRingtone(context, uri) ?: return null
        var title = ""
        val streamType = try {
            ringtone.streamType
        } catch (e: Exception) {
            -1
        }
        if (withMetadata) {
            title = queryTitle(context, uri)
            if (title.isEmpty()) {
                title = try {
                    ringtone.getTitle(context)
                } catch (e: Exception) {
                    ""
                }
            }
        }
        return mapOf("uri" to uriString, "title" to title, "type" to streamType)
    }

    /** Reads the MediaStore title for library URIs; empty otherwise. */
    private fun queryTitle(context: Context, uri: Uri): String {
        var cursor: Cursor? = null
        try {
            cursor = context.contentResolver.query(
                uri,
                arrayOf(MediaStore.Audio.Media.TITLE),
                null,
                null,
                null
            )
            if (cursor != null && cursor.moveToFirst()) {
                return cursor.getString(
                    cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
                ) ?: ""
            }
        } catch (e: Exception) {
            // Non-library URIs (e.g. settings defaults) have no row.
        } finally {
            cursor?.close()
        }
        return ""
    }

    /** Every ringtone of [type], or of all slots when null. */
    fun getAll(
        context: Context,
        type: Int?,
        withMetadata: Boolean
    ): List<Map<String, Any?>> {
        val manager = RingtoneManager(context)
        if (type != null) {
            manager.setType(type)
        }
        val cursor = manager.cursor ?: return listOf()
        cursor.use {
            val out = mutableListOf<Map<String, Any?>>()
            val titleCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            while (cursor.moveToNext()) {
                out.add(
                    mapOf(
                        "uri" to manager.getRingtoneUri(cursor.position).toString(),
                        "title" to if (withMetadata) {
                            cursor.getString(titleCol) ?: ""
                        } else {
                            ""
                        },
                        "type" to type
                    )
                )
            }
            return out
        }
    }

    /** Current default URI for [type], if the user set one. */
    fun getDefaultUri(context: Context, type: Int): String? {
        return RingtoneManager.getActualDefaultRingtoneUri(context, type)?.toString()
    }

    /** Sets (or clears, with null) the default URI for [type]. */
    fun setDefaultUri(context: Context, type: Int, uriString: String?) {
        RingtoneManager.setActualDefaultRingtoneUri(
            context,
            type,
            uriString?.let { Uri.parse(it) }
        )
    }
}
