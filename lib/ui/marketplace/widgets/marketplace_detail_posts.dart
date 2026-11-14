import 'package:flutter/material.dart';

import '../../../domain/models/marketplace_post.dart';
import 'marketplace_post_card.dart';
import 'marketplace_load_more.dart';

class MarketplaceDetailPosts extends StatelessWidget {
  const MarketplaceDetailPosts({
    super.key,
    required this.posts,
    required this.loading,
    required this.loadingMore,
    required this.hasNext,
    required this.onLoadMore,
    required this.onOpen,
  });
  final List<MarketplacePost> posts;
  final bool loading, loadingMore, hasNext;
  final VoidCallback onLoadMore;
  final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (loading)
        const LinearProgressIndicator(semanticsLabel: 'Loading place posts'),
      if (posts.isNotEmpty) ...[
        Text('News & offers', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        for (final post in posts)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MarketplacePostCard(
              post: post,
              onOpen: () => onOpen(post.place.id),
            ),
          ),
        MarketplaceLoadMore(
          hasNext: hasNext,
          pending: loadingMore,
          onPressed: onLoadMore,
          label: 'Load more posts',
          endLabel: 'All posts loaded',
        ),
      ],
    ],
  );
}
