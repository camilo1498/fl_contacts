import 'package:fl_contacts/fl_contacts.dart';
import 'package:fl_contacts_example/core/providers/contacts_providers.dart';
import 'package:fl_contacts_example/core/providers/permission_providers.dart';
import 'package:fl_contacts_example/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Searchable contact list with thumbnails, live updates and CRUD entry.
class ContactsListPage extends ConsumerWidget {
  const ContactsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(permissionStatusProvider);
    return permission.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Permission error: $e')),
      ),
      data: (status) {
        if (status != FlPermissionStatus.granted &&
            status != FlPermissionStatus.limited) {
          return Scaffold(
            appBar: AppBar(title: const Text('fl_contacts')),
            body: Center(
              child: FilledButton(
                onPressed: () =>
                    ref.invalidate(permissionStatusProvider),
                child: const Text('Grant contact permission'),
              ),
            ),
          );
        }
        return const _ContactListBody();
      },
    );
  }
}

class _ContactListBody extends ConsumerWidget {
  const _ContactListBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            const ContactEditorRouteData(id: 'new').push(context),
        child: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SearchBar(
              hintText: 'Search contacts',
              onChanged: (v) =>
                  ref.read(contactsQueryProvider.notifier).query = v,
            ),
          ),
          Expanded(
            child: contacts.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Load error: $e')),
              data: (list) => RefreshIndicator(
                onRefresh: () async {
                  ref
                    ..invalidate(contactsListProvider)
                    ..invalidate(databaseVersionProvider);
                },
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final contact = list[index];
                    final thumbnail = contact.thumbnail;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: thumbnail != null
                            ? MemoryImage(thumbnail)
                            : null,
                        child: thumbnail == null
                            ? Text(
                                contact.displayName.isNotEmpty
                                    ? contact.displayName[0]
                                    : '?',
                              )
                            : null,
                      ),
                      title: Text(contact.displayName),
                      subtitle: Text(
                        contact.phones.isNotEmpty
                            ? contact.phones.first.number
                            : 'No phone number',
                      ),
                      onTap: () => ContactDetailRouteData(
                        id: contact.id,
                      ).push(context),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
