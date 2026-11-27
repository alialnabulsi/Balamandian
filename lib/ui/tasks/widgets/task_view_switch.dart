import 'package:flutter/material.dart';

import '../view_models/task_planner_view_model.dart';

class TaskViewSwitch extends StatelessWidget {
  const TaskViewSwitch({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final PlannerView selected;
  final ValueChanged<PlannerView> onChanged;
  @override
  Widget build(BuildContext context) => SegmentedButton<PlannerView>(
    showSelectedIcon: false,
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surface,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurface,
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 8),
      ),
      textStyle: WidgetStatePropertyAll(
        Theme.of(context).textTheme.labelMedium,
      ),
    ),
    segments: const [
      ButtonSegment(value: PlannerView.list, label: Text('List')),
      ButtonSegment(value: PlannerView.kanban, label: Text('Kanban')),
    ],
    selected: {selected},
    onSelectionChanged: (value) => onChanged(value.single),
  );
}
