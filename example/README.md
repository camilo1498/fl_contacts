# fl_contacts example

Full demo app for [`fl_contacts`](../README.md) with layered architecture:

- **Riverpod** — `FutureProvider`/`StreamProvider` for permission, contacts,
  groups and device features; `NotifierProvider` for search text and refresh
  counters; a watcher subscribes to `onDatabaseChanged` once and refreshes
  every list (real-time updates).
- **GoRouter + go_router_builder** — typed routes in
  `lib/core/router/app_router.dart` (`dart run build_runner build` to
  regenerate `app_router.g.dart`); stateful shell with Contacts, Groups
  and Tools tabs.
- **Features** — searchable contact list with thumbnails, detail page with
  edit/delete/vCard/system-UI actions, contact creator/editor, group CRUD
  with member picker, and a tools page covering permissions, live change
  events, system pick/create, vCard export/parse, plus SIM, profile,
  blocked numbers and ringtones where the platform supports them.

Run it with:

```sh
flutter run
```

Remember the platform setup from the main README: `NSContactsUsageDescription`
in the iOS `Info.plist` (plus the address-book entitlement on macOS);
Android permissions are merged from the plugin.
