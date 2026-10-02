import 'package:fl_contacts_example/core/router/app_router.dart';
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
    final router = ref.watch(_routerProvider);
    return MaterialApp.router(
      title: 'fl_contacts example',
      theme: ThemeData(useMaterial3: true),
      routerConfig: router,
    );
  }
}

/// Router instance shared across rebuilds.
final _routerProvider = Provider((ref) => buildAppRouter());
