import 'package:fl_contacts_example/features/tools/presentation/widgets/demo_sections.dart';
import 'package:fl_contacts_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Full end-to-end pass on a real device/simulator.
///
/// Needs contacts access granted before the run
/// (`xcrun simctl privacy booted grant contacts <bundle>` on simulators).
/// Every flow uses unique markers and cleans up after itself.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester) =>
      tester.pumpAndSettle(const Duration(seconds: 10));

  testWidgets('empty list, create, search, detail, delete', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ContactsExampleApp()),
    );
    await settle(tester);

    // Unique marker keeps this hermetic regardless of seeded contacts.
    const marker = 'E2E-QZX';
    const fullName = 'Test User $marker';

    // Create through the editor form.
    await tester.tap(find.byIcon(Icons.person_add));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'First name'),
      'Test User',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Last name'),
      marker,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone'),
      '555-0199',
    );
    await tester.tap(find.text('Save'));
    await settle(tester);

    // Back on the list with the new contact.
    expect(find.text(fullName), findsOneWidget);

    // Search filters live.
    await tester.enterText(find.byType(SearchBar), 'zzz-no-match');
    await settle(tester);
    expect(find.text(fullName), findsNothing);
    await tester.enterText(find.byType(SearchBar), marker);
    await settle(tester);
    expect(find.text(fullName), findsOneWidget);

    // Detail shows data; delete removes it with confirmation.
    await tester.tap(find.text(fullName));
    await settle(tester);
    expect(find.text('555-0199'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    await tester.tap(find.text('Delete').last);
    await settle(tester);
    expect(find.text(fullName), findsNothing);
  });

  testWidgets('groups create and delete', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ContactsExampleApp()),
    );
    await settle(tester);

    final groupName = 'E2E Group ${DateTime.now().millisecondsSinceEpoch}';
    await tester.tap(find.text('Groups'));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.group_add));
    await settle(tester);
    await tester.enterText(find.byType(TextField), groupName);
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text(groupName), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    expect(find.text(groupName), findsNothing);
  });

  testWidgets('tools batch and vcard parse', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ContactsExampleApp()),
    );
    await settle(tester);

    Future<void> tapRunIn(String section) async {
      final scope = find.ancestor(
        of: find.text(section),
        matching: find.byType(DemoSection),
      );
      final run = find.descendant(
        of: scope,
        matching: find.text('Run'),
      );
      await tester.dragUntilVisible(
        run,
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.tap(run);
      await settle(tester);
    }

    await tester.tap(find.text('Tools'));
    await settle(tester);
    await tapRunIn('Batch CRUD');
    expect(find.textContaining('Batch OK'), findsOneWidget);

    await tapRunIn('Native filters');
    expect(find.textContaining('Phone 555:'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Parse 2 cards'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.tap(find.text('Parse 2 cards'));
    await settle(tester);
    expect(find.textContaining('One, Two'), findsOneWidget);
  });
}
