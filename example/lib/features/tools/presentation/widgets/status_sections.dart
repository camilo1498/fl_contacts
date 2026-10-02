import 'package:fl_contacts/fl_contacts.dart';
import 'package:fl_contacts_example/core/providers/permission_providers.dart';
import 'package:fl_contacts_example/core/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Permission status with request and settings shortcuts.
class PermissionSection extends ConsumerWidget {
  const PermissionSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(permissionStatusProvider);
    return SectionCard(
      title: 'Permission',
      children: [
        Text('Status: ${permission.when(
          data: (s) => s.name,
          error: (e, _) => 'error: $e',
          loading: () => '…',
        )}'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: () async {
                await FlContacts.requestPermission();
                ref.invalidate(permissionStatusProvider);
              },
              child: const Text('Request'),
            ),
            FilledButton.tonal(
              onPressed: FlContacts.openAppSettings,
              child: const Text('App settings'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Live typed change events.
class EventsSection extends ConsumerWidget {
  const EventsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(contactEventsProvider);
    return SectionCard(
      title: 'Live changes',
      children: [
        events.when(
          loading: () => const Text('Listening…'),
          error: (e, _) => Text('Stream error: $e'),
          data: (list) => Text(
            list.isEmpty
                ? 'No changes yet — edit a contact anywhere.'
                : list.map((c) => '${c.type.name}: ${c.contactId}').join('\n'),
          ),
        ),
      ],
    );
  }
}

/// System picker and prefilled creator.
class SystemUiSection extends ConsumerWidget {
  const SystemUiSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      title: 'System contact UI',
      children: [
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: () async {
                final picked = await FlContacts.openExternalPick();
                if (picked != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Picked: ${picked.displayName}')),
                  );
                }
              },
              child: const Text('Pick'),
            ),
            FilledButton.tonal(
              onPressed: () => FlContacts.openExternalInsert(
                Contact()..name.first = 'Grace',
              ),
              child: const Text('Prefilled create'),
            ),
          ],
        ),
      ],
    );
  }
}
