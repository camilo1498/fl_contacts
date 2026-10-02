import 'package:fl_contacts/fl_contacts.dart';
import 'package:fl_contacts_example/core/widgets/contact_avatar.dart';
import 'package:flutter/material.dart';

/// One contact row: gradient avatar, name, subtitle and chevron.
///
/// Shared by the contact list and anywhere contacts are picked.
class ContactListTile extends StatelessWidget {
  const ContactListTile({
    required this.contact,
    this.subtitle,
    this.onTap,
    super.key,
  });

  final Contact contact;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ContactAvatar.fromContact(contact),
      title: Text(
        contact.displayName.isEmpty ? '(No name)' : contact.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
