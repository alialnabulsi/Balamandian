import 'package:flutter/material.dart';

import '../../../domain/models/task_models.dart';
import '../../core/themes/app_tokens.dart';

class TaskKanbanColumn extends StatelessWidget {
  const TaskKanbanColumn({
    super.key,
    required this.status,
    required this.tasks,
    required this.enabled,
    required this.onAccept,
    required this.cardBuilder,
    this.pendingId,
    this.highlighted = false,
  });
  final TaskStatus status;
  final List<PlannerTask> tasks;
  final bool enabled;
  final String? pendingId;
  final bool highlighted;
  final ValueChanged<PlannerTask> onAccept;
  final Widget Function(PlannerTask) cardBuilder;
  @override
  Widget build(BuildContext context) => DragTarget<PlannerTask>(
    onWillAcceptWithDetails: (details) =>
        enabled && details.data.status != status,
    onAcceptWithDetails: (details) {
      if (enabled && details.data.status != status) onAccept(details.data);
    },
    builder: (context, candidates, rejected) {
      final scheme = Theme.of(context).colorScheme;
      return Container(
        key: ValueKey('column-${status.value}'),
        constraints: const BoxConstraints(minHeight: 240),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: highlighted ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTokens.surfaceRadius),
          border: Border.all(
            color: highlighted ? scheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                '${status.label}  ${tasks.length}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            for (final task in tasks)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: cardBuilder(task),
              ),
          ],
        ),
      );
    },
  );
}
