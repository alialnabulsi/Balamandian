import 'package:flutter/material.dart';

import '../../core/ui/app_surface.dart';
import '../view_models/campus_map_view_model.dart';
import 'campus_location_status.dart';

class CampusMapNotice extends StatelessWidget {
  const CampusMapNotice({super.key, required this.model});
  final CampusMapViewModel model;
  @override
  Widget build(BuildContext context) => AppSurface(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Semantics(
      liveRegion: true,
      child: model.mapError != null
          ? Row(
              children: [
                Expanded(
                  child: Text(
                    model.mapError!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: model.retryMap,
                  child: const Text('Retry'),
                ),
              ],
            )
          : CampusLocationStatus(
              access: model.locationAccess,
              simulated: model.simulated,
              accuracy: model.fix?.accuracy,
              onRetry: model.locate,
              onSettings: model.locationSettings,
            ),
    ),
  );
}
