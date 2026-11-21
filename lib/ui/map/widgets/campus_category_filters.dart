import 'package:flutter/material.dart';

class CampusCategoryFilters extends StatelessWidget {
  const CampusCategoryFilters({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });
  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('All places'),
          selectedColor: Theme.of(context).colorScheme.primaryContainer,
          backgroundColor: Theme.of(context).colorScheme.surface,
          checkmarkColor: Theme.of(context).colorScheme.primary,
          labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected == null
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          selected: selected == null,
          onSelected: (_) => onSelected(null),
        ),
        for (final category in categories)
          ChoiceChip(
            label: Text(category),
            selectedColor: Theme.of(context).colorScheme.primaryContainer,
            backgroundColor: Theme.of(context).colorScheme.surface,
            checkmarkColor: Theme.of(context).colorScheme.primary,
            labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected == category
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            selected: selected == category,
            onSelected: (value) => onSelected(value ? category : null),
          ),
      ],
    ),
  );
}
