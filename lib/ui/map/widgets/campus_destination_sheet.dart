import 'package:flutter/material.dart';

import '../../../domain/models/campus/campus_data.dart';

class CampusDestinationSheet extends StatelessWidget {
  const CampusDestinationSheet({
    super.key,
    required this.destination,
    required this.onDirections,
    required this.directionsAvailable,
  });
  final CampusDestination destination;
  final VoidCallback onDirections;
  final bool directionsAvailable;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (destination.image case final image?)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              image,
              height: 140,
              fit: BoxFit.cover,
              semanticLabel: destination.name,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      if (destination.id == 'uob-campus')
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            'Al Koura main campus. This pin marks the campus overview.',
          ),
        )
      else if (destination.description case final description?)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(description),
        ),
      if (directionsAvailable)
        FilledButton.icon(
          onPressed: onDirections,
          icon: const Icon(Icons.directions_walk),
          label: const Text('Directions'),
        )
      else
        Row(
          children: [
            Icon(
              Icons.directions_walk,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            const Expanded(child: Text('Walking directions coming soon')),
          ],
        ),
    ],
  );
}
