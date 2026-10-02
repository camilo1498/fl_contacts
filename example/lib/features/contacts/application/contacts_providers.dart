import 'package:fl_contacts/fl_contacts.dart';
import 'package:fl_contacts_example/core/providers/sync_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Live search query typed in the contacts list.
final contactsQueryProvider =
    NotifierProvider<ContactsQueryNotifier, String>(
  ContactsQueryNotifier.new,
);

/// Mutable search text holder.
class ContactsQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  /// Replaces the query, triggering a refetch.
  set query(String value) => state = value;
}

/// Fully hydrated contacts matching the query, reloaded on every change.
final contactsListProvider = FutureProvider<List<Contact>>((ref) async {
  ref.watch(databaseVersionProvider);
  ref.watch(databaseWatcherProvider);
  final query = ref.watch(contactsQueryProvider).trim();
  return FlContacts.getContacts(
    withProperties: true,
    withThumbnail: true,
    filter: query.isEmpty ? null : ContactFilter.name(query),
  );
});

/// One contact by ID. Auto-disposed when the detail page closes.
final contactDetailProvider =
    FutureProvider.family<Contact?, String>((ref, id) async {
  ref.watch(databaseVersionProvider);
  return FlContacts.getContact(
    id,
    withProperties: true,
    withPhoto: true,
    withGroups: true,
  );
});
