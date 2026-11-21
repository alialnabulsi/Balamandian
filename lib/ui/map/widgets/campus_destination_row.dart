import 'package:flutter/material.dart';

import '../../../domain/models/campus/campus_data.dart';

class CampusDestinationRow extends StatelessWidget {
  const CampusDestinationRow({
    super.key,
    required this.destination,
    required this.onSelected,
  });
  final CampusDestination destination;
  final VoidCallback onSelected;
  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: ListTile(
      leading: Icon(switch (destination.category.toLowerCase()) {
        'library' => Icons.local_library_outlined,
        'parking' => Icons.local_parking,
        'gates' => Icons.meeting_room_outlined,
        'sports' => Icons.sports_soccer,
        _ => Icons.location_on_outlined,
      }),
      title: Text(destination.name),
      subtitle: Text('${destination.code} · ${destination.category}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: onSelected,
    ),
  );
}
