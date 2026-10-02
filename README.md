# fl_contacts

[![pub package](https://img.shields.io/pub/v/fl_contacts.svg)](https://pub.dev/packages/fl_contacts)
[![pub points](https://img.shields.io/pub/points/fl_contacts)](https://pub.dev/packages/fl_contacts/score)
[![popularity](https://img.shields.io/pub/popularity/fl_contacts)](https://pub.dev/packages/fl_contacts/score)
[![likes](https://img.shields.io/pub/likes/fl_contacts)](https://pub.dev/packages/fl_contacts/score)
[![license](https://img.shields.io/github/license/QuisApp/fl_contacts)](https://github.com/QuisApp/fl_contacts/blob/master/LICENSE)
[![platform](https://img.shields.io/badge/platform-android%20%7C%20ios%20%7C%20macos%20%7C%20windows%20%7C%20linux-blue)](https://pub.dev/packages/fl_contacts)

A fast, complete Flutter plugin for **native contact management** on Android
and iOS: read, create, update, delete and observe contacts, manage groups
(labels on Android), exchange vCards, use the system contact UI, and handle
runtime permissions — through one clean Dart API.

Building a full contacts app takes an afternoon, not a sprint: fetch unified
contacts with a single call, render photos from memory, and let the OS do the
heavy lifting for picking, editing and syncing.

```dart
import 'package:fl_contacts/fl_contacts.dart';

// 1. Ask for permission.
if (await FlContacts.requestPermission()) {
  // 2. Read every contact, fully populated and sorted.
  final contacts = await FlContacts.getContacts(
    withProperties: true,
    withPhoto: true,
  );
  // 3. Create one.
  final john = Contact()
    ..name.first = 'John'
    ..name.last = 'Smith'
    ..phones = [Phone('555-123-4567')];
  await john.insert();
}
```

## Features

- **CRUD** — insert, update and delete unified contacts with one-liners.
- **Rich reads** — names, phones, emails, addresses, organizations, websites,
  social/IM profiles, events, notes, photos, thumbnails, starred flag,
  accounts and groups.
- **Fast list mode** — fetch IDs + display names only for instant lists, then
  hydrate on demand.
- **Sorting & dedup** — locale-friendly sorting (case- and diacritic-insensitive,
  numbers after letters) and property deduplication out of the box.
- **Groups** — read, create, rename and delete groups (iOS) / labels (Android),
  including membership.
- **Live updates** — coarse database pings plus typed per-contact diffs
  (`added`/`updated`/`removed` with IDs) on every platform.
- **Batch & search** — multi-insert/update over one round trip, native
  `ContactFilter` (IDs, group, name, phone, email) and result limits.
- **More natives** — SIM contacts, Me-card profile, number blocking and
  ringtones (Android), group membership everywhere.
- **vCard 3.0 & 4.0** — import (`Contact.fromVCard`, multi-card
  `fromVCardList`) and export with quoted-printable, folding, grouped
  properties and lossless `VCardExtra` round trips.
- **Permissions** — one call for read or read/write access, status checks,
  settings shortcuts, and iOS 18 limited-access support.

## Requirements

| Stack | Minimum |
|---|---|
| Flutter | 3.44.0 |
| Dart | 3.12.0 |
| Android | minSdk 24 · compileSdk 36 · Java 17 · AGP 9.x (built-in Kotlin) · thumbnails downsampled to 192 px natively |
| iOS | 13.0+ · Xcode 16+ · Swift 5 language mode |
| macOS | 10.15+ · Xcode 16+ (Contacts framework, no system contact UI) |
| Windows | Windows 10 1809+ (WinRT contact store) |
| Linux | Evolution Data Server running on the session bus |

iOS integrates through **Swift Package Manager** (`ios/fl_contacts/Package.swift`)
when enabled, with **CocoaPods** (`ios/fl_contacts.podspec`) as fallback.
macOS mirrors it (`macos/fl_contacts/`).

## Installation

Add the dependency:

```yaml
dependencies:
  fl_contacts: ^1.3.0
```

**iOS and macOS** — add the usage description to your app's `Info.plist`:

```xml
<plist version="1.0">
<dict>
    ...
    <key>NSContactsUsageDescription</key>
    <string>We need access to your contacts to show and manage them.</string>
</dict>
</plist>
```

On macOS the sandboxed Runner additionally needs the address-book
entitlement in both `DebugProfile.entitlements` and `Release.entitlements`:

```xml
<dict>
    ...
    <key>com.apple.security.personal-information.addressbook</key>
    <true/>
</dict>
</plist>
```

**Android** — nothing to declare: the plugin manifest already merges
`READ_CONTACTS` and `WRITE_CONTACTS`, and runtime permission is requested for
you. (Read-only flows can request just `READ_CONTACTS`, see below.)

## Usage

### Requesting permission

```dart
// Read + write (default).
final granted = await FlContacts.requestPermission();

// Android only: read-only mode requests just READ_CONTACTS.
final readOnly = await FlContacts.requestPermission(readonly: true);
```

On iOS 18+, users may grant **limited** access; `requestPermission()` returns
`true` for both full and limited grants, and fetches return the contacts the
user selected.

### Reading contacts

```dart
// Lightweight: IDs + display names, sorted, deduplicated.
final all = await FlContacts.getContacts();

// Fully hydrated: properties, low-res thumbnails and hi-res photos.
final full = await FlContacts.getContacts(
  withProperties: true,
  withThumbnail: true,
  withPhoto: true,
  withGroups: true,    // groups (iOS) / labels (Android)
  withAccounts: true,  // raw accounts (Android) / containers (iOS)
);

// A single contact by ID.
final contact = await FlContacts.getContact(full.first.id);
if (contact != null) {
  debugPrint(contact.displayName);
  debugPrint(contact.phones.map((p) => p.number).join(', '));
}
```

### Creating, updating and deleting

```dart
// Create.
final contact = Contact()
  ..name.first = 'Ada'
  ..name.last = 'Lovelace'
  ..phones = [Phone('+1-555-0100', label: PhoneLabel.work)]
  ..emails = [Email('ada@example.com', label: EmailLabel.work)];
final saved = await contact.insert(); // or FlContacts.insertContact(contact)

// Update (fetch with properties + photo first so nothing is erased).
saved.name.nickname = 'The Enchantress';
final updated = await saved.update();

// Delete.
await updated.delete(); // or FlContacts.deleteContact(updated)
await FlContacts.deleteContacts([saved]);
```

### Groups (iOS) / labels (Android)

```dart
final groups = await FlContacts.getGroups();

final coworkers = await FlContacts.insertGroup(Group('', 'Coworkers'));
coworkers.name = 'Close coworkers';
await FlContacts.updateGroup(coworkers);
await FlContacts.deleteGroup(coworkers);
```

### Observing changes

The OS only reports *that* something changed — not what. Re-fetch when notified:

```dart
void refresh() {
  // Reload your contact list here.
}

FlContacts.addListener(refresh);
// Later:
FlContacts.removeListener(refresh);
```

### System contact UI

Hand off to the native contacts app and await the outcome:

```dart
await FlContacts.openExternalView(contact.id);
final edited = await FlContacts.openExternalEdit(contact.id);
final picked = await FlContacts.openExternalPick();
final created = await FlContacts.openExternalInsert(
  Contact()..name.first = 'Grace', // pre-fills the editor
);
```

### vCard import / export

```dart
FlContacts.config.vCardVersion = VCardVersion.v4; // or VCardVersion.v3 (default)

final vcard = contact.toVCard(withPhoto: true);
final imported = Contact.fromVCard(vcard);
await imported.insert();
```

### Global configuration

```dart
FlContacts.config
  ..returnUnifiedContacts = true       // unified vs raw contacts
  ..includeNonVisibleOnAndroid = false // contacts outside any group
  ..includeNotesOnIos13AndAbove = false // requires an Apple entitlement
  ..vCardVersion = VCardVersion.v3;
```

## Data model

Every property is non-nullable except `thumbnail`/`photo` (`Uint8List?`) and
`Event.year` (`int?`, for year-less dates). Strings default to `''`, lists to
`[]`, labels to a sensible default.

```dart
Contact {
  String id, displayName;
  Uint8List? photo, thumbnail;   // photoOrThumbnail picks the best available
  bool isStarred;                // Android only
  Name name;                     // first, last, middle, prefix, suffix, nickname, phonetics
  List<Phone> phones;            // number, normalizedNumber (Android), label, customLabel, isPrimary
  List<Email> emails;            // address, label, customLabel, isPrimary
  List<Address> addresses;       // formatted + structured parts (street, city, …)
  List<Organization> organizations; // company, title, department, …
  List<Website> websites;        // url, label, customLabel
  List<SocialMedia> socialMedias;// userName, label, customLabel
  List<Event> events;            // year?, month, day, label, customLabel
  List<Note> notes;              // one on iOS, many on Android
  List<Account> accounts;        // rawId, type, name, mimetypes
  List<Group> groups;            // id, name
}
```

Labels are platform-aware enums (`PhoneLabel`, `EmailLabel`, `AddressLabel`,
`EventLabel`, `WebsiteLabel`, `SocialMediaLabel`) with a `custom` value plus
`customLabel` for anything the OS reports outside the known set.

## Platform notes

| Topic | Android | iOS | macOS | Windows | Linux |
|---|---|---|---|---|---|
| Unified vs raw | Unified by default; raw via `returnUnifiedContacts = false` (read-only) | Same | Same | Single store | Single book |
| Starred | Supported | Not supported | Not supported | Not supported | Not supported |
| `isPrimary` phones/emails | Supported | Not supported | Not supported | Not supported | Parsed from vCard |
| Notes | Multiple | One; on iOS 13+ needs the [Apple contacts-notes entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_developer_contacts_notes) plus `includeNotesOnIos13AndAbove = true` | Same as iOS | Not supported | Parsed from vCard |
| Events | Multiple incl. custom | One birthday + labeled dates | Same as iOS | Not supported | Parsed from vCard |
| Groups | Labels + membership | Groups + membership | Groups + membership | Contact lists (copies get fresh IDs) | Emergent from `CATEGORIES`; read + membership only |
| Limited access | N/A | iOS 18+ `.limited` treated as granted | N/A | N/A | N/A |
| Permissions | `READ/WRITE_CONTACTS` runtime | `NSContactsUsageDescription` required | Contacts prompt | Store consent prompt | EDS reachability |
| System contact UI | Supported | Supported | Not supported | Not supported | Not supported |
| SIM / blocked / ringtones | Supported | Not supported | Not supported | Not supported | Not supported |
| Profile ("Me") | Supported | Not supported | Supported | Not supported | Not supported |

## Example

A runnable contacts browser lives in [`example/`](example/) — permission
request, searchable list with thumbnails, and pull-to-refresh in one file.

## API reference

Full dartdoc for every class and method is published on
[pub.dev/documentation](https://pub.dev/documentation/fl_contacts/latest/).
Behavioral changes are tracked in [CHANGELOG.md](CHANGELOG.md).

## Contributing

Issues and pull requests are welcome at
[QuisApp/fl_contacts](https://github.com/QuisApp/fl_contacts).
Please run `dart format`, `flutter analyze` and `flutter test` before
submitting.

## License

MIT — see [LICENSE](LICENSE).
