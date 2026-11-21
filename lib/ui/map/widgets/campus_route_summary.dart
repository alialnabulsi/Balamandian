import 'package:flutter/material.dart';

class CampusRouteSummary extends StatelessWidget {
  const CampusRouteSummary({
    super.key,
    required this.distance,
    required this.seconds,
  });
  final double distance;
  final int seconds;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Wrap(
      spacing: 16,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Icon(Icons.directions_walk),
        Text(
          '${(seconds / 60).ceil().clamp(1, 999)} min',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          distance >= 1000
              ? '${(distance / 1000).toStringAsFixed(1)} km'
              : '${distance.round()} m',
        ),
        Text('Estimated walk', style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
