import 'package:flutter/material.dart';

/// Keeps the full heading readable on narrow phones with large system text.
class MarketplaceHeading extends StatelessWidget {
  const MarketplaceHeading({super.key});
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(
      'Marketplace',
      maxLines: 1,
      style: Theme.of(context).textTheme.headlineSmall
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}
