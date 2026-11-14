import 'package:flutter/material.dart';

class MarketplaceFeedback extends StatelessWidget {
  const MarketplaceFeedback({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    ),
  );
}
