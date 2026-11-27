import 'package:flutter/material.dart';

import '../../../domain/models/task_models.dart';
import '../../core/themes/app_tokens.dart';
import '../../core/ui/app_surface.dart';
import 'task_status_menu.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
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
    color: Colors.transparent,
    elevation: lifted ? 8 : 0,
    borderRadius: BorderRadius.circular(AppTokens.surfaceRadius),
    child: AppSurface(
      padding: const EdgeInsets.all(AppTokens.space * 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(task.title, style: Theme.of(context).textTheme.titleMedium),
          if (task.details case final details?) ...[
            const SizedBox(height: AppTokens.space),
            Text(
              details,
              maxLines: lifted ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: AppTokens.space),
          if (pending)
            Semantics(liveRegion: true, child: const Text('Saving changes…')),
          if (!lifted)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                TaskStatusMenu(status: task.status, onChanged: onStatus),
                IconButton(
                  tooltip: 'Edit ${task.title}',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete ${task.title}',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}
