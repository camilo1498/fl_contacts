/// UI state of a fire-and-report demo task.
class DemoTaskState {
  /// Creates a state snapshot.
  const DemoTaskState({this.log = 'Idle', this.running = false});

  /// Human-readable progress line shown under the demo buttons.
  final String log;

  /// Whether work is in flight; buttons disable while true.
  final bool running;

  /// Copies the state with replaced fields.
  DemoTaskState copyWith({String? log, bool? running}) => DemoTaskState(
    log: log ?? this.log,
    running: running ?? this.running,
  );
}
