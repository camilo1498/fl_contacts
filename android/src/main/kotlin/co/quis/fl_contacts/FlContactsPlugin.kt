package co.quis.fl_contacts

import android.Manifest
import android.app.Activity
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract
import android.provider.Settings
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Flutter plugin bridging Dart calls to the contacts provider.
 *
 * Method calls run on a supervised IO scope; results hop back to the
 * main thread. Instance state is torn down on engine detach so hot
 * restart never leaks channels, observers or coroutines. */
class FlContactsPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler, ActivityAware, ActivityResultListener, RequestPermissionsResultListener {
    companion object {
        private var activity: Activity? = null
        private var context: Context? = null
        private var resolver: ContentResolver? = null
        private const val permissionReadWriteCode: Int = 0
        private const val permissionReadOnlyCode: Int = 1
        private var permissionResult: Result? = null
        private var viewResult: Result? = null
        private var editResult: Result? = null
        private var pickResult: Result? = null
        private var insertResult: Result? = null
        private var ringtonePickResult: Result? = null
    }

    private var channel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var changesChannel: EventChannel? = null
    private var changesTracker: ContactChangeTracker? = null
    private var eventObserver: ContactChangeObserver? = null
    // Per-instance scope: cancelled on engine detach.
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)


    /** Registers channels on the engine messenger and caches app context. */
    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "github.com/QuisApp/fl_contacts")
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "github.com/QuisApp/fl_contacts/events")
        changesChannel = EventChannel(flutterPluginBinding.binaryMessenger, "github.com/QuisApp/fl_contacts/contactChanges")
        channel?.setMethodCallHandler(this)
        eventChannel?.setStreamHandler(this)
        changesChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                if (events != null && resolver != null) {
                    changesTracker?.stop()
                    changesTracker = ContactChangeTracker(resolver!!, events)
                    changesTracker?.start()
                }
            }

            override fun onCancel(arguments: Any?) {
                changesTracker?.stop()
                changesTracker = null
            }
        })
        context = flutterPluginBinding.applicationContext
        resolver = context?.contentResolver
    }

    /** Unregisters handlers, cancels coroutines and drops references. */
    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        changesChannel?.setStreamHandler(null)
        channel = null
        eventChannel = null
        changesChannel = null
        changesTracker?.stop()
        changesTracker = null
        scope.cancel()
        context = null
        resolver = null
    }


    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(@NonNull binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
        binding.addActivityResultListener(this)
    }

    /** Caches the activity and subscribes to its results. */
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
        binding.addActivityResultListener(this)
    }


    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        intent: Intent?
    ): Boolean {
        // Unknown codes (or stale results) return false for other plugins.
        when (requestCode) {
            FlContacts.REQUEST_CODE_VIEW ->
                if (viewResult != null) {
                    viewResult?.success(null)
                    viewResult = null
                    return true
                }
            FlContacts.REQUEST_CODE_EDIT ->
                if (editResult != null) {
                    // Lookup URIs end with the contact ID.
                    val id = if (resultCode == Activity.RESULT_OK) {
                        intent?.data?.lastPathSegment
                    } else {
                        null
                    }
                    editResult?.success(id)
                    editResult = null
                    return true
                }
            FlContacts.REQUEST_CODE_PICK ->
                if (pickResult != null) {
                    // Lookup URIs end with the contact ID.
                    val id = if (resultCode == Activity.RESULT_OK) {
                        intent?.data?.lastPathSegment
                    } else {
                        null
                    }
                    pickResult?.success(id)
                    pickResult = null
                    return true
                }
            FlContacts.REQUEST_CODE_INSERT ->
                if (insertResult != null) {
                    // Raw-contact URIs resolve to the unified contact off-thread.
                    val rawId = if (resultCode == Activity.RESULT_OK) {
                        intent?.data?.lastPathSegment
                    } else {
                        null
                    }
                    val pending = insertResult
                    insertResult = null
                    scope.launch {
                        val contactId = if (rawId != null) {
                            val contacts: List<Map<String, Any?>> =
                                FlContacts.select(
                                    resolver!!,
                                    rawId,
                                    false,
                                    false,
                                    false,
                                    false,
                                    false,
                                    true,
                                    true,
                                    true
                                )
                            if (contacts.isNotEmpty()) contacts[0]["id"] else null
                        } else {
                            null
                        }
                        withContext(Dispatchers.Main) { pending?.success(contactId) }
                    }
                    return true
                }
            FlContacts.REQUEST_CODE_RINGTONE_PICK ->
                if (ringtonePickResult != null) {
                    val uri = if (resultCode == Activity.RESULT_OK) {
                        pickRingtoneUri(intent)
                    } else {
                        null
                    }
                    ringtonePickResult?.success(uri)
                    ringtonePickResult = null
                    return true
                }
        }
        return false
    }


    /** Extracts the picked ringtone URI across API levels. */
    private fun pickRingtoneUri(intent: Intent?): String? {
        if (intent == null) return null
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(
                RingtoneManager.EXTRA_RINGTONE_PICKED_URI,
                Uri::class.java
            )?.toString()
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra<Uri>(
                RingtoneManager.EXTRA_RINGTONE_PICKED_URI
            )?.toString()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        // Unknown codes (or stale results) return false for other plugins.
        when (requestCode) {
            permissionReadWriteCode -> {
                // Empty results mean interruption: deny instead of hanging Dart.
                val granted = grantResults.size == 2 && grantResults[0] == PackageManager.PERMISSION_GRANTED && grantResults[1] == PackageManager.PERMISSION_GRANTED
                val pending = permissionResult
                permissionResult = null
                if (pending != null) {
                    scope.launch(Dispatchers.Main) {
                        pending.success(granted)
                    }
                }
                return true
            }
            permissionReadOnlyCode -> {
                val granted = grantResults.size == 1 && grantResults[0] == PackageManager.PERMISSION_GRANTED
                val pending = permissionResult
                permissionResult = null
                if (pending != null) {
                    scope.launch(Dispatchers.Main) {
                        pending.success(granted)
                    }
                }
                return true
            }
        }
        return false
    }


    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "requestPermission" ->
                scope.launch {
                    val appContext = context
                    if (appContext == null) {
                        withContext(Dispatchers.Main) { result.success(false) }
                        return@launch
                    }
                    val readonly = (call.arguments as? Boolean) ?: false
                    val readPermission = Manifest.permission.READ_CONTACTS
                    val writePermission = Manifest.permission.WRITE_CONTACTS
                    if (ContextCompat.checkSelfPermission(appContext, readPermission) == PackageManager.PERMISSION_GRANTED &&
                        (readonly || ContextCompat.checkSelfPermission(appContext, writePermission) == PackageManager.PERMISSION_GRANTED)
                    ) {
                        withContext(Dispatchers.Main) { result.success(true) }
                    } else {
                        val currentActivity = activity
                        if (currentActivity == null) {
                            withContext(Dispatchers.Main) { result.success(false) }
                        } else {
                            permissionResult = result
                            // The permission dialog requires the main thread.
                            withContext(Dispatchers.Main) {
                                if (readonly) {
                                    ActivityCompat.requestPermissions(currentActivity, arrayOf(readPermission), permissionReadOnlyCode)
                                } else {
                                    ActivityCompat.requestPermissions(currentActivity, arrayOf(readPermission, writePermission), permissionReadWriteCode)
                                }
                            }
                        }
                    }
                }
            "select" ->
                scope.launch {
                    val args = call.arguments as? List<*>
                    if (args == null || resolver == null) {
                        withContext(Dispatchers.Main) { result.success(listOf<Map<String, Any?>>()) }
                        return@launch
                    }
                    val id = args[0] as? String
                    val withProperties = args[1] as? Boolean ?: false
                    val withThumbnail = args[2] as? Boolean ?: false
                    val withPhoto = args[3] as? Boolean ?: false
                    val withGroups = args[4] as? Boolean ?: false
                    val withAccounts = args[5] as? Boolean ?: false
                    val returnUnifiedContacts = args[6] as? Boolean ?: true
                    val includeNonVisible = args[7] as? Boolean ?: false
                    // Index 8 of the args carries the iOS-only notes flag.
                    @Suppress("UNCHECKED_CAST")
                    val filter = args.getOrNull(9) as? Map<String, Any?>
                    val limit = (args.getOrNull(10) as? Int)
                        ?: (args.getOrNull(10) as? Long)?.toInt()
                    val contacts: List<Map<String, Any?>> =
                        FlContacts.select(
                            resolver!!,
                            id,
                            withProperties,
                            // Thumbnails backfill missing hi-res photos.
                            withThumbnail || withPhoto,
                            withPhoto,
                            withGroups,
                            withAccounts,
                            returnUnifiedContacts,
                            includeNonVisible,
                            false,
                            filter,
                            limit
                        )
                    withContext(Dispatchers.Main) { result.success(contacts) }
                }
            "insert" ->
                scope.launch {
                    val args = call.arguments as? List<*>
                    @Suppress("UNCHECKED_CAST")
                    val contact = args?.getOrNull(0) as? Map<String, Any?>
                    if (contact == null || resolver == null) {
                        withContext(Dispatchers.Main) {
                            result.error("", "failed to create contact", "")
                        }
                        return@launch
                    }
                    val insertedContact: Map<String, Any?>? =
                        FlContacts.insert(resolver!!, contact)
                    withContext(Dispatchers.Main) {
                        if (insertedContact != null) {
                            result.success(insertedContact)
                        } else {
                            result.error("", "failed to create contact", "")
                        }
                    }
                }
            "update" ->
                scope.launch {
                    val args = call.arguments as? List<*>
                    @Suppress("UNCHECKED_CAST")
                    val contact = args?.getOrNull(0) as? Map<String, Any?>
                    val withGroups = args?.getOrNull(1) as? Boolean ?: false
                    if (contact == null || resolver == null) {
                        withContext(Dispatchers.Main) {
                            result.error("", "failed to update contact", "")
                        }
                        return@launch
                    }
                    val updatedContact: Map<String, Any?>? =
                        FlContacts.update(resolver!!, contact, withGroups)
                    withContext(Dispatchers.Main) {
                        if (updatedContact != null) {
                            result.success(updatedContact)
                        } else {
                            result.error("", "failed to update contact", "")
                        }
                    }
                }
            "delete" ->
                scope.launch {
                    @Suppress("UNCHECKED_CAST")
                    val ids = call.arguments as? List<String> ?: emptyList()
                    if (resolver != null) {
                        FlContacts.delete(resolver!!, ids)
                    }
                    withContext(Dispatchers.Main) { result.success(null) }
                }
            "getGroups" ->
                scope.launch {
                    val groups: List<Map<String, Any?>> =
                        if (resolver != null) FlContacts.getGroups(resolver!!) else listOf()
                    withContext(Dispatchers.Main) { result.success(groups) }
                }
            "insertGroup" ->
                scope.launch {
                    val args = call.arguments as? List<*>
                    @Suppress("UNCHECKED_CAST")
                    val group = args?.getOrNull(0) as? Map<String, Any>
                    val insertedGroup: Map<String, Any?>? =
                        if (group != null && resolver != null) {
                            FlContacts.insertGroup(resolver!!, group)
                        } else {
                            null
                        }
                    withContext(Dispatchers.Main) {
                        result.success(insertedGroup)
                    }
                }
            "updateGroup" ->
                scope.launch {
                    val args = call.arguments as? List<*>
                    @Suppress("UNCHECKED_CAST")
                    val group = args?.getOrNull(0) as? Map<String, Any>
                    val updatedGroup: Map<String, Any?>? =
                        if (group != null && resolver != null) {
                            FlContacts.updateGroup(resolver!!, group)
                        } else {
                            null
                        }
                    withContext(Dispatchers.Main) {
                        result.success(updatedGroup)
                    }
                }
            "deleteGroup" ->
                scope.launch {
                    val args = call.arguments as? List<*>
                    @Suppress("UNCHECKED_CAST")
                    val group = args?.getOrNull(0) as? Map<String, Any>
                    if (group != null && resolver != null) {
                        FlContacts.deleteGroup(resolver!!, group)
                    }
                    withContext(Dispatchers.Main) {
                        result.success(null)
                    }
                }
            // External intents run inline: calls already arrive on main.
            "openExternalView" -> {
                val id = (call.arguments as? List<*>)?.getOrNull(0) as? String
                if (id == null) {
                    result.error("INVALID_ARGUMENT", "Missing contact id", null)
                } else {
                    FlContacts.openExternalViewOrEdit(activity, context, id, false)
                    viewResult = result
                }
            }
            // External intents run inline: calls already arrive on main.
            "openExternalEdit" -> {
                val id = (call.arguments as? List<*>)?.getOrNull(0) as? String
                if (id == null) {
                    result.error("INVALID_ARGUMENT", "Missing contact id", null)
                } else {
                    FlContacts.openExternalViewOrEdit(activity, context, id, true)
                    editResult = result
                }
            }
            // External intents run inline: calls already arrive on main.
            "openExternalPick" -> {
                FlContacts.openExternalPickOrInsert(activity, context, false)
                pickResult = result
            }
            // External intents run inline: calls already arrive on main.
            "openExternalInsert" -> {
                val args = call.arguments as? List<*>
                @Suppress("UNCHECKED_CAST")
                val contact = args?.getOrNull(0) as? Map<String, Any?>
                FlContacts.openExternalPickOrInsert(activity, context, true, contact)
                insertResult = result
            }
            // Inserts several contacts over one channel round trip.
            "insertAll" ->
                scope.launch {
                    val args = call.arguments as? List<*>
                    @Suppress("UNCHECKED_CAST")
                    val maps = args?.getOrNull(0) as? List<Map<String, Any?>> ?: emptyList()
                    if (resolver == null) {
                        withContext(Dispatchers.Main) { result.success(listOf<Map<String, Any?>>()) }
                        return@launch
                    }
                    val inserted = FlContacts.insertAll(resolver!!, maps)
                    withContext(Dispatchers.Main) { result.success(inserted) }
                }
            // Updates several contacts over one channel round trip.
            "updateAll" ->
                scope.launch {
                    val args = call.arguments as? List<*>
                    @Suppress("UNCHECKED_CAST")
                    val maps = args?.getOrNull(0) as? List<Map<String, Any?>> ?: emptyList()
                    val withGroups = args?.getOrNull(1) as? Boolean ?: false
                    if (resolver == null) {
                        withContext(Dispatchers.Main) { result.success(listOf<Map<String, Any?>>()) }
                        return@launch
                    }
                    val updated = FlContacts.updateAll(resolver!!, maps, withGroups)
                    withContext(Dispatchers.Main) { result.success(updated) }
                }
            // Reads contacts stored on the SIM card.
            "getSimContacts" ->
                scope.launch {
                    val contacts = if (resolver != null) {
                        FlContacts.getSimContacts(resolver!!)
                    } else {
                        listOf()
                    }
                    withContext(Dispatchers.Main) { result.success(contacts) }
                }
            // Reads the device owner's profile contact, if one exists.
            "getProfile" ->
                scope.launch {
                    val args = call.arguments as? List<*>
                    val withProperties = args?.getOrNull(0) as? Boolean ?: true
                    val withPhoto = args?.getOrNull(1) as? Boolean ?: true
                    val profile = if (resolver != null) {
                        FlContacts.getProfile(resolver!!, withProperties, withPhoto)
                    } else {
                        null
                    }
                    withContext(Dispatchers.Main) { result.success(profile) }
                }
            // Adds contacts to a label.
            "addContactsToGroup" ->
                scope.launch {
                    val args = call.arguments as? List<*>
                    val groupId = args?.getOrNull(0) as? String
                    @Suppress("UNCHECKED_CAST")
                    val ids = args?.getOrNull(1) as? List<String> ?: emptyList()
                    if (groupId != null && resolver != null) {
                        FlContacts.addContactsToGroup(resolver!!, groupId, ids)
                    }
                    withContext(Dispatchers.Main) { result.success(null) }
                }
            // Removes contacts from a label.
            "removeContactsFromGroup" ->
                scope.launch {
                    val args = call.arguments as? List<*>
                    val groupId = args?.getOrNull(0) as? String
                    @Suppress("UNCHECKED_CAST")
                    val ids = args?.getOrNull(1) as? List<String> ?: emptyList()
                    if (groupId != null && resolver != null) {
                        FlContacts.removeContactsFromGroup(resolver!!, groupId, ids)
                    }
                    withContext(Dispatchers.Main) { result.success(null) }
                }
            // Returns the labels a contact belongs to.
            "getGroupsOf" ->
                scope.launch {
                    val args = call.arguments as? List<*>
                    val contactId = args?.getOrNull(0) as? String
                    val groups = if (contactId != null && resolver != null) {
                        FlContacts.getGroupsOf(resolver!!, contactId)
                    } else {
                        listOf()
                    }
                    withContext(Dispatchers.Main) { result.success(groups) }
                }
            // Reports contact access without prompting.
            "checkPermissionStatus" -> {
                val appContext = context
                if (appContext == null) {
                    result.success("denied")
                } else {
                    val granted = ContextCompat.checkSelfPermission(
                        appContext, Manifest.permission.READ_CONTACTS
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(if (granted) "granted" else "denied")
                }
            }
            // Opens this app's system settings screen.
            "openAppSettings" -> {
                val appContext = context
                if (appContext == null) {
                    result.error("NO_CONTEXT", "Plugin is not attached", null)
                } else {
                    val intent = Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.parse("package:${appContext.packageName}")
                    )
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    appContext.startActivity(intent)
                    result.success(null)
                }
            }
            // Whether the user may manage blocked numbers.
            "isBlockNumbersAvailable" ->
                scope.launch {
                    val available = if (context != null) {
                        BlockedNumbers.isAvailable(context!!)
                    } else {
                        false
                    }
                    withContext(Dispatchers.Main) { result.success(available) }
                }
            // Whether a number is blocked.
            "isBlockedNumber" ->
                scope.launch {
                    val number = (call.arguments as? List<*>)?.getOrNull(0) as? String
                    if (number == null || context == null) {
                        withContext(Dispatchers.Main) { result.success(false) }
                        return@launch
                    }
                    try {
                        val blocked = BlockedNumbers.isBlocked(context!!, number)
                        withContext(Dispatchers.Main) { result.success(blocked) }
                    } catch (e: SecurityException) {
                        withContext(Dispatchers.Main) {
                            result.error("security_error", e.message, null)
                        }
                    }
                }
            // Every blocked number.
            "getBlockedNumbers" ->
                scope.launch {
                    if (context == null || resolver == null) {
                        withContext(Dispatchers.Main) { result.success(listOf<Map<String, Any?>>()) }
                        return@launch
                    }
                    try {
                        val numbers = BlockedNumbers.getAll(resolver!!, context!!)
                        withContext(Dispatchers.Main) { result.success(numbers) }
                    } catch (e: SecurityException) {
                        withContext(Dispatchers.Main) {
                            result.error("security_error", e.message, null)
                        }
                    }
                }
            // Blocks numbers (original + E.164 forms).
            "blockNumbers" ->
                scope.launch {
                    @Suppress("UNCHECKED_CAST")
                    val numbers = call.arguments as? List<String> ?: emptyList()
                    if (context == null || resolver == null) {
                        withContext(Dispatchers.Main) { result.success(null) }
                        return@launch
                    }
                    try {
                        BlockedNumbers.blockAll(resolver!!, context!!, numbers)
                        withContext(Dispatchers.Main) { result.success(null) }
                    } catch (e: SecurityException) {
                        withContext(Dispatchers.Main) {
                            result.error("security_error", e.message, null)
                        }
                    }
                }
            // Unblocks numbers (both stored forms).
            "unblockNumbers" ->
                scope.launch {
                    @Suppress("UNCHECKED_CAST")
                    val numbers = call.arguments as? List<String> ?: emptyList()
                    if (context == null || resolver == null) {
                        withContext(Dispatchers.Main) { result.success(null) }
                        return@launch
                    }
                    try {
                        BlockedNumbers.unblockAll(resolver!!, numbers)
                        withContext(Dispatchers.Main) { result.success(null) }
                    } catch (e: SecurityException) {
                        withContext(Dispatchers.Main) {
                            result.error("security_error", e.message, null)
                        }
                    }
                }
            // Opens the default-dialer settings.
            "openDefaultAppSettings" -> {
                if (context == null) {
                    result.error("NO_CONTEXT", "Plugin is not attached", null)
                } else {
                    BlockedNumbers.openDefaultAppSettings(context!!)
                    result.success(null)
                }
            }
            // Describes one ringtone URI.
            "getRingtone" ->
                scope.launch {
                    val args = call.arguments as? List<*>
                    val uri = args?.getOrNull(0) as? String
                    val withMetadata = args?.getOrNull(1) as? Boolean ?: true
                    val info = if (uri != null && context != null) {
                        Ringtones.getRingtoneInfo(context!!, uri, withMetadata)
                    } else {
                        null
                    }
                    withContext(Dispatchers.Main) { result.success(info) }
                }
            // Every ringtone of a slot, or of all slots when null.
            "getRingtones" ->
                scope.launch {
                    val args = call.arguments as? List<*>
                    val type = Ringtones.typeFromName(args?.getOrNull(0) as? String)
                    val withMetadata = args?.getOrNull(1) as? Boolean ?: false
                    val all = if (context != null) {
                        Ringtones.getAll(context!!, type, withMetadata)
                    } else {
                        listOf()
                    }
                    withContext(Dispatchers.Main) { result.success(all) }
                }
            // Shows the system ringtone picker.
            "pickRingtone" -> {
                val args = call.arguments as? List<*>
                val type = Ringtones.typeFromName(args?.getOrNull(0) as? String)
                val existing = args?.getOrNull(1) as? String
                val currentActivity = activity
                if (currentActivity == null) {
                    result.error("NO_ACTIVITY", "No activity attached", null)
                } else {
                    val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                        putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, type)
                        putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                        putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, true)
                        putExtra(
                            RingtoneManager.EXTRA_RINGTONE_EXISTING_URI,
                            existing?.let { Uri.parse(it) }
                        )
                    }
                    ringtonePickResult = result
                    @Suppress("DEPRECATION")
                    currentActivity.startActivityForResult(
                        intent, FlContacts.REQUEST_CODE_RINGTONE_PICK
                    )
                }
            }
            // Current default URI of a slot.
            "getDefaultRingtone" ->
                scope.launch {
                    val type = Ringtones.typeFromName(
                        (call.arguments as? List<*>)?.getOrNull(0) as? String
                    )
                    val uri = if (context != null) {
                        Ringtones.getDefaultUri(context!!, type)
                    } else {
                        null
                    }
                    withContext(Dispatchers.Main) { result.success(uri) }
                }
            // Sets (or clears) the default URI of a slot.
            "setDefaultRingtone" ->
                scope.launch {
                    val args = call.arguments as? List<*>
                    val type = Ringtones.typeFromName(args?.getOrNull(0) as? String)
                    val uri = args?.getOrNull(1) as? String
                    if (context == null) {
                        withContext(Dispatchers.Main) { result.success(null) }
                        return@launch
                    }
                    try {
                        Ringtones.setDefaultUri(context!!, type, uri)
                        withContext(Dispatchers.Main) { result.success(null) }
                    } catch (e: SecurityException) {
                        withContext(Dispatchers.Main) {
                            result.error("security_error", e.message, null)
                        }
                    }
                }
            // Previews a ringtone.
            "playRingtone" ->
                scope.launch {
                    val uri = (call.arguments as? List<*>)?.getOrNull(0) as? String
                    if (uri != null && context != null) {
                        Ringtones.play(context!!, uri)
                    }
                    withContext(Dispatchers.Main) { result.success(null) }
                }
            // Stops an in-progress preview.
            "stopRingtone" -> {
                Ringtones.stop()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }


    /** Registers a content observer posting on the main looper. */
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        if (events != null) {
            // A bare Handler() is deprecated and thread-unsafe; pin the main looper.
            eventObserver = ContactChangeObserver(Handler(Looper.getMainLooper()), events)
            resolver?.registerContentObserver(ContactsContract.Contacts.CONTENT_URI, true, eventObserver!!)
        }
    }

    /** Unregisters the observer and drops it. */
    override fun onCancel(arguments: Any?) {
        if (eventObserver != null) {
            resolver?.unregisterContentObserver(eventObserver!!)
        }
        eventObserver = null
    }
}
