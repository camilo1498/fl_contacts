import 'package:fl_contacts/fl_contacts.dart';
import 'package:fl_contacts_example/core/providers/sync_providers.dart';
import 'package:fl_contacts_example/features/contacts/application/contacts_providers.dart';
import 'package:fl_contacts_example/features/contacts/application/models/contact_draft.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Persistence behind the contact editor form.
///
/// The page owns `TextEditingController`s and validation; this controller
/// maps the draft onto the model, persists it and refreshes lists.
class ContactEditorController extends Notifier<void> {
  @override
  void build() {}

  /// Inserts a new contact from [draft].
  Future<void> create(ContactDraft draft) async {
    final contact = Contact()
      ..name.first = draft.first
      ..name.last = draft.last;
    if (draft.phone.isNotEmpty) {
      contact.phones = [Phone(draft.phone)];
    }
    if (draft.email.isNotEmpty) {
      contact.emails = [Email(draft.email)];
    }
    await contact.insert();
    ref
      ..invalidate(contactsListProvider)
      ..read(databaseVersionProvider.notifier).bump();
  }

  /// Applies [draft] onto the fetched contact [id] and updates it.
  Future<void> update(String id, ContactDraft draft) async {
    final existing = await ref.read(contactDetailProvider(id).future);
    if (existing == null) {
      throw StateError('Contact no longer exists');
    }
    existing
      ..name.first = draft.first
      ..name.last = draft.last;
    if (draft.phone.isNotEmpty) {
      existing.phones = [Phone(draft.phone)];
    }
    if (draft.email.isNotEmpty) {
      existing.emails = [Email(draft.email)];
    }
    await existing.update();
    ref
      ..invalidate(contactsListProvider)
      ..invalidate(contactDetailProvider(id))
      ..read(databaseVersionProvider.notifier).bump();
  }
}

/// Editor persistence actions.
final contactEditorControllerProvider =
    NotifierProvider<ContactEditorController, void>(
  ContactEditorController.new,
);
