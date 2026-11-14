import 'package:flutter/material.dart';

class MarketplaceRatingSummary extends StatelessWidget {
  const MarketplaceRatingSummary({
    super.key,
    required this.average,
    required this.count,
  });
  final double average;
  final int count;
  @override
  Widget build(BuildContext context) => Semantics(
    label: count == 0
        ? 'Not rated yet'
        : '${average.toStringAsFixed(1)} out of 5 stars, $count ratings',
    excludeSemantics: true,
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 5,
      children: [
        Icon(
          Icons.star_rounded,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
        Text(
          count == 0
              ? 'Not rated yet'
              : '${average.toStringAsFixed(1)} ($count ${count == 1 ? 'rating' : 'ratings'})',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
