import 'package:flutter/material.dart';

class CampusExploreCard extends StatelessWidget {
  const CampusExploreCard({
    super.key,
    required this.fixture,
    required this.routingAvailable,
    required this.onBrowse,
  });
  final bool fixture, routingAvailable;
  final VoidCallback onBrowse;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        fixture
            ? 'Demo places and paths in London.'
            : 'Explore the University of Balamand, Al Koura.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: 12),
      if (!routingAvailable) ...[
        const Text('Walking directions coming soon'),
        const SizedBox(height: 12),
      ],
      OutlinedButton.icon(
        onPressed: onBrowse,
        icon: const Icon(Icons.search_rounded),
        label: const Text('Browse places'),
      ),
    ],
  );
}
