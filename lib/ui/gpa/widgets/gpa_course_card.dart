import 'package:flutter/material.dart';

import '../../../domain/models/gpa_calculation.dart';
import 'gpa_input.dart';

class GpaCourseCard extends StatelessWidget {
  const GpaCourseCard({
    super.key,
    required this.course,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });
  final PredictedCourse course;
  final int index;
  final ValueChanged<PredictedCourse> onChanged;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final fields = [
        GpaInput(
          label: 'Course',
          numeric: false,
          value: course.name,
          error: course.name.isEmpty ? null : course.nameError,
          onChanged: (s) => onChanged(course.copyWith(name: s)),
        ),
        GpaInput(
          label: 'Credits',
          value: course.credits,
          error: course.credits.isEmpty ? null : course.creditsError,
          onChanged: (s) => onChanged(course.copyWith(credits: s)),
        ),
        GpaInput(
          label: 'Grade /100',
          value: course.grade,
          error: course.grade.isEmpty ? null : course.gradeError,
          onChanged: (s) => onChanged(course.copyWith(grade: s)),
        ),
      ];
      final remove = IconButton(
        tooltip: 'Remove course $index',
        onPressed: onRemove,
        icon: const Icon(Icons.delete_outline),
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child:
            size.maxWidth >= 360 &&
                MediaQuery.textScalerOf(context).scale(14) <= 18
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: fields[0]),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: fields[1]),
                  const SizedBox(width: 8),
                  Expanded(flex: 3, child: fields[2]),
                  remove,
                ],
              )
            : Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: fields[0]),
                      remove,
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: fields[1]),
                      const SizedBox(width: 12),
                      Expanded(child: fields[2]),
                    ],
                  ),
                ],
              ),
      );
    },
  );
}
