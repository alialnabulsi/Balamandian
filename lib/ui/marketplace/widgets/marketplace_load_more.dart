import 'package:flutter/material.dart';

class MarketplaceLoadMore extends StatelessWidget {
  const MarketplaceLoadMore({
    super.key,
    required this.hasNext,
    required this.pending,
    required this.onPressed,
    this.label = 'Load more places',
    this.endLabel = 'All places loaded',
  });
  final bool hasNext, pending;
  final VoidCallback onPressed;
  final String label, endLabel;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: pending
        ? const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Loading more marketplace items',
            ),
          )
        : hasNext
        ? Center(
            child: OutlinedButton.icon(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(Icons.expand_more_rounded),
              label: Text(label),
            ),
          )
        : Center(
            child: Text(endLabel, style: Theme.of(context).textTheme.bodySmall),
          ),
  );
}
