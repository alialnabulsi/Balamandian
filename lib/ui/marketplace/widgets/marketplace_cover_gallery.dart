import 'package:flutter/material.dart';

import '../../../domain/models/marketplace_place_detail.dart';
import 'marketplace_image.dart';
import 'marketplace_tokens.dart';

class MarketplaceCoverGallery extends StatelessWidget {
  const MarketplaceCoverGallery({super.key, required this.detail});
  final MarketplacePlaceDetail detail;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(MarketplaceTokens.radius),
        child: MarketplaceImage(
          url: detail.place.coverImageUrl,
          slug: detail.place.slug,
          label: '${detail.place.name} cover image',
        ),
      ),
      if (detail.images.isNotEmpty) ...[
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final image in detail.images)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 180,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        MarketplaceTokens.radius,
                      ),
                      child: MarketplaceImage(
                        url: image.imageUrl,
                        slug: detail.place.slug,
                        label:
                            image.alternativeText ??
                            '${detail.place.name} gallery image',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ],
  );
}
