import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/models/schedule_models.dart';

class ScheduleWeekGrid extends StatelessWidget {
  const ScheduleWeekGrid({
    super.key,
    required this.courses,
    required this.monday,
  });
  final List<ProposedCourse> courses;
  final DateTime monday;
  @override
  Widget build(BuildContext context) {
    final meetings = [
      for (final c in courses)
        for (final s in c.components)
          for (final m in s.meetings ?? <ClassMeeting>[])
            for (var day = 0; day < 7; day++)
              if (m.occurs(monday.add(Duration(days: day)))) (c, s, m, day),
    ];
    final days = meetings.any((e) => e.$4 > 4) ? 7 : 5,
        start = meetings.fold<int>(
          8,
          (h, e) => math.min(h, e.$3.startMinute ~/ 60),
        ),
        last = meetings.fold<int>(
          18,
          (h, e) => math.max(h, (e.$3.endMinute / 60).ceil()),
        );
    final colors = Theme.of(context).colorScheme,
        palette = [colors.primary, colors.tertiary, colors.secondary],
        height = (last - start) * 52.0;
    const column = 132.0, axis = 54.0;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: axis + days * column,
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: axis),
                for (var d = 0; d < days; d++)
                  SizedBox(
                    width: column,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '${MaterialLocalizations.of(context).narrowWeekdays[(d + 1) % 7]} ${monday.add(Duration(days: d)).day}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(
              height: height + 20,
              child: Stack(
                children: [
                  Positioned(
                    left: axis,
                    top: 0,
                    width: days * column,
                    height: height,
                    child: CustomPaint(
                      painter: TimetableGridPainter(
                        lines: last - start,
                        days: days,
                        color: colors.outlineVariant,
                      ),
                    ),
                  ),
                  for (var hour = start; hour <= last; hour++)
                    Positioned(
                      left: 0,
                      top: (hour - start) * 52.0,
                      width: axis - 5,
                      child: Text(
                        hour == 24
                            ? '24:00'
                            : MaterialLocalizations.of(context).formatTimeOfDay(
                                TimeOfDay(hour: hour, minute: 0),
                              ),
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  for (final entry in meetings)
                    Positioned(
                      left: axis + entry.$4 * column + 3,
                      top: (entry.$3.startMinute - start * 60) / 60 * 52 + 1,
                      width: column - 6,
                      height: math.max(
                        24,
                        (entry.$3.endMinute - entry.$3.startMinute) / 60 * 52 -
                            2,
                      ),
                      child: ScheduleClassBlock(
                        course: entry.$1,
                        component: entry.$2,
                        meeting: entry.$3,
                        color:
                            palette[courses.indexOf(entry.$1) % palette.length],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScheduleClassBlock extends StatelessWidget {
  const ScheduleClassBlock({
    super.key,
    required this.course,
    required this.component,
    required this.meeting,
    required this.color,
  });
  final ProposedCourse course;
  final ClassComponent component;
  final ClassMeeting meeting;
  final Color color;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${course.id}, ${component.label}, ${meeting.time}',
    child: Material(
      color: color.withValues(alpha: .24),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: Text('${course.id} - ${component.label}'),
            content: Text(
              '${course.title}\n${meeting.time}\n${meeting.location ?? 'Location not supplied'}\n${meeting.startDate} to ${meeting.endDate}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            '${course.id} ${component.label}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    ),
  );
}

class TimetableGridPainter extends CustomPainter {
  const TimetableGridPainter({
    required this.lines,
    required this.days,
    required this.color,
  });
  final int lines, days;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..strokeWidth = .7;
    for (var i = 0; i <= lines * 2; i++) {
      final y = size.height * i / (lines * 2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), pen);
    }
    for (var i = 0; i <= days; i++) {
      final x = size.width * i / days;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), pen);
    }
  }

  @override
  bool shouldRepaint(TimetableGridPainter old) =>
      old.lines != lines || old.days != days || old.color != color;
}
