import 'package:flutter/material.dart';

import '../../core/ui/buttons/async_action_button.dart';

class TaskPlannerHeader extends StatelessWidget {
  const TaskPlannerHeader({
    super.key,
    required this.onBack,
    required this.onAdd,
  });
  final VoidCallback onBack;
  final VoidCallback? onAdd;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Tools'),
        ),
      ),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          Text(
            'To-do Planner',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          AsyncActionButton(label: 'Add task', onPressed: onAdd),
        ],
      ),
    ],
  );
}
