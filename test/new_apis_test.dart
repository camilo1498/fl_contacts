// New 1.3.0 APIs: extras round-trip, vCard lists, filters and streams.
import 'package:fl_contacts/fl_contacts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unknown vCard lines round-trip through extras', () {
    const vcard = 'BEGIN:VCARD\n'
        'VERSION:3.0\n'
        'FN:Jane Doe\n'
        'X-SPOUSE:Jane Sr\n'
        'item1.X-FOO;TYPE=bar:baz\n'
        'END:VCARD';
    final contact = Contact.fromVCard(vcard);
    expect(contact.displayName, 'Jane Doe');
    expect(contact.extras.length, 2);
    expect(contact.extras.first.name, 'X-SPOUSE');
    expect(contact.extras.first.value, 'Jane Sr');
    expect(contact.extras.last.group, 'item1');
    final exported = contact.toVCard();
    expect(exported, contains('X-SPOUSE:Jane Sr'));
    expect(exported, contains('item1.X-FOO;TYPE=BAR:baz'));
  });

  test('structural lines never become extras', () {
    final contact = Contact.fromVCard(
      'BEGIN:VCARD\nVERSION:3.0\nFN:No Extras\nEND:VCARD',
    );
    expect(contact.extras, isEmpty);
  });

  test('fromVCardList splits multiple cards', () {
    const doc = 'BEGIN:VCARD\nFN:One\nEND:VCARD\n'
        'BEGIN:VCARD\nFN:Two\nEND:VCARD\n';
    final contacts = Contact.fromVCardList(doc);
    expect(contacts.map((c) => c.displayName).toList(), ['One', 'Two']);
    expect(Contact.fromVCardList('  \n'), isEmpty);
  });

  test('ContactFilter encodes only set fields', () {
    expect(const ContactFilter.name('ann').toJson(), {
      'ids': null,
      'groupId': null,
      'name': 'ann',
      'phone': null,
      'email': null,
    });
    expect(
      const ContactFilter.ids(['a', 'b']).toJson()?['ids'],
      ['a', 'b'],
    );
  });

  test('batch insert validates every entry', () async {
    const channel = MethodChannel('github.com/QuisApp/fl_contacts');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall m) async {
      if (m.method == 'insertAll') return [];
      return null;
    });
    final bad = Contact()..id = 'x';
    await expectLater(
      FlContacts.insertContacts([Contact(), bad]),
      throwsException,
    );
  });

  test('contact changes stream parses typed events', () async {
    const method = MethodChannel('github.com/QuisApp/fl_contacts');
    const events =
        EventChannel('github.com/QuisApp/fl_contacts/contactChanges');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(method, (MethodCall m) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (args, events) {
          events.success([
            {'type': 'added', 'contactId': '1'},
            {'type': 'bogus', 'contactId': '2'},
            {'type': 'removed', 'contactId': null},
            'garbage',
          ]);
        },
      ),
    );
    final changes = await FlContacts.onContactChanged.first;
    expect(
      changes,
      [const ContactChange(type: ContactChangeType.added, contactId: '1')],
    );
  });

  test('desktop-only APIs throw with clear errors', () async {    await expectLater(
      FlContacts.getSimContacts(),
      throwsUnsupportedError,
    );
    await expectLater(
      FlBlockedNumbers.isBlocked('123'),
      throwsUnsupportedError,
    );
    await expectLater(
      FlRingtones.stop(),
      throwsUnsupportedError,
    );
  });

  test('thumbnails are downsampled by default', () {
    expect(FlContacts.config.thumbnailMaxSize, 192);
  });
}
