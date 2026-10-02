import 'package:flutter/material.dart';

/// Reusable validators for contact forms.
///
/// Mixed into the form's [State] so every field shares one validation
/// vocabulary instead of scattering regexes across pages.
mixin ContactFormValidators<T extends StatefulWidget> on State<T> {
  /// Fails when the value is blank.
  String? validateRequired(String? value, String field) =>
      (value == null || value.trim().isEmpty) ? '$field is required' : null;

  /// Fails when the value is a malformed email; blank passes (optional).
  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
    return valid ? null : 'Enter a valid email';
  }

  /// Fails when the value holds no digits; blank passes (optional).
  String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 3 ? null : 'Enter a valid phone';
  }
}
