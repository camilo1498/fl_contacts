import 'dart:io';

import 'package:fl_contacts/properties/phone.dart';
import 'package:flutter/services.dart';

/// Android system number-blocking backed by `BlockedNumberContract`.
///
/// Blocking only works when this app is the default dialer or SMS app, or
/// holds carrier privileges; otherwise calls throw [PlatformException] with
/// code `security_error`. Every other platform throws [UnsupportedError].
class FlBlockedNumbers {
  static const _channel = MethodChannel('github.com/QuisApp/fl_contacts');

  static void _ensureAndroid() {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Blocked numbers are only available on Android.');
    }
  }

  /// Whether blocking can work here: Android plus dialer/SMS/carrier rights.
  ///
  /// Never throws; returns `false` on other platforms or without rights.
  static Future<bool> isAvailable() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isBlockNumbersAvailable') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// Whether [number] is currently blocked.
  static Future<bool> isBlocked(String number) async {
    _ensureAndroid();
    return await _channel.invokeMethod<bool>('isBlockedNumber', [number]) ??
        false;
  }

  /// Every blocked number with its normalized form.
  static Future<List<Phone>> getAll() async {
    _ensureAndroid();
    final numbers =
        await _channel.invokeMethod<List<dynamic>>('getBlockedNumbers') ?? [];
    return numbers
        .map((n) => Phone.fromJson(Map<String, dynamic>.from(n as Map)))
        .toList();
  }

  /// Blocks [number]. The system matches the original and E.164 forms.
  static Future<void> block(String number) => blockAll([number]);

  /// Blocks every number in [numbers].
  static Future<void> blockAll(List<String> numbers) async {
    _ensureAndroid();
    await _channel.invokeMethod<void>('blockNumbers', numbers);
  }

  /// Unblocks [number].
  static Future<void> unblock(String number) => unblockAll([number]);

  /// Unblocks every number in [numbers].
  static Future<void> unblockAll(List<String> numbers) async {
    _ensureAndroid();
    await _channel.invokeMethod<void>('unblockNumbers', numbers);
  }

  /// Opens the system default-dialer setting so the user can grant rights.
  static Future<void> openDefaultAppSettings() async {
    _ensureAndroid();
    await _channel.invokeMethod<void>('openDefaultAppSettings');
  }
}
