import 'package:flutter/material.dart';

import '../../../domain/models/calendar_models.dart';
import 'calendar_category_filter.dart';

class CalendarEventTile extends StatelessWidget {
  const CalendarEventTile({
    super.key,
    required this.event,
    required this.onOpen,
  });
  final CampusEvent event;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final color = calendarCategoryColor(context, event.category);
    return Card(
      child: ListTile(
        leading: Icon(categoryIcon(event.category), color: color),
        title: Text(event.title),
        subtitle: Text(
          '${event.category.name} - ${event.allDay ? 'All day' : event.start.substring(11)}${event.location == null ? '' : ' ? ${event.location}'}',
        ),
        onTap: onOpen,
      ),
    );
  }
}
