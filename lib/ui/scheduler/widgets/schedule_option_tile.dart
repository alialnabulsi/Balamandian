import 'package:flutter/material.dart';

import '../../../domain/models/schedule_models.dart';

class ScheduleOptionTile extends StatelessWidget {
  const ScheduleOptionTile({
    super.key,
    required this.option,
    required this.index,
    required this.onOpen,
    required this.onSave,
    required this.enabled,
  });
  final ScheduleOption option;
  final int index;
  final VoidCallback onOpen, onSave;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Option $index ? ${option.credits} credits',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            option.courses.map((c) => '${c.id} (${c.bundleId})').join(' - '),
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: onOpen,
                child: const Text('View timetable'),
              ),
              FilledButton(
                onPressed: enabled ? onSave : null,
                child: const Text('Choose schedule'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
