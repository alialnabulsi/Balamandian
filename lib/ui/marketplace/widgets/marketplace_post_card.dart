import 'package:flutter/material.dart';

import '../../../domain/models/marketplace_post.dart';
import 'marketplace_image.dart';
import 'marketplace_tokens.dart';

class MarketplacePostCard extends StatelessWidget {
  const MarketplacePostCard({
    super.key,
    required this.post,
    required this.onOpen,
  });
  final MarketplacePost post;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), ad = post.type == 'advertisement';
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MarketplaceTokens.radius),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MarketplaceImage(
              url: post.imageUrl ?? post.place.coverImageUrl,
              slug: post.place.slug,
              label: post.title,
              aspectRatio: 2,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ad ? 'ADVERTISEMENT' : 'NEWS',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: ad
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(post.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(post.body, style: theme.textTheme.bodyMedium),
                  TextButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: Text(post.place.name),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
