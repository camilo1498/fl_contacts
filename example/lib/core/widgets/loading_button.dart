import 'package:flutter/material.dart';

/// Filled button rendering a spinner while [busy].
class LoadingFilledButton extends StatelessWidget {
  const LoadingFilledButton({
    required this.onPressed,
    required this.label,
    this.busy = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}
