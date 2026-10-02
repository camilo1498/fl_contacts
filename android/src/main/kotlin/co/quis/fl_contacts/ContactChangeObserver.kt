package co.quis.fl_contacts

import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import io.flutter.plugin.common.EventChannel

/** Forwards provider change events to the Dart event sink. */
class ContactChangeObserver : ContentObserver {
    val _sink: EventChannel.EventSink

    constructor(handler: Handler, sink: EventChannel.EventSink) : super(handler) {
        this._sink = sink
    }

    /** Legacy callback; both overrides funnel here. */
    override fun onChange(selfChange: Boolean) {
        _sink.success(selfChange)
    }

    /** Modern callback carrying the changed URI. */
    override fun onChange(selfChange: Boolean, uri: Uri?) {
        onChange(selfChange)
    }
}
