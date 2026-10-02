import 'dart:io';

import 'package:fl_contacts/ringtone.dart';
import 'package:flutter/services.dart';

/// Android system ringtones via `RingtoneManager` and `MediaStore`.
///
/// Every other platform throws [UnsupportedError]. Picking and playback run
/// through system UI and never block the Dart thread.
class FlRingtones {
  static const _channel = MethodChannel('github.com/QuisApp/fl_contacts');

  static void _ensureAndroid() {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Ringtones are only available on Android.');
    }
  }

  /// Describes the ringtone at [uri], optionally with store metadata.
  static Future<Ringtone?> get(String uri, {bool withMetadata = true}) async {
    _ensureAndroid();
    final map = await _channel.invokeMethod<Map<Object?, Object?>>(
      'getRingtone',
      [uri, withMetadata],
    );
    if (map == null) return null;
    final json = Map<String, dynamic>.from(map);
    return Ringtone(
      uri: (json['uri'] as String?) ?? uri,
      title: (json['title'] as String?) ?? '',
    );
  }

  /// Every ringtone of [type], or of all slots when null.
  static Future<List<Ringtone>> getAll({
    RingtoneType? type,
    bool withMetadata = false,
  }) async {
    _ensureAndroid();
    final list =
        await _channel.invokeMethod<List<dynamic>>('getRingtones', [
          type?.value,
          withMetadata,
        ]) ??
        [];
    return list.map((e) {
      final json = Map<String, dynamic>.from(e as Map);
      return Ringtone(
        uri: (json['uri'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
      );
    }).toList();
  }

  /// Shows the system picker for [type] and returns the chosen URI.
  ///
  /// Returns `null` when the user cancels. [existingUri] pre-checks an entry.
  static Future<String?> pick(RingtoneType type, {String? existingUri}) async {
    _ensureAndroid();
    return _channel.invokeMethod<String>('pickRingtone', [
      type.value,
      existingUri,
    ]);
  }

  /// The current default URI for [type], if any.
  static Future<String?> getDefaultUri(RingtoneType type) async {
    _ensureAndroid();
    return _channel.invokeMethod<String>('getDefaultRingtone', [type.value]);
  }

  /// Sets (or clears, with null) the default URI for [type].
  static Future<void> setDefaultUri(
    RingtoneType type,
    String? ringtoneUri,
  ) async {
    _ensureAndroid();
    await _channel.invokeMethod<void>('setDefaultRingtone', [
      type.value,
      ringtoneUri,
    ]);
  }

  /// Previews the ringtone at [uri]. Call [stop] to end playback early.
  static Future<void> play(String ringtoneUri) async {
    _ensureAndroid();
    await _channel.invokeMethod<void>('playRingtone', [ringtoneUri]);
  }

  /// Stops an in-progress preview started by [play].
  static Future<void> stop() async {
    _ensureAndroid();
    await _channel.invokeMethod<void>('stopRingtone');
  }
}
