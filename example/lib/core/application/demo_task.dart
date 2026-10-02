import 'package:fl_contacts_example/core/application/models/demo_task_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Base for tools-page demos: busy flag, log line and guarded execution.
///
/// Subclasses only implement [runTask]; this base owns the lifecycle so
/// pages stay declarative.
abstract class DemoTaskController extends Notifier<DemoTaskState> {
  @override
  DemoTaskState build() => const DemoTaskState();

  /// Override with the demo work; may throw, errors land in [DemoTaskState].
  Future<String> runTask();

  /// Executes [runTask] (or [task] when given) unless one is already running.
  Future<void> execute([Future<String> Function()? task]) async {
    if (state.running) return;
    state = state.copyWith(running: true, log: 'Running…');
    try {
      state = state.copyWith(log: await (task?.call() ?? runTask()));
    } catch (e) {
      state = state.copyWith(log: 'Error: $e');
    } finally {
      if (ref.mounted) state = state.copyWith(running: false);
    }
  }
}
