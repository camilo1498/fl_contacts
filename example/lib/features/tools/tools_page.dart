import 'dart:io';

import 'package:fl_contacts/fl_contacts.dart';
import 'package:fl_contacts_example/core/providers/contacts_providers.dart';
import 'package:fl_contacts_example/core/providers/device_providers.dart';
import 'package:fl_contacts_example/core/providers/permission_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Permissions, native UI, vCard tools and device-only features.
class ToolsPage extends ConsumerWidget {
  const ToolsPage({super.key});

  Future<void> _showText(
    BuildContext context,
    String title,
    String text,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: SelectableText(text)),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Copy & close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(permissionStatusProvider);
    final events = ref.watch(contactEventsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tools')),
      body: ListView(
        children: [
          _Section(
            title: permission.when(
              data: (status) => 'Permission (${status.name})',
              error: (_, _) => 'Permission (error)',
              loading: () => 'Permission (…)',
            ),
            children: [
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
                    onPressed: () => FlContacts.openAppSettings(),
                    child: const Text('App settings'),
                  ),
                ],
              ),
            ],
          ),
          _Section(
            title: 'Live changes',
            children: [
              events.when(
                loading: () => const Text('Listening…'),
                error: (e, _) => Text('Stream error: $e'),
                data: (list) => Text(
                  list.isEmpty
                      ? 'No changes yet — edit a contact anywhere.'
                      : list
                          .map((c) => '${c.type.name}: ${c.contactId}')
                          .join('\n'),
                ),
              ),
            ],
          ),
          _Section(
            title: 'System contact UI',
            children: [
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: () async {
                      final picked =
                          await FlContacts.openExternalPick();
                      if (picked != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('Picked: ${picked.displayName}'),
                          ),
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
          ),
          _Section(
            title: 'vCard',
            children: [
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: () async {
                      final contacts =
                          await ref.read(contactsListProvider.future);
                      if (!context.mounted) return;
                      await _showText(
                        context,
                        '${contacts.length} contacts',
                        Contact.listToVCard(contacts.take(5).toList()),
                      );
                    },
                    child: const Text('Export first 5'),
                  ),
                  FilledButton.tonal(
                    onPressed: () async {
                      const sample = 'BEGIN:VCARD\nVERSION:3.0\n'
                          'FN:Ada Lovelace\nTEL:+1-555-0100\n'
                          'X-SPOUSE:Lord Byron\nEND:VCARD';
                      final parsed = Contact.fromVCard(sample);
                      if (!context.mounted) return;
                      await _showText(
                        context,
                        'Parsed',
                        '${parsed.displayName}\n'
                        'extras: ${parsed.extras.map((e) => e.name).join(', ')}',
                      );
                    },
                    child: const Text('Parse sample'),
                  ),
                  FilledButton.tonal(
                    onPressed: () async {
                      const doc = 'BEGIN:VCARD\nFN:One\nEND:VCARD\n'
                          'BEGIN:VCARD\nFN:Two\nEND:VCARD\n';
                      final parsed = Contact.fromVCardList(doc);
                      if (!context.mounted) return;
                      await _showText(
                        context,
                        'Multi-card',
                        parsed.map((c) => c.displayName).join(', '),
                      );
                    },
                    child: const Text('Parse 2 cards'),
                  ),
                ],
              ),
            ],
          ),
          const _Section(title: 'Batch', children: [_BatchDemo()]),
          const _Section(title: 'Native filters', children: [_FilterDemo()]),
          const _Section(
            title: 'Groups of contact',
            children: [_GroupsOfDemo()],
          ),
          const _Section(title: 'Profile', children: [_ProfileSection()]),
          const _Section(title: 'Config', children: [_ConfigSection()]),
          if (Platform.isAndroid) ...[
            _Section(
              title: 'SIM contacts',
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final sim = ref.watch(simContactsProvider);
                    return sim.when(
                      loading: () =>
                          const CircularProgressIndicator(),
                      error: (e, _) => Text('SIM error: $e'),
                      data: (list) => Text('${list.length} on SIM'),
                    );
                  },
                ),
              ],
            ),
            _Section(
              title: 'Blocked numbers',
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final blocked = ref.watch(blockedNumbersProvider);
                    return blocked.when(
                      loading: () =>
                          const CircularProgressIndicator(),
                      error: (e, _) => Text('Blocked error: $e'),
                      data: (list) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            list.isEmpty
                                ? 'None blocked'
                                : list
                                    .map((p) => p.number)
                                    .join(', '),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              FilledButton.tonal(
                                onPressed: () async {
                                  await FlBlockedNumbers.block(
                                    '555-0100',
                                  );
                                  ref.invalidate(blockedNumbersProvider);
                                  ref.invalidate(databaseVersionProvider);
                                },
                                child: const Text('Block 555-0100'),
                              ),
                              FilledButton.tonal(
                                onPressed: () async {
                                  await FlBlockedNumbers.unblock(
                                    '555-0100',
                                  );
                                  ref.invalidate(blockedNumbersProvider);
                                  ref.invalidate(databaseVersionProvider);
                                },
                                child: const Text('Unblock'),
                              ),
                              const _BlockedExtras(),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            _Section(
              title: 'Ringtones',
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final tones = ref.watch(ringtonesProvider);
                    return tones.when(
                      loading: () =>
                          const CircularProgressIndicator(),
                      error: (e, _) => Text('Ringtone error: $e'),
                      data: (list) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${list.length} ringtones'),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final tone in list.take(3))
                                FilledButton.tonal(
                                  onPressed: () =>
                                      FlRingtones.play(tone.uri),
                                  child: Text(
                                    tone.title.isEmpty
                                        ? 'Play'
                                        : tone.title,
                                  ),
                                ),
                              FilledButton.tonal(
                                onPressed: FlRingtones.stop,
                                child: const Text('Stop'),
                              ),
                              FilledButton.tonal(
                                onPressed: () async {
                                  final uri = await FlRingtones.pick(
                                    RingtoneType.ringtone,
                                  );
                                  if (uri != null) {
                                    await FlRingtones.setDefaultUri(
                                      RingtoneType.ringtone,
                                      uri,
                                    );
                                  }
                                  ref.invalidate(ringtonesProvider);
                                },
                                child: const Text('Pick default'),
                              ),
                              FilledButton.tonal(
                                onPressed: () async {
                                  final uri =
                                      await FlRingtones.getDefaultUri(
                                    RingtoneType.ringtone,
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Default: ${uri ?? 'none'}',
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Show default'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BatchDemo extends ConsumerStatefulWidget {
  const _BatchDemo();

  @override
  ConsumerState<_BatchDemo> createState() => _BatchDemoState();
}

class _BatchDemoState extends ConsumerState<_BatchDemo> {
  String _log = 'Idle';

  Future<void> _run() async {
    setState(() => _log = 'Inserting…');
    final created = await FlContacts.insertContacts([
      Contact()..name.first = 'Batch A',
      Contact()..name.first = 'Batch B',
    ]);
    setState(() => _log = 'Updating ${created.length}…');
    for (final c in created) {
      c.name.last = 'Batched';
    }
    final updated = await FlContacts.updateContacts(created);
    setState(() => _log = 'Deleting ${updated.length}…');
    await FlContacts.deleteContacts(updated);
    if (mounted) setState(() => _log = 'Batch OK: 2 upserted + deleted');
    ref.invalidate(databaseVersionProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_log),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: _run,
          child: const Text('Run insert/delete batch'),
        ),
      ],
    );
  }
}

class _FilterDemo extends ConsumerStatefulWidget {
  const _FilterDemo();

  @override
  ConsumerState<_FilterDemo> createState() => _FilterDemoState();
}

class _FilterDemoState extends ConsumerState<_FilterDemo> {
  String _log = 'Idle';

  Future<void> _run(String label, ContactFilter filter, {int? limit}) async {
    setState(() => _log = '$label…');
    final contacts = await FlContacts.getContacts(
      filter: filter,
      limit: limit ?? 100,
    );
    if (mounted) {
      setState(() => _log = '$label: ${contacts.length} match(es)');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_log),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: () =>
                  _run('By phone 555', const ContactFilter.phone('555')),
              child: const Text('Phone 555'),
            ),
            FilledButton.tonal(
              onPressed: () => _run(
                'By email example.com',
                const ContactFilter.email('example.com'),
              ),
              child: const Text('Email domain'),
            ),
            FilledButton.tonal(
              onPressed: () => _run(
                'First 3 IDs',
                const ContactFilter.ids([]),
                limit: 3,
              ),
              child: const Text('Limit 3'),
            ),
          ],
        ),
      ],
    );
  }
}

