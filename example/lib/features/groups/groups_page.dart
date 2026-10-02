import 'package:fl_contacts/fl_contacts.dart';
import 'package:fl_contacts_example/core/providers/contacts_providers.dart';
import 'package:fl_contacts_example/core/providers/permission_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Group browser with create, rename, delete and member editing.
class GroupsPage extends ConsumerWidget {
  const GroupsPage({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Coworkers'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    try {
      await FlContacts.insertGroup(Group('', name));
    } on UnsupportedError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Not supported here')),
        );
      }
      return;
    }
    ref.invalidate(databaseVersionProvider);
  }

  Future<void> _members(
    BuildContext context,
    WidgetRef ref,
    Group group,
  ) async {
    final contacts = await FlContacts.getContacts(withGroups: true);
    final initial = {
      for (final c in contacts)
        if (c.groups.any((g) => g.id == group.id)) c.id,
    };
    if (!context.mounted) return;
    final picked = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _MemberPicker(
        contacts: contacts,
        initial: initial,
      ),
    );
    if (picked == null) return;
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
    ref.invalidate(databaseVersionProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Groups')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _create(context, ref),
        child: const Icon(Icons.group_add),
      ),
      body: groups.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Load error: $e')),
        data: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(groupsProvider),
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final group = list[index];
              return ListTile(
                leading: const Icon(Icons.label),
                title: Text(group.name),
                onTap: () => _members(context, ref, group),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'rename') {
                      final controller =
                          TextEditingController(text: group.name);
                      final name = await showDialog<String>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Rename group'),
                          content: TextField(controller: controller),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(
                                context,
                                controller.text.trim(),
                              ),
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      );
                      controller.dispose();
                      if (name == null || name.isEmpty) return;
                      group.name = name;
                      await FlContacts.updateGroup(group);
                      ref.invalidate(databaseVersionProvider);
                    } else {
                      await FlContacts.deleteGroup(group);
                      ref.invalidate(databaseVersionProvider);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Checkbox list of contacts for group membership editing.
class _MemberPicker extends StatefulWidget {
  const _MemberPicker({required this.contacts, required this.initial});

  final List<Contact> contacts;
  final Set<String> initial;

  @override
  State<_MemberPicker> createState() => _MemberPickerState();
}

class _MemberPickerState extends State<_MemberPicker> {
  late Set<String> _picked;

  @override
  void initState() {
    super.initState();
    _picked = Set.of(widget.initial);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Members'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.contacts.length,
          itemBuilder: (context, index) {
            final contact = widget.contacts[index];
            return CheckboxListTile(
              title: Text(contact.displayName),
              value: _picked.contains(contact.id),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _picked.add(contact.id);
                } else {
                  _picked.remove(contact.id);
                }
              }),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _picked),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
