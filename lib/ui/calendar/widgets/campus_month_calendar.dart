import 'package:flutter/material.dart';

import '../../../domain/models/calendar_models.dart';
import '../../core/themes/app_tokens.dart';
import 'calendar_category_filter.dart';

class CampusMonthCalendar extends StatelessWidget {
  const CampusMonthCalendar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onMonthChanged,
    this.events = const [],
    this.today,
    this.maximumGridTextScale = 1.3,
  });
  final DateTime selected;
  final DateTime? today;
  final ValueChanged<DateTime> onSelect, onMonthChanged;
  final List<CampusEvent> events;
  final double maximumGridTextScale;
  @override
  Widget build(BuildContext context) {
    final first = DateTime(selected.year, selected.month),
        count = DateTime(selected.year, selected.month + 1, 0).day,
        offset = first.weekday % 7;
    final l = MaterialLocalizations.of(context),
        scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 1,
      borderRadius: BorderRadius.circular(AppTokens.surfaceRadius),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selected,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2099, 12, 31),
                      );
                      if (date != null) onSelect(date);
                    },
                    child: Text(
                      l.formatMonthYear(selected),
                      textAlign: TextAlign.start,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Previous month',
                  onPressed: () => onMonthChanged(
                    DateTime(selected.year, selected.month - 1),
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: 'Next month',
                  onPressed: () => onMonthChanged(
                    DateTime(selected.year, selected.month + 1),
                  ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: maximumGridTextScale,
              child: Column(
                children: [
                  Row(
                    children: [
                      for (final day in l.narrowWeekdays)
                        Expanded(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                day,
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                          mainAxisExtent: 60,
                        ),
                    itemCount: ((offset + count + 6) ~/ 7) * 7,
                    itemBuilder: (context, index) {
                      final number = index - offset + 1;
                      if (number < 1 || number > count) {
                        return const SizedBox.shrink();
                      }
                      final day = DateTime(
                        selected.year,
                        selected.month,
                        number,
                      );
                      final matches = events
                              .where((e) => e.onDay(day))
                              .toList(),
                          categories = matches.map((e) => e.category).toSet();
                      return CalendarDayCell(
                        day: day,
                        selected: day.day == selected.day,
                        today: DateUtils.isSameDay(day, today),
                        categories: categories,
                        count: matches.length,
                        onTap: () => onSelect(day),
                      );
                    },
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

class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    super.key,
    required this.day,
    required this.selected,
    required this.today,
    required this.categories,
    required this.count,
    required this.onTap,
  });
  final DateTime day;
  final bool selected, today;
  final Set<CalendarCategory> categories;
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${MaterialLocalizations.of(context).formatFullDate(day)}, $count events${today ? ', today' : ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: categories.isEmpty
                ? scheme.surfaceContainerLow
                : calendarCategoryColor(
                    context,
                    categories.first,
                  ).withValues(alpha: .2),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${day.day}', style: Theme.of(context).textTheme.bodyMedium),
              if (categories.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final c in categories)
                      Padding(
                        padding: const EdgeInsets.all(1),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: calendarCategoryColor(context, c),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              if (today)
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
