import 'package:fl_contacts/fl_contacts.dart';
import 'package:fl_contacts_example/core/providers/permission_providers.dart';
import 'package:fl_contacts_example/features/contacts/presentation/widgets/contact_list_body.dart';
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
                onPressed: () => ref.invalidate(permissionStatusProvider),
                child: const Text('Grant contact permission'),
              ),
            ),
          );
        }
        return const ContactListBody();
      },
    );
  }
}
