import 'package:fl_contacts/fl_contacts.dart';
import 'package:fl_contacts_example/core/widgets/contact_avatar.dart';
import 'package:flutter/material.dart';

/// Hero-style header: oversized avatar over a gradient wash plus names.
///
/// Reused by the detail page and anywhere a contact is presented.
class ContactHeader extends StatelessWidget {
  const ContactHeader({required this.contact, super.key});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer,
            scheme.surface,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: Column(
        children: [
          ContactAvatar.fromContact(contact, radius: 44),
          const SizedBox(height: 12),
          Text(
            contact.displayName.isEmpty ? '(No name)' : contact.displayName,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          if (contact.name.nickname.isNotEmpty)
            Text(
              '"${contact.name.nickname}"',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
