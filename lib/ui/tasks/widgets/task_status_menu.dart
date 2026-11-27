import 'package:flutter/material.dart';

import '../../../domain/models/task_models.dart';

class TaskStatusMenu extends StatelessWidget {
  const TaskStatusMenu({
    super.key,
    required this.status,
    required this.onChanged,
  });
  final TaskStatus status;
  final ValueChanged<TaskStatus>? onChanged;
  @override
  Widget build(BuildContext context) => PopupMenuButton<TaskStatus>(
    tooltip: 'Change task status. ${status.label}',
    enabled: onChanged != null,
    initialValue: status,
    onSelected: onChanged,
    itemBuilder: (_) => [
      for (final value in TaskStatus.values)
        PopupMenuItem(value: value, child: Text(value.label)),
    ],
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                status.label,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            const Icon(Icons.expand_more_rounded, size: 20),
          ],
        ),
      ),
    ),
  );
}
