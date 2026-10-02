import 'package:fl_contacts/fl_contacts.dart';
import 'package:fl_contacts_example/core/providers/sync_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// All groups (labels), reloaded on every database change.
final groupsProvider = FutureProvider<List<Group>>((ref) async {
  ref.watch(databaseVersionProvider);
  return FlContacts.getGroups();
});

/// Group CRUD plus membership diffing.
///
/// Pages collect user intent (names, picked IDs); this controller executes
/// provider calls and refreshes shared state.
class GroupsController extends Notifier<void> {
  @override
  void build() {}

  /// Creates a group and refreshes lists.
  Future<void> create(String name) async {
    await FlContacts.insertGroup(Group('', name));
    _refresh();
  }

  /// Renames [group] in place and refreshes lists.
  Future<void> rename(Group group, String name) async {
    group.name = name;
    await FlContacts.updateGroup(group);
    _refresh();
  }

  /// Deletes [group] and refreshes lists.
  Future<void> delete(Group group) async {
    await FlContacts.deleteGroup(group);
    _refresh();
  }

  /// Applies a picked member set, adding and removing the delta.
  Future<void> setMembers(Group group, Set<String> picked) async {
    final contacts = await FlContacts.getContacts(withGroups: true);
    final initial = {
      for (final c in contacts)
        if (c.groups.any((g) => g.id == group.id)) c.id,
    };
    final added = picked.difference(initial).toList();
    final removed = initial.difference(picked).toList();
    if (added.isNotEmpty) {
      await FlContacts.addContactsToGroup(
        groupId: group.id,
        contactIds: added,
      );
    }
    if (removed.isNotEmpty) {
      await FlContacts.removeContactsFromGroup(
        groupId: group.id,
        contactIds: removed,
      );
    }
    _refresh();
  }

  /// Member IDs of [groupId] from one hydrated fetch.
  Future<Set<String>> memberIds(String groupId) async {
    final contacts = await FlContacts.getContacts(withGroups: true);
    return {
      for (final c in contacts)
        if (c.groups.any((g) => g.id == groupId)) c.id,
    };
  }

  void _refresh() {
    ref
      ..invalidate(groupsProvider)
      ..read(databaseVersionProvider.notifier).bump();
  }
}

/// Group mutations.
final groupsControllerProvider =
    NotifierProvider<GroupsController, void>(GroupsController.new);
