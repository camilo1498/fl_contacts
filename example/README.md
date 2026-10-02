# fl_contacts example

Minimal contacts browser built on
[`fl_contacts`](../README.md): requests permission, lists every contact
with its thumbnail, filters by name, and refreshes on pull.

Run it with:

```sh
flutter run
```

Remember the platform setup from the main README: `NSContactsUsageDescription`
in the iOS `Info.plist` (Android permissions are merged from the plugin).
