import 'package:fl_contacts/fl_contacts.dart';
import 'package:fl_contacts_example/core/application/demo_task.dart';
import 'package:fl_contacts_example/core/application/models/demo_task_state.dart';
import 'package:fl_contacts_example/core/providers/sync_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Blocked-numbers actions with status feedback.
class BlockedController extends DemoTaskController {
  @override
  Future<String> runTask() async {
    final blocked = await FlBlockedNumbers.isBlocked('555-0100');
    return blocked ? '555-0100 is blocked' : '555-0100 is not blocked';
  }

  /// Blocks two sample numbers and refreshes lists.
  Future<void> blockSample() {
    return execute(() async {
      await FlBlockedNumbers.blockAll(['555-0101', '555-0102']);
      ref.invalidate(databaseVersionProvider);
      return 'Blocked 555-0101, 555-0102';
    });
  }

  /// Unblocks the sample numbers and refreshes lists.
  Future<void> unblockSample() {
    return execute(() async {
      await FlBlockedNumbers.unblockAll(['555-0101', '555-0102']);
      ref.invalidate(databaseVersionProvider);
      return 'Unblocked sample numbers';
    });
  }

  /// Opens the system default-dialer settings.
  Future<void> openSettings() =>
      execute(() async {
        await FlBlockedNumbers.openDefaultAppSettings();
        return 'Opened dialer settings';
      });
}

/// Blocked-numbers actions.
final blockedControllerProvider =
    NotifierProvider<BlockedController, DemoTaskState>(
  BlockedController.new,
);

/// Ringtone actions with status feedback.
class RingtoneController extends DemoTaskController {
  @override
  Future<String> runTask() async {
    final uri = await FlRingtones.getDefaultUri(RingtoneType.ringtone);
    return 'Default ringtone: ${uri ?? 'none'}';
  }

  /// Picks a ringtone through system UI and sets it as default.
  Future<void> pickDefault() {
    return execute(() async {
      final uri = await FlRingtones.pick(RingtoneType.ringtone);
      if (uri != null) {
        await FlRingtones.setDefaultUri(RingtoneType.ringtone, uri);
        return 'Default set';
      }
      return 'Picker cancelled';
    });
  }

  /// Previews a ringtone URI.
  Future<void> play(String uri) {
    return execute(() async {
      await FlRingtones.play(uri);
      return 'Playing…';
    });
  }

  /// Stops any in-progress preview.
  Future<void> stop() {
    return execute(() async {
      await FlRingtones.stop();
      return 'Stopped';
    });
  }
}

/// Ringtone actions.
final ringtoneControllerProvider =
    NotifierProvider<RingtoneController, DemoTaskState>(
  RingtoneController.new,
);
