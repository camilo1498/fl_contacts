import 'dart:io';

import 'package:fl_contacts/fl_contacts.dart';
import 'package:fl_contacts_example/core/providers/device_providers.dart';
import 'package:fl_contacts_example/core/widgets/section_card.dart';
import 'package:fl_contacts_example/features/tools/application/media_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// SIM contacts (Android only).
class SimSection extends ConsumerWidget {
  const SimSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Platform.isAndroid) return const SizedBox.shrink();
    final sim = ref.watch(simContactsProvider);
    return SectionCard(
      title: 'SIM contacts',
      children: [
        sim.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('SIM error: $e'),
          data: (list) => Text('${list.length} on SIM'),
        ),
      ],
    );
  }
}

/// Owner profile card (Android/macOS).
class ProfileSection extends ConsumerWidget {
  const ProfileSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Platform.isAndroid && !Platform.isMacOS) {
      return const SectionCard(
        title: 'Profile',
        children: [Text('Profile is Android/macOS only.')],
      );
    }
    final profile = ref.watch(profileProvider);
    return SectionCard(
      title: 'Profile',
      children: [
        profile.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Profile error: $e'),
          data: (contact) => Text(
            contact == null ? 'No profile set' : 'Me: ${contact.displayName}',
          ),
        ),
      ],
    );
  }
}

/// Export format and thumbnail budget.
class ConfigSection extends StatefulWidget {
  const ConfigSection({super.key});

  @override
  State<ConfigSection> createState() => _ConfigSectionState();
}

class _ConfigSectionState extends State<ConfigSection> {
  @override
  Widget build(BuildContext context) {
    final v4 = FlContacts.config.vCardVersion == VCardVersion.v4;
    return SectionCard(
      title: 'Config',
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

/// Blocked-numbers actions (Android only).
class BlockedSection extends ConsumerWidget {
  const BlockedSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Platform.isAndroid) return const SizedBox.shrink();
    final blocked = ref.watch(blockedNumbersProvider);
    final controller = ref.watch(blockedControllerProvider.notifier);
    final status = ref.watch(blockedControllerProvider);
    return SectionCard(
      title: 'Blocked numbers',
      children: [
        blocked.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Blocked error: $e'),
          data: (list) => Text(
            list.isEmpty
                ? 'None blocked'
                : list.map((p) => p.number).join(', '),
          ),
        ),
        Text(status.log),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: controller.execute,
              child: const Text('Check 555-0100'),
            ),
            FilledButton.tonal(
              onPressed: controller.blockSample,
              child: const Text('Block 2'),
            ),
            FilledButton.tonal(
              onPressed: controller.unblockSample,
              child: const Text('Unblock 2'),
            ),
            FilledButton.tonal(
              onPressed: controller.openSettings,
              child: const Text('Dialer settings'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Ringtone actions (Android only).
class RingtoneSection extends ConsumerWidget {
  const RingtoneSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Platform.isAndroid) return const SizedBox.shrink();
    final tones = ref.watch(ringtonesProvider);
    final controller = ref.watch(ringtoneControllerProvider.notifier);
    final status = ref.watch(ringtoneControllerProvider);
    return SectionCard(
      title: 'Ringtones',
      children: [
        tones.when(
          loading: () => const CircularProgressIndicator(),
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
                      onPressed: () => controller.play(tone.uri),
                      child: Text(
                        tone.title.isEmpty ? 'Play' : tone.title,
                      ),
                    ),
                  FilledButton.tonal(
                    onPressed: controller.stop,
                    child: const Text('Stop'),
                  ),
                  FilledButton.tonal(
                    onPressed: controller.pickDefault,
                    child: const Text('Pick default'),
                  ),
                  FilledButton.tonal(
                    onPressed: controller.execute,
                    child: const Text('Show default'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Text(status.log),
      ],
    );
  }
}
