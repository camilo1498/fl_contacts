import 'package:fl_contacts/fl_contacts.dart';
import 'package:flutter/material.dart';

/// Shows a checkbox dialog picking member contact IDs.
///
/// Resolves to the picked IDs, or null when cancelled.
Future<Set<String>?> showMemberPicker(
  BuildContext context, {
  required List<Contact> contacts,
  required Set<String> initial,
}) {
  final picked = Set<String>.of(initial);
  return showDialog<Set<String>>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Members'),
      content: SizedBox(
        width: double.maxFinite,
        child: StatefulBuilder(
          builder: (context, setDialogState) => ListView.builder(
            shrinkWrap: true,
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return CheckboxListTile(
                title: Text(contact.displayName),
                value: picked.contains(contact.id),
                onChanged: (v) => setDialogState(() {
                  if (v == true) {
                    picked.add(contact.id);
                  } else {
                    picked.remove(contact.id);
                  }
                }),
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, picked),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
