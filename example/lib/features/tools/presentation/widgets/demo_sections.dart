import 'package:fl_contacts/fl_contacts.dart';
import 'package:fl_contacts_example/core/application/demo_task.dart';
import 'package:fl_contacts_example/core/application/models/demo_task_state.dart';
import 'package:fl_contacts_example/features/contacts/application/contacts_providers.dart';
import 'package:fl_contacts_example/features/tools/presentation/widgets/demo_action.dart';
import 'package:fl_contacts_example/core/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Generic card driving a [DemoTaskController] with extra actions.
class DemoSection extends ConsumerWidget {
  const DemoSection({
    required this.title,
    required this.provider,
    this.actions = const [],
    super.key,
  });

  final String title;
  final NotifierProvider<DemoTaskController, DemoTaskState> provider;
  final List<DemoAction> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    return SectionCard(
      title: title,
      children: [
        Text(state.log),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: state.running ? null : controller.execute,
              child: const Text('Run'),
            ),
            for (final action in actions)
              FilledButton.tonal(
                onPressed:
                    state.running ? null : () => action.run(controller),
                child: Text(action.label),
              ),
          ],
        ),
      ],
    );
  }
}

/// vCard export and parsing demos.
class VCardSection extends ConsumerWidget {
  const VCardSection({super.key});

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
    return SectionCard(
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
    );
  }
}
