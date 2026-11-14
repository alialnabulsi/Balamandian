import 'package:flutter/material.dart';

class MarketplaceEmptyState extends StatelessWidget {
  const MarketplaceEmptyState({
    super.key,
    required this.search,
    required this.filtered,
  });
  final String search;
  final bool filtered;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        Icon(
          Icons.storefront_outlined,
          size: 40,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          search.isNotEmpty
              ? 'No places match your search'
              : filtered
              ? 'No places in this category'
              : 'No places yet',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          search.isNotEmpty || filtered
              ? 'Try another search or choose All places.'
              : 'Check back for places and services.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
