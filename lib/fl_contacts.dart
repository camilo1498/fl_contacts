import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:fl_contacts/config.dart';
import 'package:fl_contacts/contact.dart';
import 'package:fl_contacts/contact_change.dart';
import 'package:fl_contacts/contact_filter.dart';
import 'package:fl_contacts/diacritics.dart';
import 'package:fl_contacts/properties/group.dart';
import 'package:fl_contacts/ringtone.dart';

export 'contact.dart';
export 'contact_change.dart';
export 'contact_filter.dart';
export 'fl_blocked_numbers.dart';
export 'fl_ringtones.dart';
export 'properties/account.dart';
export 'properties/address.dart';
export 'properties/email.dart';
export 'properties/event.dart';
export 'properties/group.dart';
export 'properties/name.dart';
export 'properties/note.dart';
export 'properties/organization.dart';
export 'properties/phone.dart';
export 'properties/social_media.dart';
export 'properties/website.dart';
export 'ringtone.dart';
export 'vcard_extra.dart';

/// Entry point for reading and mutating the device contact database.
///
/// All methods are static and delegate to the native Android / iOS
/// implementations over a method channel. Contacts are transferred as plain
/// maps; see [Contact] for the payload layout.
class FlContacts {
  static const _channel = MethodChannel('github.com/QuisApp/fl_contacts');
  static const _eventChannel = EventChannel(
    'github.com/QuisApp/fl_contacts/events',
  );
  static const _contactChangesChannel = EventChannel(
    'github.com/QuisApp/fl_contacts/contactChanges',
  );
  static final _eventSubscribers = <void Function()>{};
  static StreamSubscription<void>? _legacyDatabaseSubscription;
  static final _alpha = RegExp(r'\p{Letter}', unicode: true);
  static final _numeric = RegExp(r'\p{Number}', unicode: true);

  /// Mutable plugin-wide configuration. Assign fields before fetching or
  /// exporting contacts; changes apply to subsequent calls only.
  static FlContactsConfig get config => flContactsConfig;

  /// Asks the OS for contact access.
  ///
  /// Returns `true` when access is granted and `false` otherwise. With
  /// [readonly] only read access is requested, which applies to Android
  /// (iOS has no read-only contact permission).
  static Future<bool> requestPermission({bool readonly = false}) async =>
      await _channel.invokeMethod<bool>('requestPermission', readonly) ?? false;

  /// Reports the current contact-access state without prompting.
  ///
  /// Maps the OS status: full grants become [FlPermissionStatus.granted],
  /// iOS 18+ limited selection becomes [FlPermissionStatus.limited], denials
  /// stay [FlPermissionStatus.denied], and policy blocks or permanent
  /// denials become [FlPermissionStatus.restricted].
  static Future<FlPermissionStatus> checkPermissionStatus() async {
    final raw =
        await _channel.invokeMethod<String>('checkPermissionStatus') ?? '';
    return switch (raw) {
      'granted' => FlPermissionStatus.granted,
      'limited' => FlPermissionStatus.limited,
      'restricted' => FlPermissionStatus.restricted,
      _ => FlPermissionStatus.denied,
    };
  }

