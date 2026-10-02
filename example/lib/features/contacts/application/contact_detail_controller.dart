import 'package:fl_contacts/fl_contacts.dart';
import 'package:fl_contacts_example/core/providers/sync_providers.dart';
import 'package:fl_contacts_example/features/contacts/application/contacts_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Detail-screen actions: delete and vCard export.
///
/// Data stays in [contactDetailProvider]; this controller only performs
/// mutations and refreshes the shared version counter. The contact ID
/// travels per call, so no family is needed.
class ContactDetailController extends Notifier<void> {
  @override
  void build() {}

  /// Deletes the contact [id] and bumps the database version.
  Future<void> delete(String id) async {
    final contact = await ref.read(contactDetailProvider(id).future);
    if (contact == null) return;
    await contact.delete();
    ref.read(databaseVersionProvider.notifier).bump();
  }

  /// Serializes the contact [id] without photos for sharing.
  Future<String?> exportVCard(String id) async {
    final contact = await ref.read(contactDetailProvider(id).future);
    return contact?.toVCard(withPhoto: false);
  }
}

/// Detail actions.
final contactDetailControllerProvider =
    NotifierProvider<ContactDetailController, void>(
  ContactDetailController.new,
);
