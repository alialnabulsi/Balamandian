import 'package:flutter/material.dart';

import 'schedule_week_grid.dart';

import '../../../domain/models/schedule_models.dart';

class ScheduleTimetable extends StatefulWidget {
  const ScheduleTimetable({
    super.key,
    required this.courses,
    required this.proposed,
  });
  final List<ProposedCourse> courses;
  final bool proposed;
  @override
  State<ScheduleTimetable> createState() => _ScheduleTimetableState();
}

class _ScheduleTimetableState extends State<ScheduleTimetable> {
  bool week = true;
  late DateTime day = _initialDay();
  DateTime _initialDay() {
    final dates = [
      for (final c in widget.courses)
        for (final s in c.components)
          for (final m in s.meetings ?? <ClassMeeting>[])
            DateTime.parse(m.startDate),
    ]..sort();
    final now = DateTime.now();
    return dates.isNotEmpty && dates.first.isAfter(now) ? dates.first : now;
  }

  @override
  Widget build(BuildContext context) {
    final monday = DateTime(day.year, day.month, day.day - day.weekday + 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.proposed
              ? 'Proposed timetable - NOT registered'
              : 'Actual SIS-registered timetable',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: () => setState(() => week = false),
              child: const Text('Agenda'),
            ),
            TextButton(
              onPressed: () => setState(() => week = true),
              child: const Text('Week'),
            ),
            IconButton(
              tooltip: 'Previous week',
              onPressed: () =>
                  setState(() => day = day.subtract(const Duration(days: 7))),
              icon: const Icon(Icons.chevron_left),
            ),
            Text(MaterialLocalizations.of(context).formatCompactDate(monday)),
            IconButton(
              tooltip: 'Next week',
              onPressed: () =>
                  setState(() => day = day.add(const Duration(days: 7))),
              icon: const Icon(Icons.chevron_right),
            ),
            TextButton(
              onPressed: () => setState(() => day = DateTime.now()),
              child: const Text('This week'),
            ),
          ],
        ),
        if (week)
          ScheduleWeekGrid(courses: widget.courses, monday: monday)
        else ...[
          for (var i = 0; i < 7; i++)
            ScheduleDayAgenda(
              day: monday.add(Duration(days: i)),
              courses: widget.courses,
            ),
        ],
        for (final c in widget.courses)
          ExpansionTile(
            title: Text('${c.id} - ${c.title}'),
            subtitle: Text('${c.credits} credits'),
            children: [
              for (final component in c.components)
                ListTile(
                  title: Text('${component.kind}: ${component.label}'),
                  subtitle: Text(
                    component.meetings == null
                        ? 'Meeting times unverified'
                        : component.meetings!
                              .map(
                                (m) =>
                                    '${m.startDate} - ${m.endDate} - ${m.time}${m.weekInterval == 2 ? ' - alternating weeks' : ''} - ${m.location ?? 'Location not supplied'}',
                              )
                              .join('\n'),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class ScheduleDayAgenda extends StatelessWidget {
  const ScheduleDayAgenda({
    super.key,
    required this.day,
    required this.courses,
  });
  final DateTime day;
  final List<ProposedCourse> courses;
  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final c in courses)
        for (final s in c.components)
          for (final m in s.meetings ?? <ClassMeeting>[])
            if (m.occurs(day)) (c, s, m),
    ]..sort((a, b) => a.$3.startMinute.compareTo(b.$3.startMinute));
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            MaterialLocalizations.of(context).formatMediumDate(day),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No verified meetings'),
            ),
          for (final e in entries)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.$3.time),
                    Text(
                      e.$1.id,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(e.$2.label),
                    if (e.$3.location != null) Text(e.$3.location!),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
