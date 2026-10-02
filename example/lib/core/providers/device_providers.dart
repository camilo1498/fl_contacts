import 'dart:io';

import 'package:fl_contacts/fl_contacts.dart';
import 'package:fl_contacts_example/core/providers/sync_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// SIM contacts (Android only, empty elsewhere).
final simContactsProvider = FutureProvider<List<Contact>>((ref) async {
  if (!Platform.isAndroid) return [];
  ref.watch(databaseVersionProvider);
  return FlContacts.getSimContacts();
});

/// Owner profile card (Android/macOS, null elsewhere or when missing).
final profileProvider = FutureProvider<Contact?>((ref) async {
  if (!Platform.isAndroid && !Platform.isMacOS) return null;
  return FlContacts.getProfile(withProperties: true);
});

/// Blocked numbers (Android only, empty elsewhere).
final blockedNumbersProvider = FutureProvider<List<Phone>>((ref) async {
  if (!Platform.isAndroid) return [];
  ref.watch(databaseVersionProvider);
  if (!await FlBlockedNumbers.isAvailable()) return [];
  return FlBlockedNumbers.getAll();
});

/// System ringtones of the default slot (Android only).
final ringtonesProvider = FutureProvider<List<Ringtone>>((ref) async {
  if (!Platform.isAndroid) return [];
  return FlRingtones.getAll(type: RingtoneType.ringtone);
});
