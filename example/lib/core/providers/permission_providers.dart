import 'package:fl_contacts/fl_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current contact-access state. Requests permission on first read.
final permissionStatusProvider =
    FutureProvider<FlPermissionStatus>((ref) async {
  final granted = await FlContacts.requestPermission();
  if (!granted) return FlPermissionStatus.denied;
  return FlContacts.checkPermissionStatus();
});

/// Recent typed change events for the activity feed.
final contactEventsProvider = StreamProvider<List<ContactChange>>((ref) {
  return FlContacts.onContactChanged;
});
