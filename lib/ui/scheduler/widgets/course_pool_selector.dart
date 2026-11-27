import 'package:flutter/material.dart';

import '../../../domain/models/schedule_models.dart';

class CoursePoolSelector extends StatelessWidget {
  const CoursePoolSelector({
    super.key,
    required this.courses,
    required this.selected,
    required this.onSelect,
    required this.onSearch,
    required this.onCredits,
    required this.enabled,
    required this.target,
    this.validTarget = true,
  });
  final List<CandidateCourse> courses;
  final Set<String> selected;
  final void Function(String, bool) onSelect;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onCredits;
  final bool enabled;
  final String target;
  final bool validTarget;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextFormField(
        initialValue: target,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Exact credit target (up to 36)',
          errorText: validTarget ? null : 'Enter credits greater than 0, up to 36 (max 2 decimal places).',
        ),
        onChanged: onCredits,
      ),
      const Text(
        'Select a candidate pool. It may exceed the target; the generator chooses subsets.',
      ),
      TextField(
        enabled: enabled,
        decoration: const InputDecoration(
          labelText: 'Search verified offered courses',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: onSearch,
      ),
      for (final c in courses)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${c.id} - ${c.title}'),
          subtitle: Text('${c.credits} credits - ${c.reason ?? c.status}'),
          value: selected.contains(c.id),
          onChanged: enabled && c.status == 'eligible'
              ? (v) => onSelect(c.id, v ?? false)
              : null,
        ),
      Text('${selected.length} candidate courses selected'),
    ],
  );
}
