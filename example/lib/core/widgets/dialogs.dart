import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows a destructive-action confirmation dialog, resolving to the choice.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String confirmLabel = 'Delete',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Shows a short-lived message.
void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

/// Shows long text in a scrollable dialog with copy-and-close.
Future<void> showScrollableText(
  BuildContext context, {
  required String title,
  required String text,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(child: SelectableText(text)),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Copy & close'),
        ),
      ],
    ),
  );
}
