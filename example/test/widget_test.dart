import 'package:fl_contacts_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('denied permission shows the grant button', (tester) async {
    const channel = MethodChannel('github.com/QuisApp/fl_contacts');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall m) async {
      if (m.method == 'requestPermission') return false;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      const ProviderScope(child: ContactsExampleApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Grant contact permission'), findsOneWidget);
    expect(find.byType(SearchBar, skipOffstage: false), findsNothing);
  });
}