class _GroupsOfDemo extends ConsumerStatefulWidget {
  const _GroupsOfDemo();

  @override
  ConsumerState<_GroupsOfDemo> createState() => _GroupsOfDemoState();
}

class _GroupsOfDemoState extends ConsumerState<_GroupsOfDemo> {
  String _log = 'Idle';

  Future<void> _run() async {
    setState(() => _log = 'Loading…');
    final contacts = await FlContacts.getContacts(limit: 1);
    if (contacts.isEmpty) {
      if (mounted) setState(() => _log = 'No contacts');
      return;
    }
    final groups = await FlContacts.getGroupsOf(contacts.first.id);
    if (mounted) {
      setState(() => _log =
          '${contacts.first.displayName}: ${groups.map((g) => g.name).join(', ')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_log),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: _run,
          child: const Text('Groups of first contact'),
        ),
      ],
    );
  }
}

class _BlockedExtras extends ConsumerWidget {
  const _BlockedExtras();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      children: [
        FilledButton.tonal(
          onPressed: () async {
            final blocked = await FlBlockedNumbers.isBlocked('555-0100');
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(blocked ? 'Blocked' : 'Not blocked')),
            );
          },
          child: const Text('Check 555-0100'),
        ),
        FilledButton.tonal(
          onPressed: () async {
            await FlBlockedNumbers.blockAll(['555-0101', '555-0102']);
            ref.invalidate(blockedNumbersProvider);
          },
          child: const Text('Block 2'),
        ),
        FilledButton.tonal(
          onPressed: () async {
            await FlBlockedNumbers.unblockAll(['555-0101', '555-0102']);
            ref.invalidate(blockedNumbersProvider);
          },
          child: const Text('Unblock 2'),
        ),
        FilledButton.tonal(
          onPressed: FlBlockedNumbers.openDefaultAppSettings,
          child: const Text('Dialer settings'),
        ),
      ],
    );
  }
}

class _ProfileSection extends ConsumerWidget {
  const _ProfileSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Platform.isAndroid && !Platform.isMacOS) {
      return const Text('Profile is Android/macOS only.');
    }
    final profile = ref.watch(profileProvider);
    return profile.when(
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('Profile error: $e'),
      data: (contact) => Text(
        contact == null ? 'No profile set' : 'Me: ${contact.displayName}',
      ),
    );
  }
}

class _ConfigSection extends StatefulWidget {
  const _ConfigSection();

  @override
  State<_ConfigSection> createState() => _ConfigSectionState();
}

class _ConfigSectionState extends State<_ConfigSection> {
  @override
  Widget build(BuildContext context) {
    final v4 = FlContacts.config.vCardVersion == VCardVersion.v4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Thumbnails capped at ${FlContacts.config.thumbnailMaxSize}px'),
        SwitchListTile(
          title: const Text('Export vCard v4 (default v3)'),
          value: v4,
          onChanged: (value) => setState(() {
            FlContacts.config.vCardVersion =
                value ? VCardVersion.v4 : VCardVersion.v3;
          }),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}
