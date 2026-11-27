import 'package:flutter/material.dart';

import '../../../domain/models/task_models.dart';
import '../../core/themes/app_tokens.dart';

class TaskKanbanCard extends StatelessWidget {
  const TaskKanbanCard({
    super.key,
    required this.task,
    this.onEdit,
    this.onDelete,
    this.onStatus,
    this.pending = false,
    this.lifted = false,
  });
  final PlannerTask task;
  final VoidCallback? onEdit, onDelete;
  final ValueChanged<TaskStatus>? onStatus;
  final bool pending, lifted;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    elevation: lifted ? 8 : 1,
    borderRadius: BorderRadius.circular(AppTokens.controlRadius),
    child: InkWell(
      borderRadius: BorderRadius.circular(AppTokens.controlRadius),
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              task.title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                decoration: task.status == TaskStatus.done
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            if (pending)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(semanticsLabel: 'Saving task'),
              ),
            if (!lifted && (onStatus != null || onEdit != null))
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: PopupMenuButton<String>(
                  tooltip: 'Actions for ${task.title}',
                  padding: EdgeInsets.zero,
                  onSelected: (v) {
                    if (v == 'edit') {
                      onEdit?.call();
                    } else if (v == 'delete') {
                      onDelete?.call();
                    } else {
                      onStatus?.call(
                        TaskStatus.values.firstWhere((s) => s.value == v),
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    for (final s in TaskStatus.values)
                      PopupMenuItem(value: s.value, child: Text(s.label)),
                    const PopupMenuDivider(),
                    if (onEdit != null)
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                  ],
                  icon: const Icon(Icons.more_horiz, size: 20),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
