import 'package:flutter/material.dart';

class MarketplaceFavoriteButton extends StatelessWidget {
  const MarketplaceFavoriteButton({
    super.key,
    required this.isFavorite,
    required this.pending,
    required this.onPressed,
    required this.placeName,
  });
  final bool isFavorite, pending;
  final String placeName;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: pending
        ? 'Updating favorite for $placeName'
        : isFavorite
        ? 'Remove $placeName from favorites'
        : 'Save $placeName to favorites',
    isSelected: isFavorite,
    onPressed: pending ? null : onPressed,
    style: IconButton.styleFrom(
      minimumSize: const Size.square(48),
      foregroundColor: Theme.of(context).colorScheme.primary,
    ),
    icon: pending
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: 'Updating favorite',
            ),
          )
        : Icon(
            isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          ),
  );
}
