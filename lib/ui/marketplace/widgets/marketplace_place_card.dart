import 'package:flutter/material.dart';

import '../../../domain/models/marketplace_place_summary.dart';
import 'marketplace_image.dart';
import 'marketplace_favorite_button.dart';
import 'marketplace_rating_summary.dart';
import 'marketplace_tokens.dart';

class MarketplacePlaceCard extends StatelessWidget {
  const MarketplacePlaceCard({
    super.key,
    required this.place,
    required this.favoritePending,
    required this.onFavorite,
    required this.onOpen,
  });
  final MarketplacePlaceSummary place;
  final bool favoritePending;
  final VoidCallback onFavorite, onOpen;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MarketplaceTokens.radius),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            label: 'View ${place.name} photo and details',
            child: InkWell(
              onTap: onOpen,
              child: ExcludeSemantics(
                child: MarketplaceImage(
                  url: place.coverImageUrl,
                  slug: place.slug,
                  label: place.name,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          place.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    MarketplaceFavoriteButton(
                      isFavorite: place.isFavorite,
                      pending: favoritePending,
                      onPressed: onFavorite,
                      placeName: place.name,
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    MarketplaceRatingSummary(
                      average: place.averageRating,
                      count: place.ratingCount,
                    ),
                    Text(
                      place.category.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  place.address,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 64),
                    child: TextButton.icon(
                      onPressed: onOpen,
                      label: const Text('View details'),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      iconAlignment: IconAlignment.end,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
