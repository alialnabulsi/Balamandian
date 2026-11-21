import 'package:flutter/material.dart';

import '../../core/ui/buttons/async_action_button.dart';
import '../view_models/campus_map_view_model.dart';

/// Pinned outside the planner's scrolling form and above the shell navigation.
class CampusPlannerActions extends StatelessWidget {
  const CampusPlannerActions({super.key, required this.model});
  final CampusMapViewModel model;
  @override
  Widget build(BuildContext context) {
    if (model.plannedRoute == null) {
      return AsyncActionButton(
        label: 'Find walking route',
        runningLabel: 'Calculating route…',
        running: model.calculating,
        onPressed: model.directionsAvailable ? model.calculate : null,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          onPressed: () => model.beginNavigation(simulate: model.data!.fixture),
          icon: Icon(
            model.data!.fixture
                ? Icons.play_circle_outline
                : Icons.navigation_outlined,
          ),
          label: Text(
            model.data!.fixture ? 'Simulate this route' : 'Start navigation',
          ),
        ),
        if (!model.data!.fixture)
          OutlinedButton.icon(
            onPressed: () => model.beginNavigation(simulate: true),
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Simulate this route'),
          ),
      ],
    );
  }
}
