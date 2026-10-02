import 'package:fl_contacts_example/features/tools/application/demo_controllers.dart';
import 'package:fl_contacts_example/features/tools/presentation/widgets/demo_sections.dart';
import 'package:fl_contacts_example/features/tools/presentation/widgets/device_sections.dart';
import 'package:fl_contacts_example/features/tools/presentation/widgets/status_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Catalogue page composing one section per plugin capability.
class ToolsPage extends ConsumerWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tools')),
      body: ListView(
        children: [
          const PermissionSection(),
          EventsSection(),
          SystemUiSection(),
          VCardSection(),
          DemoSection(
            title: 'Batch CRUD',
            provider: batchDemoControllerProvider,
          ),
          DemoSection(
            title: 'Native filters',
            provider: filterDemoControllerProvider,
          ),
          DemoSection(
            title: 'Groups of contact',
            provider: groupsOfDemoControllerProvider,
          ),
          SimSection(),
          ProfileSection(),
          ConfigSection(),
          BlockedSection(),
          RingtoneSection(),
        ],
      ),
    );
  }
}
