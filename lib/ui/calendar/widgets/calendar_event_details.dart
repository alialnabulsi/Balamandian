import 'package:flutter/material.dart';

import '../../../domain/models/calendar_models.dart';

class CalendarEventDetails extends StatelessWidget {
  const CalendarEventDetails({
    super.key,
    required this.event,
    required this.member,
    required this.onEdit,
    required this.onDelete,
    required this.onReminder,
    required this.onSource,
  });
  final CampusEvent event;
  final bool member;
  final VoidCallback onEdit, onDelete, onSource;
  final ValueChanged<int?> onReminder;
  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(event.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${event.category.name.toUpperCase()} - Asia/Beirut'),
        Text(
          '${event.start} - ${event.end}${event.allDay ? ' (end exclusive)' : ''}',
        ),
        if (event.details != null) SelectableText(event.details!),
        if (event.location != null) Text(event.location!),
        if (event.sourceLabel != null) Text('Source: ${event.sourceLabel}'),
        if (event.academicYear != null)
          Text('Academic year ${event.academicYear}'),
        if (event.sourceUrl != null)
          TextButton(
            onPressed: onSource,
            child: const Text('Open official source'),
          ),
        if (member && !event.personal)
          DropdownButtonFormField<int?>(
            initialValue: event.reminderMinutes,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'My reminder'),
            items: [
              for (final m in reminderLeads)
                DropdownMenuItem(value: m, child: Text(reminderLabel(m))),
            ],
            onChanged: onReminder,
          ),
        if (!event.personal) const Text('Published event - read only'),
      ],
    ),
    actions: [
      if (member && event.personal) ...[
        TextButton(onPressed: onDelete, child: const Text('Delete')),
        TextButton(onPressed: onEdit, child: const Text('Edit')),
      ],
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}
