import 'package:flutter/material.dart';

class MarketplaceLoadingState extends StatelessWidget {
  const MarketplaceLoadingState({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading marketplace',
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const CircularProgressIndicator(semanticsLabel: 'Loading places'),
          const SizedBox(height: 24),
          for (var i = 0; i < 2; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const AspectRatio(aspectRatio: 1.8),
              ),
            ),
        ],
      ),
    ),
  );
}
