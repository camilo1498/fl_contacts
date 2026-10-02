## 1.3.1

* Fix scroll jank on contact lists: provider thumbnail blobs are often
  full-size photos, decoded per frame. Thumbnails are now downsampled
  natively (longest side `FlContactsConfig.thumbnailMaxSize`, 192 px by
  default, format-preserving, with byte-identical fallback) on a
  background thread before crossing the channel. Set it to 0 to keep the
  original bytes. Full-resolution `photo` fetches are untouched.

## 1.3.0

* Renamed package `flutter_contacts` → `fl_contacts`: Dart package and
  imports, `FlContacts` / `FlContactsPlugin` classes, Android application
  ID, iOS/macOS modules, method channels and docs. GitHub issue links in
  older entries still point at their original locations.
* New platforms: macOS (Contacts framework, SPM + CocoaPods, Me-card
  profile), Windows (WinRT contact store with CRUD, lists-as-groups and
  change polling) and Linux (Evolution Data Server over D-Bus, vCard
  shuttling, live view signals). Desktop system-contact UI stays
  mobile-only and now throws `UnsupportedError` instead of hanging.
* New features on every mobile platform, additive only:
  - batch `insertContacts` / `updateContacts` over one channel round trip
  - `ContactFilter` (IDs, group, name, phone, email) plus `limit`,
    evaluated natively
  - group membership APIs: `addContactsToGroup`,
    `removeContactsFromGroup`, `getGroupsOf`
  - `ContactChange` typed stream (`onContactChanged`: added/updated/removed
    with IDs) next to the coarse `onDatabaseChanged` broadcast; legacy
    `addListener` / `removeListener` keep working on top of it
  - `VCardExtra` round trip: unknown properties survive import/export
  - `FlBlockedNumbers` (Android), `FlRingtones` (Android),
    `getSimContacts` (Android), `getProfile` (Android/macOS),
    `checkPermissionStatus` and `openAppSettings`
* Performance: debounced, fingerprinted change tracking off the UI thread
  on all platforms; worker-thread D-Bus/WinRT calls with main-thread
  result delivery on desktop.

## 1.2.0

* Modernize to the current Flutter / Android / iOS toolchains:
  - Require Dart `^3.12.0` and Flutter `>=3.44.0`; replace discontinued
    `pedantic` with `flutter_lints ^6.0.0`
  - Android: AGP `9.1.0` with built-in Kotlin (no `kotlin-android` plugin),
    Gradle `9.3.1`, `compileSdk 36`, `minSdk 24`, Java/Kotlin 17,
    coroutines `1.11.0`; declare `READ/WRITE_CONTACTS` in the plugin
    manifest; drop unused `kotlinx-serialization` dependency
  - iOS: deployment target `13.0`, Swift Package Manager support
    (`ios/fl_contacts/Package.swift`, shared `Sources/` layout, privacy
    manifest) alongside CocoaPods; pure-Swift plugin class
    (`FlContactsPlugin`, ObjC shim removed); scene-based view-controller
    lookup, limited-access (`.limited`) permission support on iOS 18+,
    results delivered on the main thread
* Fix Android `getQuick` always reporting `isStarred == false` (wrong column
  and inverted comparison)
* Fix Android permission / activity-result futures hanging forever when the
  request is interrupted or no activity is attached, and leaking listeners
  across hot restart
* Fix iOS contact-change observer leak (`removeObserver(self)` never removed
  block-based observers) and the `UIApplication.delegate!.window!!` crash on
  multi-scene apps
* Fix vCard parser emitting every valueless parameter twice, crashing on
  `TYPE` without a value, and dropping `IMPP` usernames containing colons
* Fix iOS birthday parsing overwriting the sanitized year, and `mySpace`
  labels never matching on insert
* Harden all platform-channel parsing with typed method calls and null-safe
  casts on both Dart and native sides
* Migrate value types to `Object.hash`, content-based photo equality, and
  collision-free property deduplication

## 1.1.7+1

