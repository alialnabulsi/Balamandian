import 'package:flutter/material.dart';

class MarketplaceLocationSection extends StatelessWidget {
  const MarketplaceLocationSection({
    super.key,
    required this.address,
    required this.onDirections,
  });
  final String address;
  final VoidCallback? onDirections;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Location', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.location_on_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(address)),
        ],
      ),
      if (onDirections != null)
        TextButton.icon(
          onPressed: onDirections,
          icon: const Icon(Icons.directions_outlined),
          label: const Text('Open directions'),
        ),
    ],
  );
}
