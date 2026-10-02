import 'package:flutter/material.dart';

/// Pill showing a property label (`home`, `work`, custom…).
class LabelChip extends StatelessWidget {
  const LabelChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: scheme.secondaryContainer,
      labelStyle: TextStyle(
        color: scheme.onSecondaryContainer,
        fontSize: 12,
      ),
    );
  }
}

/// Icon-led property row with title, label chip and optional tap.
class PropertyRow extends StatelessWidget {
  const PropertyRow({
    required this.icon,
    required this.title,
    this.label,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(title),
      trailing: label != null ? LabelChip(label: label!) : null,
      onTap: onTap,
    );
  }
}