  /// Opens the OS app-settings page so users can unblock denied access.
  ///
  /// Android opens this app's settings screen; iOS and macOS open the
  /// system settings. Other platforms throw [UnsupportedError].
  static Future<void> openAppSettings() async {
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
      throw UnsupportedError(
        'Opening app settings is not supported on this platform.',
      );
    }
    await _channel.invokeMethod<void>('openAppSettings');
  }

  /// Returns every contact in the database.
  ///
  /// By default only IDs and display names are loaded, which is fast enough
  /// for large address books. Opt into [withProperties], [withThumbnail],
  /// [withPhoto], [withGroups] and [withAccounts] to hydrate the result.
  /// Results are sorted naturally and deduplicated unless disabled.
  ///
  /// [filter] narrows the fetch natively (by IDs, group, name, phone or
  /// email) and [limit] caps the result size. Both are ignored by platforms
  /// that cannot apply them, which then return everything.
  static Future<List<Contact>> getContacts({
    bool withProperties = false,
    bool withThumbnail = false,
    bool withPhoto = false,
    bool withGroups = false,
    bool withAccounts = false,
    bool sorted = true,
    bool deduplicateProperties = true,
    ContactFilter? filter,
    int? limit,
  }) async => _select(
    withProperties: withProperties,
    withThumbnail: withThumbnail,
    withPhoto: withPhoto,
    withGroups: withGroups,
    withAccounts: withAccounts,
    sorted: sorted,
    deduplicateProperties: deduplicateProperties,
    filter: filter,
    limit: limit,
  );

  /// Returns the contact with the given [id], or `null` when it is missing.
  ///
  /// Everything available is fetched unless the `with...` flags opt out.
  static Future<Contact?> getContact(
    String id, {
    bool withProperties = true,
    bool withThumbnail = true,
    bool withPhoto = true,
    bool withGroups = false,
    bool withAccounts = false,
    bool deduplicateProperties = true,
  }) async {
    final contacts = await _select(
      id: id,
      withProperties: withProperties,
      withThumbnail: withThumbnail,
      withPhoto: withPhoto,
      withGroups: withGroups,
      withAccounts: withAccounts,
      sorted: false,
      deduplicateProperties: deduplicateProperties,
    );
    if (contacts.length != 1) return null;
    return contacts.first;
  }

  /// Persists a new [contact] and returns it as stored.
  ///
  /// The returned instance differs from the input (e.g. it carries the
  /// database-assigned ID); use it for any follow-up operation. Throws when
  /// the input already has an ID or is a raw contact.
  static Future<Contact> insertContact(Contact contact) async {
    if (contact.id.isNotEmpty) {
      throw Exception('Cannot insert contact that already has an ID');
    }
    if (!contact.isUnified) {
      throw Exception('Cannot insert raw contacts');
    }
    if (Platform.isLinux) {
      return _insertLinux(contact.toVCard());
    }
    final json = await _channel.invokeMethod<Map<Object?, Object?>>('insert', [
      contact.toJson(),
      config.includeNotesOnIos13AndAbove,
    ]);
    if (json == null) {
      throw StateError('Failed to insert contact');
    }
    return Contact.fromJson(Map<String, dynamic>.from(json));
  }

  /// Persists changes to an existing [contact] and returns it as stored.
  ///
  /// Requires a fetched ID, properties and photo: updating a partially
  /// loaded contact would wipe the missing fields. On Android the contact
  /// must also carry raw-account data (`withAccounts: true` at fetch time).
  static Future<Contact> updateContact(
    Contact contact, {
    bool withGroups = false,
  }) async {
    if (contact.id.isEmpty) {
      throw Exception('Cannot update contact without ID');
    }
    if (Platform.isAndroid &&
        !contact.accounts.any((x) => x.rawId.isNotEmpty)) {
      throw Exception(
        'Cannot update contact without raw ID on Android, make sure to '
        'specify `withAccounts: true` when fetching contacts',
      );
    }
    if (!contact.propertiesFetched || !contact.photoFetched) {
      throw Exception(
        'Cannot update contact without properties and photo, make sure to '
        'specify `withProperties: true` and `withPhoto: true` when fetching '
        'contacts',
      );
    }
    if (!contact.isUnified) {
      throw Exception('Cannot update raw contacts');
    }
    if (Platform.isLinux) {
      return _updateLinux(contact.id, contact.toVCard());
    }
    final json = await _channel.invokeMethod<Map<Object?, Object?>>('update', [
      contact.toJson(),
      withGroups,
      config.includeNotesOnIos13AndAbove,
    ]);
    if (json == null) {
      throw StateError('Failed to update contact');
    }
    return Contact.fromJson(Map<String, dynamic>.from(json));
  }

  /// Removes every contact in [contacts] from the database.
  static Future<void> deleteContacts(List<Contact> contacts) async {
    final ids = contacts.map((c) => c.id).toList();
    if (ids.any((x) => x.isEmpty)) {
      throw Exception('Cannot delete contacts without IDs');
    }
    if (contacts.any((c) => !c.isUnified)) {
      throw Exception('Cannot delete raw contacts');
    }
    await _channel.invokeMethod<void>('delete', ids);
  }

  /// Removes a single [contact] from the database.
  static Future<void> deleteContact(Contact contact) async =>
      deleteContacts([contact]);

  /// Inserts every contact in [contacts] over one channel round trip.
  ///
  /// Each entry follows the [insertContact] rules; entries with IDs or raw
  /// contacts abort the whole call. Returns the stored contacts in order.
  static Future<List<Contact>> insertContacts(List<Contact> contacts) async {
    for (final contact in contacts) {
      if (contact.id.isNotEmpty) {
        throw Exception('Cannot insert contact that already has an ID');
      }
      if (!contact.isUnified) {
        throw Exception('Cannot insert raw contacts');
      }
    }
    if (Platform.isLinux) {
      final untyped =
          await _channel.invokeMethod<List<dynamic>>('insertAll', [
            contacts.map((c) => c.toVCard()).toList(),
          ]) ??
          [];
      return untyped
          .map(
            (x) => _contactFromLinuxEntry(Map<String, dynamic>.from(x as Map)),
          )
          .toList();
    }
    final untyped =
        await _channel.invokeMethod<List<dynamic>>('insertAll', [
          contacts.map((c) => c.toJson()).toList(),
          config.includeNotesOnIos13AndAbove,
        ]) ??
        [];
    return untyped
        .map((x) => Contact.fromJson(Map<String, dynamic>.from(x as Map)))
        .toList();
  }

  /// Updates every contact in [contacts] over one channel round trip.
  ///
  /// The same guards as [updateContact] apply to each entry. Returns the
  /// stored contacts in order.
  static Future<List<Contact>> updateContacts(
    List<Contact> contacts, {
    bool withGroups = false,
  }) async {
    for (final contact in contacts) {
      if (contact.id.isEmpty) {
        throw Exception('Cannot update contact without ID');
      }
      if (!contact.propertiesFetched || !contact.photoFetched) {
        throw Exception(
          'Cannot update contact without properties and photo, make sure to '
          'specify `withProperties: true` and `withPhoto: true` when '
          'fetching contacts',
        );
      }
      if (!contact.isUnified) {
        throw Exception('Cannot update raw contacts');
      }
    }
    if (Platform.isLinux) {
      final untyped =
          await _channel.invokeMethod<List<dynamic>>('updateAll', [
            contacts.map((c) => [c.id, c.toVCard()]).toList(),
          ]) ??
          [];
      return untyped
          .map(
            (x) => _contactFromLinuxEntry(Map<String, dynamic>.from(x as Map)),
          )
          .toList();
    }
    final untyped =
        await _channel.invokeMethod<List<dynamic>>('updateAll', [
          contacts.map((c) => c.toJson()).toList(),
          withGroups,
          config.includeNotesOnIos13AndAbove,
        ]) ??
        [];
    return untyped
        .map((x) => Contact.fromJson(Map<String, dynamic>.from(x as Map)))
        .toList();
  }

  /// Returns contacts stored on the SIM card.
  ///
  /// Android only; every other platform throws [UnsupportedError]. SIM
  /// records carry an ID, a display name and mobile numbers.
  static Future<List<Contact>> getSimContacts() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('SIM contacts are only available on Android.');
    }
    final untyped =
        await _channel.invokeMethod<List<dynamic>>('getSimContacts') ?? [];
    final contacts = untyped
        .map((x) => Contact.fromJson(Map<String, dynamic>.from(x as Map)))
        .toList();
    contacts.sort(
      (a, b) => _compareNormalized(
        _normalizeName(a.displayName),
        _normalizeName(b.displayName),
      ),
    );
    return contacts;
  }

  /// Returns the device owner's profile ("Me") contact, if one exists.
  ///
  /// Android reads the profile provider; macOS reads the Me card. iOS,
  /// Windows and Linux throw [UnsupportedError].
  static Future<Contact?> getProfile({
    bool withProperties = true,
    bool withPhoto = true,
  }) async {
    if (!Platform.isAndroid && !Platform.isMacOS) {
      throw UnsupportedError(
        'The profile contact is only available on Android and macOS.',
      );
    }
    final json = await _channel.invokeMethod<Map<Object?, Object?>>(
      'getProfile',
      [withProperties, withPhoto],
    );
    if (json == null) return null;
    return Contact.fromJson(Map<String, dynamic>.from(json));
  }

  /// Returns all groups (called labels on Android).
  static Future<List<Group>> getGroups() async {
    final untypedGroups =
        await _channel.invokeMethod<List<dynamic>>('getGroups') ?? [];
    final groups = untypedGroups
        .map((x) => Group.fromJson(Map<String, dynamic>.from(x as Map)))
        .toList();
    return groups;
  }

  /// Creates a new [group] and returns it as stored.
  static Future<Group> insertGroup(Group group) async {
    if (Platform.isLinux) {
      throw UnsupportedError(
        'Explicit groups do not exist on Linux: labels emerge from '
        'CATEGORIES. Use addContactsToGroup instead.',
      );
    }
    final json = await _channel.invokeMethod<Map<Object?, Object?>>(
      'insertGroup',
      [group.toJson()],
    );
    if (json == null) {
      throw StateError('Failed to insert group');
    }
    return Group.fromJson(Map<String, dynamic>.from(json));
  }

  /// Renames [group] and returns it as stored.
  static Future<Group> updateGroup(Group group) async {
    if (Platform.isLinux) {
      throw UnsupportedError(
        'Explicit groups do not exist on Linux: labels emerge from '
        'CATEGORIES. Use addContactsToGroup instead.',
      );
    }
    final json = await _channel.invokeMethod<Map<Object?, Object?>>(
      'updateGroup',
      [group.toJson()],
    );
    if (json == null) {
      throw StateError('Failed to update group');
    }
    return Group.fromJson(Map<String, dynamic>.from(json));
  }

  /// Deletes [group] from the database.
  static Future<void> deleteGroup(Group group) async {
    if (Platform.isLinux) {
      throw UnsupportedError(
        'Explicit groups do not exist on Linux: remove the CATEGORIES '
        'from every contact with removeContactsFromGroup instead.',
      );
    }
    await _channel.invokeMethod<void>('deleteGroup', [group.toJson()]);
  }

  /// Adds [contactIds] to the group [groupId] without touching the contacts.
  static Future<void> addContactsToGroup({
    required String groupId,
    required List<String> contactIds,
  }) async {
    await _channel.invokeMethod<void>('addContactsToGroup', [
      groupId,
      contactIds,
    ]);
  }

  /// Removes [contactIds] from the group [groupId].
  static Future<void> removeContactsFromGroup({
    required String groupId,
    required List<String> contactIds,
  }) async {
    await _channel.invokeMethod<void>('removeContactsFromGroup', [
      groupId,
      contactIds,
    ]);
  }

  /// Returns the groups (or labels) the contact [contactId] belongs to.
  static Future<List<Group>> getGroupsOf(String contactId) async {
    final untyped =
        await _channel.invokeMethod<List<dynamic>>('getGroupsOf', [
          contactId,
        ]) ??
        [];
    return untyped
        .map((x) => Group.fromJson(Map<String, dynamic>.from(x as Map)))
        .toList();
  }

  /// Broadcast that fires with `null` on every native database notification.
  ///
  /// Coarse-grained by OS design: the event carries no details, so refresh
  /// whatever is on screen. Prefer [onContactChanged] for per-contact diffs.
  /// The platform subscription starts with the first listener and stops
  /// with the last.
  static Stream<void> get onDatabaseChanged {
    _databaseController ??= StreamController<void>.broadcast(
      onListen: _ensureDatabaseStream,
      onCancel: _cancelDatabaseStream,
    );
    return _databaseController!.stream;
  }

  /// Per-contact diffs (`added`/`updated`/`removed` with IDs) per cycle.
  ///
  /// Computed by snapshotting fingerprints around each native notification
  /// and debouncing bursts, on every platform that reports changes. Each
  /// event lists what changed since the previous one.
  static Stream<List<ContactChange>> get onContactChanged {
    _changesController ??= StreamController<List<ContactChange>>.broadcast(
      onListen: _ensureChangesStream,
      onCancel: _cancelChangesStream,
    );
    return _changesController!.stream;
  }

  static StreamController<void>? _databaseController;
  static StreamSubscription<dynamic>? _databaseSubscription;
  static StreamController<List<ContactChange>>? _changesController;
  static StreamSubscription<dynamic>? _changesSubscription;

  static void _ensureDatabaseStream() {
    _databaseSubscription ??= _eventChannel.receiveBroadcastStream().listen(
      (_) => _databaseController?.add(null),
      onError: (Object e) => _databaseController?.addError(e),
    );
  }

  static void _cancelDatabaseStream() {
    unawaited(_databaseSubscription?.cancel());
    _databaseSubscription = null;
  }

  static void _ensureChangesStream() {
    _changesSubscription ??= _contactChangesChannel
        .receiveBroadcastStream()
        .listen(
          (dynamic event) =>
              _changesController?.add(_parseContactChanges(event)),
          onError: (Object e) => _changesController?.addError(e),
        );
  }

  static void _cancelChangesStream() {
    unawaited(_changesSubscription?.cancel());
    _changesSubscription = null;
  }

  /// Decodes native change payloads, dropping malformed entries.
  static List<ContactChange> _parseContactChanges(dynamic event) {
    if (event is! List) return [];
    final changes = <ContactChange>[];
    for (final entry in event) {
      if (entry is! Map) continue;
      final contactId = entry['contactId'] as String?;
      if (contactId == null) continue;
      final type = switch (entry['type']) {
        'added' => ContactChangeType.added,
        'removed' => ContactChangeType.removed,
        'updated' => ContactChangeType.updated,
        _ => null,
      };
      if (type != null) {
        changes.add(ContactChange(type: type, contactId: contactId));
      }
    }
    return changes;
  }

  /// Registers [listener] for contact-database changes.
  ///
  /// Kept for compatibility; routes through [onDatabaseChanged]. Call
  /// [removeListener] when done; the caller owns the subscription lifecycle.
  static void addListener(void Function() listener) {
    if (_eventSubscribers.add(listener) && _eventSubscribers.length == 1) {
      _legacyDatabaseSubscription = onDatabaseChanged.listen(
        (_) => _runAllListeners(null),
      );
    }
  }

  /// Unregisters a listener previously added with [addListener].
  static void removeListener(void Function() listener) {
    _eventSubscribers.remove(listener);
    if (_eventSubscribers.isEmpty) {
      unawaited(_legacyDatabaseSubscription?.cancel());
      _legacyDatabaseSubscription = null;
    }
  }

  /// Fans a native change event out to every registered listener.
  static void _runAllListeners(dynamic event) {
    for (final listener in _eventSubscribers) {
      listener();
    }
  }

  /// Shows the contact with [id] in the system contacts app.
  ///
  /// Android and iOS only; desktop platforms throw [UnsupportedError].
  static Future<void> openExternalView(String id) async {
    _ensureMobileExternal();
    await _channel.invokeMethod<void>(
      Platform.isAndroid ? 'openExternalView' : 'openExternalViewOrEdit',
      [id],
    );
  }

  /// Opens the system editor for [id] and returns the contact afterwards,
  /// or `null` when the flow is dismissed without a result.
  ///
  /// Android and iOS only; desktop platforms throw [UnsupportedError].
  static Future<Contact?> openExternalEdit(String id) async {
    _ensureMobileExternal();
    final newId = await _channel.invokeMethod<String>(
      Platform.isAndroid ? 'openExternalEdit' : 'openExternalViewOrEdit',
      [id],
    );
    return newId == null ? null : getContact(newId);
  }

  /// Opens the system picker and returns the chosen contact, if any.
  ///
  /// Android and iOS only; desktop platforms throw [UnsupportedError].
  static Future<Contact?> openExternalPick() async {
    _ensureMobileExternal();
    final id = await _channel.invokeMethod<String>('openExternalPick');
    return id == null ? null : getContact(id);
  }

  /// Opens the system creator, optionally pre-filled from [contact], and
  /// returns the created contact, if any.
  ///
  /// Android and iOS only; desktop platforms throw [UnsupportedError].
  static Future<Contact?> openExternalInsert([Contact? contact]) async {
    _ensureMobileExternal();
    final args = contact != null
        ? [contact.toJson()]
        : <Map<String, dynamic>>[];
    final id = await _channel.invokeMethod<String>('openExternalInsert', args);
    return id == null ? null : getContact(id);
  }

  static void _ensureMobileExternal() {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError(
        'System contact UI is only available on Android and iOS.',
      );
    }
  }

  /// Shared fetch pipeline: one native round-trip, then optional sorting,
  /// property deduplication and fetch-metadata bookkeeping.
  static Future<List<Contact>> _select({
    String? id,
    bool withProperties = false,
    bool withThumbnail = false,
    bool withPhoto = false,
    bool withGroups = false,
    bool withAccounts = false,
    bool sorted = true,
    bool deduplicateProperties = true,
    ContactFilter? filter,
    int? limit,
  }) async {
    if (Platform.isLinux) {
      return _selectLinux(
        sorted: sorted,
        deduplicateProperties: deduplicateProperties,
        filter: filter,
        limit: limit,
      );
    }
    final untypedContacts =
        await _channel.invokeMethod<List<dynamic>>('select', [
          id,
          withProperties,
          withThumbnail,
          withPhoto,
          withGroups,
          withAccounts,
          config.returnUnifiedContacts,
          config.includeNonVisibleOnAndroid,
          config.includeNotesOnIos13AndAbove,
          filter?.toJson(),
          limit,
        ]) ??
        [];
    final contacts = untypedContacts
        .map((x) => Contact.fromJson(Map<String, dynamic>.from(x as Map)))
        .toList();
    if (sorted) {
      _sortByDisplayName(contacts);
    }
    if (deduplicateProperties) {
      for (final c in contacts) {
        c.deduplicateProperties();
      }
    }
    for (final c in contacts) {
      c
        ..propertiesFetched = withProperties
        ..thumbnailFetched = withThumbnail
        ..photoFetched = withPhoto
        ..isUnified = config.returnUnifiedContacts;
    }
    return contacts;
  }

  /// Linux fetch: the native side shuttles `{uid, vcard}` pairs and Dart
  /// parses them with the shared vCard importer.
  static Future<List<Contact>> _selectLinux({
    String? id,
    bool sorted = true,
    bool deduplicateProperties = true,
    ContactFilter? filter,
    int? limit,
  }) async {
    final untyped =
        await _channel.invokeMethod<List<dynamic>>('select', [
          filter?.toJson(),
          limit,
        ]) ??
        [];
    var contacts = untyped.map((x) {
      final entry = Map<String, dynamic>.from(x as Map);
      return _contactFromLinuxEntry(entry);
    }).toList();
    if (id != null) {
      contacts = contacts.where((c) => c.id == id).toList();
    }
    if (sorted) {
      _sortByDisplayName(contacts);
    }
    if (deduplicateProperties) {
      for (final c in contacts) {
        c.deduplicateProperties();
      }
    }
    return contacts;
  }

  /// Builds a contact from a Linux `{uid, vcard}` entry.
  static Contact _contactFromLinuxEntry(Map<String, dynamic> entry) {
    final contact = Contact.fromVCard((entry['vcard'] as String?) ?? '');
    contact.id = (entry['uid'] as String?) ?? '';
    contact
      ..propertiesFetched = true
      ..thumbnailFetched = true
      ..photoFetched = true
      ..isUnified = true;
    return contact;
  }

  /// Linux insert: vCard round trip through Evolution Data Server.
  static Future<Contact> _insertLinux(String vCard) async {
    final json = await _channel.invokeMethod<Map<Object?, Object?>>('insert', [
      vCard,
    ]);
    if (json == null) {
      throw StateError('Failed to insert contact');
    }
    return _contactFromLinuxEntry(Map<String, dynamic>.from(json));
  }

  /// Linux update: vCard round trip through Evolution Data Server.
  static Future<Contact> _updateLinux(String id, String vCard) async {
    final json = await _channel.invokeMethod<Map<Object?, Object?>>('update', [
      id,
      vCard,
    ]);
    if (json == null) {
      throw StateError('Failed to update contact');
    }
    final contact = _contactFromLinuxEntry(Map<String, dynamic>.from(json));
    if (contact.id.isEmpty) contact.id = id;
    return contact;
  }

  /// Orders display names naturally: case- and diacritic-insensitive, with
  /// numbers sorted after letters and blanks last. `Édouard` precedes `Elon`.
  ///
  /// Normalization (including ~190 diacritic passes) runs once per contact
  /// instead of once per comparison, which dominates large address books.
  static void _sortByDisplayName(List<Contact> contacts) {
    final keys = <Contact, String>{
      for (final c in contacts) c: _normalizeName(c.displayName),
    };
    contacts.sort((a, b) => _compareNormalized(keys[a]!, keys[b]!));
  }

  /// Natural ordering over pre-normalized names.
  static int _compareNormalized(String x, String y) {
    if (x.isEmpty && y.isNotEmpty) return 1;
    if (x.isEmpty && y.isEmpty) return 0;
    if (x.isNotEmpty && y.isEmpty) return -1;
    if (_alpha.hasMatch(x[0]) && !_alpha.hasMatch(y[0])) return -1;
    if (!_alpha.hasMatch(x[0]) && _alpha.hasMatch(y[0])) return 1;
    if (!_alpha.hasMatch(x[0]) && !_alpha.hasMatch(y[0])) {
      if (_numeric.hasMatch(x[0]) && !_numeric.hasMatch(y[0])) return -1;
      if (!_numeric.hasMatch(x[0]) && _numeric.hasMatch(y[0])) return 1;
    }
    return x.compareTo(y);
  }

  /// Normalizes a display name for comparison: trimmed, lower-cased and
  /// stripped of diacritics.
  static String _normalizeName(String name) =>
      removeDiacritics(name.trim().toLowerCase());
}

/// Convenience persistence operations on [Contact].
///
/// Defined here (rather than on [Contact] itself) so the data model stays
/// free of channel dependencies and the import graph stays acyclic.
extension ContactPersistence on Contact {
  /// Persists this contact and returns it as stored.
  Future<Contact> insert() => FlContacts.insertContact(this);

  /// Persists this contact's changes and returns it as stored.
  Future<Contact> update({bool withGroups = false}) =>
      FlContacts.updateContact(this, withGroups: withGroups);

  /// Removes this contact from the database.
  Future<void> delete() => FlContacts.deleteContact(this);
}
