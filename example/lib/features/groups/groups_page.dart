import 'package:fl_contacts/fl_contacts.dart';
import 'package:fl_contacts_example/core/widgets/contact_avatar.dart';
import 'package:fl_contacts_example/core/widgets/dialogs.dart';
import 'package:fl_contacts_example/core/widgets/empty_state.dart';
import 'package:fl_contacts_example/features/groups/application/groups_controller.dart';
import 'package:fl_contacts_example/features/groups/presentation/member_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Group browser delegating every mutation to [GroupsController].
class GroupsPage extends ConsumerWidget {
  const GroupsPage({super.key});
  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await _promptName(context, title: 'New group');
    if (name == null || name.isEmpty || !context.mounted) return;
    try {
      await ref.read(groupsControllerProvider.notifier).create(name);
    } on UnsupportedError catch (e) {
      if (context.mounted) {
        showMessage(context, e.message ?? 'Not supported here');
      }
    }
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, Group group) async {
    final name = await _promptName(
      context,
      title: 'Rename group',
      initial: group.name,
    );
    if (name == null || name.isEmpty) return;
    await ref.read(groupsControllerProvider.notifier).rename(group, name);
  }

  Future<void> _editMembers(BuildContext context, WidgetRef ref, Group group) async {
    final controller = ref.read(groupsControllerProvider.notifier);
    final contacts = await FlContacts.getContacts(withGroups: true);
    final initial = await controller.memberIds(group.id);
    if (!context.mounted) return;
    final picked = await showMemberPicker(
      context,
      contacts: contacts,
      initial: initial,
    );
    if (picked == null) return;
    await controller.setMembers(group, picked);
  }

  Future<String?> _promptName(
    BuildContext context, {
    required String title,
    String initial = '',
  }) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _NamePromptDialog(
        title: title,
        initial: initial,
      ),
    );
    return (name == null || name.isEmpty) ? null : name;
  }

  /// Name prompt owning its controller so disposal is framework-ordered.
  

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
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.label_off,
              title: 'No groups yet',
              subtitle: 'Create one to organize contacts.',
              action: FilledButton(
                onPressed: () => _create(context, ref),
                child: const Text('Create group'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(groupsProvider),
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, index) {
                final group = list[index];
                return ListTile(
                  leading: ContactAvatar(
                    displayName: group.name,
                    radius: 20,
                  ),
                  title: Text(group.name),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'rename') {
                        await _rename(context, ref, group);
                      } else {
                        final confirmed = await showConfirmDialog(
                          context,
                          title: 'Delete group?',
                        );
                        if (confirmed && context.mounted) {
                          await ref
                              .read(groupsControllerProvider.notifier)
                              .delete(group);
                        }
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                          value: 'rename', child: Text('Rename')),
                      PopupMenuItem(
                          value: 'delete', child: Text('Delete')),
                    ],
                  ),
                  onTap: () => _editMembers(context, ref, group),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Single-field name prompt with framework-managed controller lifecycle.
class _NamePromptDialog extends StatefulWidget {
  const _NamePromptDialog({required this.title, this.initial = ''});

  final String title;
  final String initial;

  @override
  State<_NamePromptDialog> createState() => _NamePromptDialogState();
}

class _NamePromptDialogState extends State<_NamePromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Coworkers'),
        onSubmitted: (_) => _submit(context),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => _submit(context),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
