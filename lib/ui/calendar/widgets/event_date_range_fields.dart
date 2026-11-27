import 'package:flutter/material.dart';

class EventDateRangeFields extends StatelessWidget {
  const EventDateRangeFields({
    super.key,
    required this.start,
    required this.end,
    required this.allDay,
    required this.enabled,
    required this.onStart,
    required this.onEnd,
  });
  final DateTime start, end;
  final bool allDay, enabled;
  final ValueChanged<DateTime> onStart, onEnd;
  Future<void> pick(
    BuildContext context,
    DateTime current,
    ValueChanged<DateTime> changed,
    bool time,
  ) async {
    if (time) {
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current),
      );
      if (context.mounted && t != null) {
        changed(
          DateTime.utc(
            current.year,
            current.month,
            current.day,
            t.hour,
            t.minute,
          ),
        );
      }
    } else {
      final d = await showDatePicker(
        context: context,
        initialDate: current,
        firstDate: DateTime(2000),
        lastDate: DateTime(2099, 12, 30),
      );
      if (context.mounted && d != null) {
        changed(
          DateTime.utc(d.year, d.month, d.day, current.hour, current.minute),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      for (final pair in [(start, onStart, 'Start'), (end, onEnd, 'End')]) ...[
        if (pair.$3 == 'End')
          const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.arrow_forward, size: 20),
          ),
        Expanded(
          child: Column(
            children: [
              TextButton(
                onPressed: enabled
                    ? () => pick(context, pair.$1, pair.$2, false)
                    : null,
                child: Text(
                  MaterialLocalizations.of(context).formatMediumDate(pair.$1),
                  textAlign: TextAlign.center,
                  semanticsLabel: '${pair.$3} date',
                ),
              ),
              if (!allDay)
                TextButton(
                  onPressed: enabled
                      ? () => pick(context, pair.$1, pair.$2, true)
                      : null,
                  child: Text(
                    MaterialLocalizations.of(context)
                        .formatTimeOfDay(TimeOfDay.fromDateTime(pair.$1)),
                    semanticsLabel: '${pair.$3} time',
                  ),
                ),
            ],
          ),
        ),
      ],
    ],
  );
}
