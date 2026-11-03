import 'package:flutter/material.dart';

class TourProgress extends StatelessWidget {
  const TourProgress({
    super.key,
    required this.index,
    required this.onSelected,
    this.narrow = false,
  });
  final int index;
  final ValueChanged<int>? onSelected;
  final bool narrow;
  static const names = [
    'Find your way',
    'Find your people',
    'Tools and campus assistant',
  ];
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(
      3,
      (i) => Padding(
        padding: EdgeInsets.symmetric(horizontal: narrow ? 0 : 2),
        child: Semantics(
          selected: i == index,
          child: IconButton(
            tooltip: 'Go to step ${i + 1}: ${names[i]}',
            onPressed: onSelected == null ? null : () => onSelected!(i),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tightFor(
              width: narrow ? 48 : 52,
              height: 48,
            ),
            icon: Container(
              width: narrow ? 34 : 40,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: i == index
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
