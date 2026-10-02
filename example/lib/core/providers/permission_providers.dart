import 'package:fl_contacts/fl_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current contact-access state. Requests permission on first read.
final permissionStatusProvider =
    FutureProvider<FlPermissionStatus>((ref) async {
  final granted = await FlContacts.requestPermission();
  if (!granted) return FlPermissionStatus.denied;
  return FlContacts.checkPermissionStatus();
});

/// Bumped whenever the database changes; refreshes dependent lists.
final databaseVersionProvider =
    NotifierProvider<DatabaseVersionNotifier, int>(
  DatabaseVersionNotifier.new,
);

/// Monotonic refresh counter.
class DatabaseVersionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Bumps the version, refreshing watchers.
  void bump() => state++;
}

/// Subscribes once and bumps [databaseVersionProvider] on every change.
final databaseWatcherProvider = Provider<void>((ref) {
  final sub = FlContacts.onDatabaseChanged.listen((_) {
    ref.read(databaseVersionProvider.notifier).bump();
  });
  ref.onDispose(sub.cancel);
});

/// Recent typed change events for the activity feed.
final contactEventsProvider = StreamProvider<List<ContactChange>>((ref) {
  return FlContacts.onContactChanged;
});
