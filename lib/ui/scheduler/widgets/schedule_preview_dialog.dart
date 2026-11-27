import 'package:flutter/material.dart';

import '../../../domain/models/schedule_models.dart';
import 'schedule_timetable.dart';

class SchedulePreviewDialog extends StatelessWidget {
  const SchedulePreviewDialog({super.key, required this.option});
  final ScheduleOption option;
  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 900,
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ScheduleTimetable(courses: option.courses, proposed: true),
            ),
          ),
        ],
      ),
    ),
  );
}
