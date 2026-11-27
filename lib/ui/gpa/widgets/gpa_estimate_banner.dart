import 'package:flutter/material.dart';

import '../../../domain/models/gpa_calculation.dart';

class GpaEstimateBanner extends StatelessWidget {
  const GpaEstimateBanner({super.key, required this.prediction});
  final GpaPrediction? prediction;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary,
      borderRadius: BorderRadius.circular(18),
    ),
    child: DefaultTextStyle.merge(
      style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ESTIMATED SEMESTER GPA'),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 12,
            children: [
              Text(
                prediction?.equivalent.toStringAsFixed(2) ?? '?',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('/ 4.00'),
              ),
            ],
          ),
          Text(
            '${prediction?.countedCredits.toStringAsFixed(1) ?? '0'} credit hours',
          ),
        ],
      ),
    ),
  );
}
