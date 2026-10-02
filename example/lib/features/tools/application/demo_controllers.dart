import 'package:fl_contacts/fl_contacts.dart';
import 'package:fl_contacts_example/core/application/demo_task.dart';
import 'package:fl_contacts_example/core/application/models/demo_task_state.dart';
import 'package:fl_contacts_example/core/providers/sync_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Inserts two sample contacts, updates them, then deletes them again.
class BatchDemoController extends DemoTaskController {
  @override
  Future<String> runTask() async {
    final created = await FlContacts.insertContacts([
      Contact()..name.first = 'Batch A',
      Contact()..name.first = 'Batch B',
    ]);
    for (final c in created) {
      c.name.last = 'Batched';
    }
    final updated = await FlContacts.updateContacts(created);
    await FlContacts.deleteContacts(updated);
    ref.invalidate(databaseVersionProvider);
    return 'Batch OK: ${updated.length} upserted + deleted';
  }
}

/// Batch insert/update/delete demo.
final batchDemoControllerProvider =
    NotifierProvider<BatchDemoController, DemoTaskState>(
  BatchDemoController.new,
);

/// Runs filtered fetches and reports match counts.
class FilterDemoController extends DemoTaskController {
  @override
  Future<String> runTask() async {
    final byPhone = await FlContacts.getContacts(
      filter: const ContactFilter.phone('555'),
      limit: 100,
    );
    final byEmail = await FlContacts.getContacts(
      filter: const ContactFilter.email('example.com'),
      limit: 100,
    );
    return 'Phone 555: ${byPhone.length}, email domain: ${byEmail.length}';
  }

  /// Fetches with [filter] (and optional [limit]), reporting the count.
  Future<void> runQuery(
    String label,
    ContactFilter filter, {
    int? limit,
  }) {
    return execute(() async {
      final contacts = await FlContacts.getContacts(
        filter: filter,
        limit: limit ?? 100,
      );
      return '$label: ${contacts.length} match(es)';
    });
  }
}

/// Native filter demo.
final filterDemoControllerProvider =
    NotifierProvider<FilterDemoController, DemoTaskState>(
  FilterDemoController.new,
);

/// Resolves the groups of the first contact.
class GroupsOfDemoController extends DemoTaskController {
  @override
  Future<String> runTask() async {
    final contacts = await FlContacts.getContacts(limit: 1);
    if (contacts.isEmpty) return 'No contacts';
    final groups = await FlContacts.getGroupsOf(contacts.first.id);
    return '${contacts.first.displayName}: '
        '${groups.map((g) => g.name).join(', ')}';
  }
}

/// Groups-of-contact demo.
final groupsOfDemoControllerProvider =
    NotifierProvider<GroupsOfDemoController, DemoTaskState>(
  GroupsOfDemoController.new,
);
