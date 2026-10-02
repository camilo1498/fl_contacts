import 'package:fl_contacts_example/core/application/demo_task.dart';

/// Extra button on a demo section reusing its controller.
class DemoAction {
  /// Creates an action with its [label] and [run] callback.
  const DemoAction({required this.label, required this.run});

  /// Button text.
  final String label;

  /// Work receiving the owning controller.
  final Future<void> Function(DemoTaskController controller) run;
}
