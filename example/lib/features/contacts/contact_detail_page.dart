import 'package:fl_contacts/fl_contacts.dart';
import 'package:fl_contacts_example/core/providers/contacts_providers.dart';
import 'package:fl_contacts_example/core/providers/permission_providers.dart';
import 'package:fl_contacts_example/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Full contact detail with edit, delete, vCard and external actions.
class ContactDetailPage extends ConsumerWidget {
  const ContactDetailPage({required this.contactId, super.key});

  final String contactId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete contact?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final contact = await ref.read(contactDetailProvider(contactId).future);
    if (contact == null || !context.mounted) return;
    await contact.delete();
    ref.invalidate(databaseVersionProvider);
    if (context.mounted) context.pop();
  }

  Future<void> _export(BuildContext context, Contact contact) async {
    final vcard = contact.toVCard(withPhoto: false);
    await Clipboard.setData(ClipboardData(text: vcard));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'vCard copied (${contact.extras.length} extras preserved)',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contact = ref.watch(contactDetailProvider(contactId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => ContactEditorRouteData(id: contactId)
                .push<bool>(context)
                .then((_) => ref.invalidate(contactDetailProvider(contactId))),
          ),
        ],
      ),
      body: contact.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Load error: $e')),
        data: (c) {
          if (c == null) {
            return const Center(child: Text('Contact not found'));
          }
          return ListView(
            children: [
              if (c.photoOrThumbnail != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: CircleAvatar(
                    radius: 48,
                    backgroundImage: MemoryImage(c.photoOrThumbnail!),
                  ),
                ),
              ListTile(
                title: Text(
                  c.displayName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                subtitle: Text(c.name.nickname.isEmpty
                    ? ''
                    : '"${c.name.nickname}"'),
              ),
              for (final p in c.phones)
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: Text(p.number),
                  subtitle: Text(p.label.name),
                ),
              for (final e in c.emails)
                ListTile(
                  leading: const Icon(Icons.email),
                  title: Text(e.address),
                  subtitle: Text(e.label.name),
                ),
              for (final a in c.addresses)
                ListTile(
                  leading: const Icon(Icons.home),
                  title: Text(a.address),
                  subtitle: Text(a.label.name),
                ),
              const Divider(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: () => _export(context, c),
                    child: const Text('Copy vCard'),
                  ),
                  FilledButton.tonal(
                    onPressed: () =>
                        FlContacts.openExternalView(c.id),
                    child: const Text('System view'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => FlContacts.openExternalEdit(c.id),
                    child: const Text('System edit'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => _delete(context, ref),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
