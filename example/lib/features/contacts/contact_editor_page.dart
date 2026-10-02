import 'package:fl_contacts/fl_contacts.dart';
import 'package:fl_contacts_example/core/providers/contacts_providers.dart';
import 'package:fl_contacts_example/core/providers/permission_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Creator (`contactId == null`) and editor with name, phone and email.
class ContactEditorPage extends ConsumerStatefulWidget {
  const ContactEditorPage({this.contactId, super.key});

  final String? contactId;

  @override
  ConsumerState<ContactEditorPage> createState() => _ContactEditorPageState();
}

class _ContactEditorPageState extends ConsumerState<ContactEditorPage> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  void _fill(Contact contact) {
    if (_loaded) return;
    _loaded = true;
    _first.text = contact.name.first;
    _last.text = contact.name.last;
    if (contact.phones.isNotEmpty) _phone.text = contact.phones.first.number;
    if (contact.emails.isNotEmpty) _email.text = contact.emails.first.address;
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save(Contact? existing) async {
    setState(() => _saving = true);
    try {
      if (existing == null) {
        final contact = Contact()
          ..name.first = _first.text
          ..name.last = _last.text;
        if (_phone.text.isNotEmpty) {
          contact.phones = [Phone(_phone.text)];
        }
        if (_email.text.isNotEmpty) {
          contact.emails = [Email(_email.text)];
        }
        await contact.insert();
      } else {
        existing
          ..name.first = _first.text
          ..name.last = _last.text;
        if (_phone.text.isNotEmpty) {
          existing.phones = [Phone(_phone.text)];
        }
        if (_email.text.isNotEmpty) {
          existing.emails = [Email(_email.text)];
        }
        await existing.update();
      }
      ref.invalidate(databaseVersionProvider);
      if (mounted) context.pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editingId = widget.contactId;
    final existing = editingId == null
        ? const AsyncValue<Contact?>.data(null)
        : ref.watch(contactDetailProvider(editingId));
    return Scaffold(
      appBar: AppBar(
        title: Text(editingId == null ? 'New contact' : 'Edit contact'),
      ),
      body: existing.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Load error: $e')),
        data: (contact) {
          if (contact != null) _fill(contact);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _first,
                decoration: const InputDecoration(labelText: 'First name'),
              ),
              TextField(
                controller: _last,
                decoration: const InputDecoration(labelText: 'Last name'),
              ),
              TextField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : () => _save(contact),
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
