import 'package:fl_contacts/fl_contacts.dart';
import 'package:fl_contacts_example/core/router/app_router.dart';
import 'package:fl_contacts_example/core/widgets/contact_avatar.dart';
import 'package:fl_contacts_example/core/widgets/contact_header.dart';
import 'package:fl_contacts_example/core/widgets/dialogs.dart';
import 'package:fl_contacts_example/core/widgets/empty_state.dart';
import 'package:fl_contacts_example/core/widgets/property_row.dart';
import 'package:fl_contacts_example/core/widgets/section_card.dart';
import 'package:fl_contacts_example/features/contacts/application/contact_detail_controller.dart';
import 'package:fl_contacts_example/features/contacts/application/contacts_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Full contact detail with edit, delete, vCard and external actions.
class ContactDetailPage extends ConsumerWidget {
  const ContactDetailPage({required this.contactId, super.key});

  final String contactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contact = ref.watch(contactDetailProvider(contactId));
    final controller =
        ref.watch(contactDetailControllerProvider.notifier);
    return Scaffold(
      body: contact.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Load error: $e')),
        data: (c) {
          if (c == null) {
            return const EmptyState(
              icon: Icons.person_off,
              title: 'Contact not found',
              subtitle: 'It may have been deleted elsewhere.',
            );
          }
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 220,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () =>
                        ContactEditorRouteData(id: contactId).push(context),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: ContactHeader(contact: c),
                ),
              ),
              SliverList.list(
                children: [
                  if (c.photoOrThumbnail != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          ContactAvatar.fromContact(c, radius: 28),
                          const SizedBox(width: 12),
                          const Text('Synced photo'),
                        ],
                      ),
                    ),
                  if (c.phones.isNotEmpty)
                    SectionCard(
                      title: 'Phones',
                      children: [
                        for (final p in c.phones)
                          PropertyRow(
                            icon: Icons.phone,
                            title: p.number,
                            label: p.label == PhoneLabel.custom
                                ? p.customLabel
                                : p.label.name,
                          ),
                      ],
                    ),
                  if (c.emails.isNotEmpty)
                    SectionCard(
                      title: 'Emails',
                      children: [
                        for (final e in c.emails)
                          PropertyRow(
                            icon: Icons.email,
                            title: e.address,
                            label: e.label == EmailLabel.custom
                                ? e.customLabel
                                : e.label.name,
                          ),
                      ],
                    ),
                  if (c.addresses.isNotEmpty)
                    SectionCard(
                      title: 'Addresses',
                      children: [
                        for (final a in c.addresses)
                          PropertyRow(
                            icon: Icons.home,
                            title: a.address,
                            label: a.label.name,
                          ),
                      ],
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonal(
                          onPressed: () async {
                            final vcard =
                                await controller.exportVCard(contactId);
                            if (vcard == null || !context.mounted) return;
                            await Clipboard.setData(
                              ClipboardData(text: vcard),
                            );
                            if (context.mounted) {
                              showMessage(
                                context,
                                'vCard copied '
                                '(${c.extras.length} extras)',
                              );
                            }
                          },
                          child: const Text('Copy vCard'),
                        ),
                        FilledButton.tonal(
                          onPressed: () =>
                              FlContacts.openExternalView(c.id),
                          child: const Text('System view'),
                        ),
                        FilledButton.tonal(
                          onPressed: () =>
                              FlContacts.openExternalEdit(c.id),
                          child: const Text('System edit'),
                        ),
                        FilledButton.tonal(
                          onPressed: () async {
                            final confirmed = await showConfirmDialog(
                              context,
                              title: 'Delete contact?',
                            );
                            if (!confirmed || !context.mounted) return;
                            await controller.delete(contactId);
                            if (context.mounted) context.pop();
                          },
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
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
