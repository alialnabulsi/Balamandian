import 'package:flutter/material.dart';

import '../../core/ui/app_surface.dart';

class TaskProgressSummary extends StatelessWidget {
  const TaskProgressSummary({
    super.key,
    required this.completed,
    required this.total,
  });
  final int completed, total;
  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : completed / total;
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$completed of $total completed · ${(progress * 100).round()}%',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.outlineVariant,
            minHeight: 6,
            semanticsLabel:
                'Task completion: $completed of $total tasks completed',
          ),
        ],
      ),
    );
  }
}
