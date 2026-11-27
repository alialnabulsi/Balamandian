import 'package:flutter/material.dart';

import '../../../domain/models/calendar_models.dart';

IconData categoryIcon(CalendarCategory c) => switch (c) {
  CalendarCategory.academic => Icons.school_outlined,
  CalendarCategory.university => Icons.account_balance_outlined,
  CalendarCategory.personal => Icons.person_outline,
};

Color calendarCategoryColor(BuildContext context, CalendarCategory category) {
  final colors = Theme.of(context).colorScheme;
  return switch (category) {
    CalendarCategory.academic => colors.primary,
    CalendarCategory.university => colors.tertiary,
    CalendarCategory.personal => colors.secondary,
  };
}

class CalendarCategoryFilter extends StatelessWidget {
  const CalendarCategoryFilter({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.member,
  });
  final Set<CalendarCategory> selected;
  final void Function(CalendarCategory, bool) onChanged;
  final bool member;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final c in CalendarCategory.values)
          if (member || c == CalendarCategory.academic)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FilterChip(
                avatar: Icon(
                  categoryIcon(c),
                  size: 18,
                  color: calendarCategoryColor(context, c),
                ),
                showCheckmark: false,
                selectedColor: calendarCategoryColor(
                  context,
                  c,
                ).withValues(alpha: .15),
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                label: Text(c.name[0].toUpperCase() + c.name.substring(1)),
                selected: selected.contains(c),
                onSelected: (v) => onChanged(c, v),
              ),
            ),
      ],
    ),
  );
}
