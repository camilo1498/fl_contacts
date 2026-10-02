package co.quis.fl_contacts

import android.content.ContentResolver
import android.database.ContentObserver
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit

/** Emits per-contact diffs (`added`/`updated`/`removed` + IDs) to Dart.
 *
 * The provider only signals *that* something changed, so this tracker keeps
 * a fingerprint snapshot (`id -> content hash`), debounces bursts for
 * 300 ms, then reports the delta. Snapshots exclude photo bytes: fetching
 * thumbnails for thousands of contacts on every keystroke would defeat the
 * purpose of a lightweight listener.
 */
class ContactChangeTracker(
    private val resolver: ContentResolver,
    private val sink: EventChannel.EventSink
) {
    private val worker = Executors.newSingleThreadExecutor()
    private val debouncer: ScheduledExecutorService =
        Executors.newSingleThreadScheduledExecutor()
    private var pending: ScheduledFuture<*>? = null
    private var baseline: Map<String, Int> = mapOf()

    private val observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
        override fun onChange(selfChange: Boolean) {
            schedule()
        }

        override fun onChange(selfChange: Boolean, uri: android.net.Uri?) {
            schedule()
        }
    }

    /** Snapshots the current state and starts observing. */
    fun start() {
        worker.execute {
            baseline = snapshot()
            resolver.registerContentObserver(
                ContactsContract.Contacts.CONTENT_URI,
                true,
                observer
            )
        }
    }

    /** Stops observing and shuts down executors. */
    fun stop() {
        try {
            resolver.unregisterContentObserver(observer)
        } catch (e: Exception) {
            // Already unregistered.
        }
        pending?.cancel(false)
        debouncer.shutdown()
        worker.shutdown()
    }

    private fun schedule() {
        pending?.cancel(false)
        pending = debouncer.schedule(
            { worker.execute { diffAndEmit() } },
            300,
            TimeUnit.MILLISECONDS
        )
    }

    /** Content fingerprint: identity plus every scalar property. */
    private fun fingerprint(contact: Map<String, Any?>): Int {
        var hash = (contact["id"] as? String ?: "").hashCode()
        hash = 31 * hash + (contact["displayName"] as? String ?: "").hashCode()
        hash = 31 * hash + (contact["isStarred"] as? Boolean ?: false).hashCode()
        for (key in listOf("phones", "emails", "addresses", "organizations", "websites", "socialMedias", "events", "notes", "groups")) {
            hash = 31 * hash + (contact[key]?.toString() ?: "").hashCode()
        }
        return hash
    }

    /** Reads the current fingerprint snapshot off the worker thread. */
    private fun snapshot(): Map<String, Int> {
        return try {
            FlContacts.select(
                resolver,
                null,
                true,
                false,
                false,
                true,
                false,
                true,
                true
            ).associate { contact ->
                val id = contact["id"] as? String ?: ""
                id to fingerprint(contact)
            }.filterKeys { it.isNotEmpty() }
        } catch (e: Exception) {
            mapOf()
        }
    }

    /** Diffs against the baseline on the worker, reporting on main. */
    private fun diffAndEmit() {
        val current = snapshot()
        val changes = mutableListOf<Map<String, String>>()
        for ((id, hash) in current) {
            val old = baseline[id]
            if (old == null) {
                changes.add(mapOf("type" to "added", "contactId" to id))
            } else if (old != hash) {
                changes.add(mapOf("type" to "updated", "contactId" to id))
            }
        }
        for (id in baseline.keys) {
            if (!current.containsKey(id)) {
                changes.add(mapOf("type" to "removed", "contactId" to id))
            }
        }
        baseline = current
        if (changes.isNotEmpty()) {
            Handler(Looper.getMainLooper()).post { sink.success(changes) }
        }
    }
}