- Fix for AGP <4.2 (https://github.com/QuisApp/flutter_contacts/issues/127) - thanks trfiladelfo

## 1.1.7

- Add feature to pre-populate fields in openExternalInsert() - thanks sakchhams
- Fix openExternalView and openExternalEdit on iOS (https://github.com/QuisApp/flutter_contacts/issues/91, https://github.com/QuisApp/flutter_contacts/issues/70)
- Support Gradle 8 (https://github.com/QuisApp/flutter_contacts/issues/123)
- Fix fetching notes on iOS - thanks starshipcoder and yassinsameh
- Fix bug with address label default on iOS - thanks MohamedAl-Kainai and yassinsameh

## 1.1.6

- Update kotlin/gradle versions (https://github.com/QuisApp/flutter_contacts/issues/69)

## 1.1.5+1

- Fix null pointer error (https://github.com/QuisApp/flutter_contacts/pull/71 - thanks anggrayudi)
- Update README

## 1.1.5

- Edit groups (iOS) / labels (Android) and group/label membership

## 1.1.4

- Fix gradle compile error (https://github.com/QuisApp/flutter_contacts/issues/49)

## 1.1.3

- Fix social media custom label bug (https://github.com/QuisApp/flutter_contacts/issues/42)

## 1.1.2

- Read/write starred contacts on Android (https://github.com/QuisApp/flutter_contacts/issues/37)
- Fix vCard photo encoding (https://github.com/QuisApp/flutter_contacts/issues/34)

## 1.1.1+2

- Update comments

## 1.1.1+1

- Update README

## 1.1.1

- Fetch groups (iOS) / labels (Android) and containers (iOS) / accounts (Android) (https://github.com/QuisApp/flutter_contacts/issues/29)
- Ability to request read-only permissions (https://github.com/QuisApp/flutter_contacts/issues/25)

## 1.1.0+4

- Load rawContact instead of contactId after update, since Android sometimes changes the contactId

## 1.1.0+3

- Fix withThumbnail on iOS

## 1.1.0+2

- Fix hashCode and ==

## 1.1.0+1

- Fix a diacritics bug

## 1.1.0

- Add ability to open external contact app to view, edit, pick or insert contacts (https://github.com/QuisApp/flutter_contacts/issues/16)

## 1.0.0+1

- Fix for permission handler on Android (https://github.com/QuisApp/flutter_contacts/pull/17) - thanks @scroollocker
- Fix type cast error on iOS 14.5 (https://github.com/QuisApp/flutter_contacts/issues/19) - thanks @jadasi

## 1.0.0

- Stable release 🎉
- Follow-up fix for https://github.com/QuisApp/flutter_contacts/issues/9
- Fix https://github.com/QuisApp/flutter_contacts/issues/14

## 0.3.3+1

- Fix https://github.com/QuisApp/flutter_contacts/issues/9

## 0.3.3

- Fix lint warning

## 0.3.2

- Remove unused dependency

## 0.3.1

- Change Dart SDK version requirements

## 0.3.0

- Migrated to null-safety

## 0.2.2

- Support for requesting permissions
- Option to return non-visible contacts on Android and raw contacts on Android/iOS
  (https://github.com/QuisApp/flutter_contacts/issues/5)

## 0.2.1

- Format

## 0.2.0

- Not backward compatible!
- Photo and thumbnail are now distinct fields
- `Event.date` is now `Event.year`, `Event.month`, `Event.day`
- Convenience methods `contact.insert()`, `contact.update()`, `contact.delete()`
- Much more advanced vCard parsing and exporting (to version 3.0 and 4.0)
- We can now add multiple listeners
- Removed dependencies to `build_runner` and `json_serializable`
- Implemented `toString()`, `hashCode` and `operator==` for contact and properties
- Support for notes on iOS13+ by setting
  `FlContacts.config.includeNotesOnIos13AndAbove = true`
- Added tests

## 0.1.3

- Remove extra print statements

## 0.1.2

- Properly delete events on iOS (https://github.com/QuisApp/flutter_contacts/issues/2)

## 0.1.1

- Fix date serialization on Android (https://github.com/QuisApp/flutter_contacts/issues/2)

## 0.1.0

- Support for vCard parsing and exporting
- Add `pedantic` static analyzer
- Make default values non-const so they can be mutated
- Add tests
- Update dependencies
- Deduplicate events
- Rename `socialMedia.dart` -> `social_media.dart`

## 0.0.7

- Bug fix with normalized phone number

## 0.0.6

- Added normalized phone numbers (android only)
- Deduplicate phone numbers and emails by default

## 0.0.5

- Improved README and dartdoc.
- Added option to `getFullContacts()` with high-res photos.
- Fixed bug on iOS where low-res photos were fetched instead of high-res and vice-versa.
- Better Kotlin null safety.

## 0.0.4

- `newContact()` now returns the full contact instead of ID / raw ID.

## 0.0.3

- Fix README typos.

## 0.0.2

- Fix support for iOS.

## 0.0.1

- Initial release.
