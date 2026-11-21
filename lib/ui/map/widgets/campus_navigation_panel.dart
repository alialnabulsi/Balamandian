import 'package:flutter/material.dart';

import '../view_models/campus_map_view_model.dart';
import 'campus_route_summary.dart';

class CampusNavigationPanel extends StatelessWidget {
  const CampusNavigationPanel({super.key, required this.model});
  final CampusMapViewModel model;
  @override
  Widget build(BuildContext context) {
    final progress = model.progress!;
    final arrived = model.mode == CampusMapMode.arrived;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (model.simulated)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'SIMULATION · ${model.simulationPaused ? 'Paused' : 'Playing'} · ${model.simulationSpeed.toInt()}×',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(
            arrived
                ? 'You have arrived at the entrance'
                : progress.offRoute
                ? 'Return to a verified walkway'
                : '${progress.upcoming.instruction}${progress.maneuverDistance > 3 ? ' in ${progress.maneuverDistance.round()} m' : ''}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        CampusRouteSummary(
          distance: progress.remaining,
          seconds: progress.remainingSeconds,
        ),
        LinearProgressIndicator(
          value: model.plannedRoute!.distance == 0
              ? 1
              : (progress.traveled / model.plannedRoute!.distance).clamp(0, 1),
          semanticsLabel: 'Walking route progress',
        ),
        if (model.calculating)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Recalculating walking route…'),
          ),
        if (model.simulated && !arrived)
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                onPressed: model.pauseSimulation,
                icon: Icon(
                  model.simulationPaused ? Icons.play_arrow : Icons.pause,
                ),
                label: Text(model.simulationPaused ? 'Resume' : 'Pause'),
              ),
              for (final speed in [1.0, 2.0, 4.0])
                ChoiceChip(
                  label: Text('${speed.toInt()}×'),
                  selected: model.simulationSpeed == speed,
                  onSelected: (_) => model.simulationSpeedTo(speed),
                ),
            ],
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: model.recenter,
              icon: const Icon(Icons.my_location),
              label: const Text('Recenter'),
            ),
            FilledButton.tonalIcon(
              onPressed: model.endNavigation,
              icon: const Icon(Icons.close),
              label: Text(arrived ? 'Done' : 'End navigation'),
            ),
          ],
        ),
      ],
    );
  }
}
