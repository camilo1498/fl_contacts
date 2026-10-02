import 'package:fl_contacts_example/core/providers/app_providers.dart';
import 'package:fl_contacts_example/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: ContactsExampleApp()));
}

/// Demo root: Riverpod scope plus the typed GoRouter shell.
class ContactsExampleApp extends ConsumerWidget {
  const ContactsExampleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'fl_contacts example',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
