import 'package:fl_contacts_example/core/providers/sync_providers.dart';
import 'package:fl_contacts_example/core/router/app_router.dart';
import 'package:fl_contacts_example/core/theme/app_theme.dart';
import 'package:fl_contacts_example/core/widgets/contact_list_tile.dart';
import 'package:fl_contacts_example/core/widgets/empty_state.dart';
import 'package:fl_contacts_example/features/contacts/application/contacts_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Scrollable contact list body: search, count, rows and refresh.
///
/// Separated from [ContactsListPage] so the permission gate stays a thin
/// switch while this widget owns the whole list experience.
class ContactListBody extends ConsumerWidget {
  const ContactListBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            icon: const Icon(Icons.brightness_6),
            onPressed: () => ref.read(themeModeProvider.notifier).next(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            const ContactEditorRouteData(id: 'new').push(context),
        child: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SearchBar(
              hintText: 'Search contacts',
              leading: const Icon(Icons.search),
              onChanged: (v) =>
                  ref.read(contactsQueryProvider.notifier).query = v,
            ),
          ),
          Expanded(
            child: contacts.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Load error: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.person_search,
                    title: 'No contacts found',
                    subtitle: 'Try another search or pull to refresh.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref
                      ..invalidate(contactsListProvider)
                      ..invalidate(databaseVersionProvider);
                  },
                  child: ListView.builder(
                    itemCount: list.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Text(
                            '${list.length} contacts',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        );
                      }
                      final contact = list[index - 1];
                      return ContactListTile(
                        contact: contact,
                        subtitle: contact.phones.isNotEmpty
                            ? contact.phones.first.number
                            : 'No phone number',
                        onTap: () => ContactDetailRouteData(
                          id: contact.id,
                        ).push(context),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
