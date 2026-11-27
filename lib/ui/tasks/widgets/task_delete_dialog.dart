import 'package:flutter/material.dart';

import '../view_models/task_planner_view_model.dart';

class TaskDeleteDialog extends StatelessWidget {
  const TaskDeleteDialog({
    super.key,
    required this.title,
    required this.planner,
    required this.epoch,
  });
  final String title;
  final TaskPlannerViewModel planner;
  final int epoch;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: planner,
    builder: (context, _) => planner.epoch != epoch
        ? AlertDialog(
            title: const Text('Account changed'),
            content: const Text(
              'Close this dialog to continue with your current account.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          )
        : AlertDialog(
            scrollable: true,
            title: const Text('Delete task?'),
            content: Text('Delete “$title”? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete task'),
              ),
            ],
          ),
  );
}
