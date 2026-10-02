import 'package:fl_contacts/fl_contacts.dart';
import 'package:fl_contacts_example/core/mixins/form_validators.dart';
import 'package:fl_contacts_example/core/widgets/loading_button.dart';
import 'package:fl_contacts_example/core/widgets/section_card.dart';
import 'package:fl_contacts_example/features/contacts/application/contact_editor_controller.dart';
import 'package:fl_contacts_example/features/contacts/application/contacts_providers.dart';
import 'package:fl_contacts_example/features/contacts/application/models/contact_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Creator (`contactId == null`) and editor with validated fields.
class ContactEditorPage extends ConsumerStatefulWidget {
  const ContactEditorPage({this.contactId, super.key});

  final String? contactId;

  @override
  ConsumerState<ContactEditorPage> createState() => _ContactEditorPageState();
}

class _ContactEditorPageState extends ConsumerState<ContactEditorPage>
    with ContactFormValidators {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  bool _filled = false;
  bool _saving = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  void _fillOnce(WidgetRef ref, String id) {
    if (_filled) return;
    final existing = ref
        .read(contactDetailProvider(id))
        .maybeWhen(data: (c) => c, orElse: () => null);
    if (existing == null) return;
    _filled = true;
    _first.text = existing.name.first;
    _last.text = existing.name.last;
    if (existing.phones.isNotEmpty) {
      _phone.text = existing.phones.first.number;
    }
    if (existing.emails.isNotEmpty) {
      _email.text = existing.emails.first.address;
    }
  }

  Future<void> _save(String? editingId) async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final controller = ref.read(contactEditorControllerProvider.notifier);
    final draft = ContactDraft(
      first: _first.text.trim(),
      last: _last.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
    );
    try {
      if (editingId == null) {
        await controller.create(draft);
      } else {
        await controller.update(editingId, draft);
      }
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
          if (contact != null && editingId != null) {
            _fillOnce(ref, editingId);
          }
          return Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                SectionCard(
                  title: 'Name',
                  children: [
                    TextFormField(
                      controller: _first,
                      decoration: const InputDecoration(
                        labelText: 'First name',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) => validateRequired(v, 'First name'),
                    ),
                    TextFormField(
                      controller: _last,
                      decoration: const InputDecoration(
                        labelText: 'Last name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                  ],
                ),
                SectionCard(
                  title: 'Contact channels',
                  children: [
                    TextFormField(
                      controller: _phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: validatePhone,
                    ),
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: validateEmail,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: LoadingFilledButton(
                    busy: _saving,
                    label: 'Save',
                    onPressed: () => _save(editingId),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
