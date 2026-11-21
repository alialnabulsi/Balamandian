import 'package:flutter/material.dart';

import '../../core/ui/buttons/app_icon_button.dart';
import '../view_models/campus_map_view_model.dart';
import 'campus_route_summary.dart';

class CampusRoutePlanner extends StatelessWidget {
  const CampusRoutePlanner({super.key, required this.model});
  final CampusMapViewModel model;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'From\n${model.startLabel}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          AppIconButton(
            tooltip: 'Swap start and destination',
            icon: Icons.swap_vert,
            onPressed: model.canSwap ? model.swap : null,
          ),
        ],
      ),
      if (model.data!.entrances.isNotEmpty)
        DropdownButtonFormField<String>(
          key: ValueKey('${model.startDestinationId}-${model.origin?.nodeId}'),
          isExpanded: true,
          initialValue: model.origin?.nodeId == null
              ? null
              : model.data!.entrances.values
                    .where((e) => e.nodeId == model.origin!.nodeId)
                    .firstOrNull
                    ?.id,
          decoration: const InputDecoration(labelText: 'From · choose a place'),
          items: model.data!.entrances.values
              .map(
                (e) => DropdownMenuItem(
                  value: e.id,
                  child: Text(e.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (id) {
            if (id != null) model.startAtEntrance(model.data!.entrances[id]!);
          },
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => model.locate(asOrigin: true),
          icon: const Icon(Icons.my_location),
          label: const Text('Use current location'),
        ),
      ),
      Text(
        'To\n${model.selected!.name}',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      if (model.destinationEntrances.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: DropdownButtonFormField<String>(
            key: ValueKey('${model.selected!.id}-${model.entranceId}'),
            isExpanded: true,
            initialValue: model.entranceId,
            decoration: const InputDecoration(
              labelText: 'Destination entrance',
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Best connected entrance'),
              ),
              ...model.destinationEntrances.map(
                (e) => DropdownMenuItem(
                  value: e.id,
                  child: Text(e.name, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: model.chooseEntrance,
          ),
        ),
      if (model.data!.routingAvailable) ...[
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Avoid stairs'),
          subtitle: const Text('Does not verify wheelchair accessibility'),
          value: model.avoidStairs,
          onChanged: model.stairs,
        ),
        const Text('Or press and hold a walking path to choose your start.'),
      ] else
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('Walking directions coming soon'),
        ),
      if (model.plannedRoute case final route?) ...[
        CampusRouteSummary(
          distance: route.distance,
          seconds: route.duration.inSeconds,
        ),
        Text(
          route.accessibilityVerified
              ? 'Accessibility verified in this dataset.'
              : 'Path accessibility has not been fully verified.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ],
  );
}
