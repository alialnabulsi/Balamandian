import 'package:flutter/material.dart';

class MarketplaceStarInput extends StatelessWidget {
  const MarketplaceStarInput({
    super.key,
    required this.rating,
    required this.pending,
    required this.onRate,
    required this.onRemove,
  });
  final int? rating;
  final bool pending;
  final ValueChanged<int> onRate;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Your rating', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      Text(
        rating == null
            ? 'Tap a star to rate this place.'
            : 'You rated this place $rating out of 5 stars.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      Wrap(
        children: [
          for (var value = 1; value <= 5; value++)
            IconButton(
              tooltip: 'Rate $value out of 5 stars',
              onPressed: pending ? null : () => onRate(value),
              style: IconButton.styleFrom(
                minimumSize: const Size.square(48),
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              icon: Icon(
                value <= (rating ?? 0)
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                size: 30,
              ),
            ),
        ],
      ),
      if (pending)
        const LinearProgressIndicator(semanticsLabel: 'Saving your rating'),
      if (rating != null)
        TextButton.icon(
          onPressed: pending ? null : onRemove,
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Remove my rating'),
        ),
    ],
  );
}
