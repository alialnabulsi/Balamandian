import 'package:flutter/material.dart';

import '../../core/ui/form_message.dart';
import '../view_models/campus_map_view_model.dart';
import 'campus_panel.dart';
import 'campus_destination_sheet.dart';
import 'campus_explore_card.dart';
import 'campus_route_planner.dart';
import 'campus_navigation_panel.dart';
import 'campus_planner_actions.dart';

class CampusContextPanel extends StatelessWidget {
  const CampusContextPanel({
    super.key,
    required this.model,
    required this.onHeight,
  });
  final CampusMapViewModel model;
  final ValueChanged<double> onHeight;
  @override
  Widget build(BuildContext context) => CampusPanel(
    key: ValueKey(model.mode),
    title: switch (model.mode) {
      CampusMapMode.explore =>
        model.data!.fixture ? 'Development demo' : 'Al Koura campus',
      CampusMapMode.selected => model.selected!.name,
      CampusMapMode.planning => 'Plan your walk',
      CampusMapMode.navigating =>
        model.simulated ? 'Simulated walk' : 'Walking navigation',
      CampusMapMode.arrived => 'Arrival',
      CampusMapMode.search => '',
    },
    subtitle: switch (model.mode) {
      CampusMapMode.explore => 'Explore Balamand',
      CampusMapMode.selected =>
        '${model.selected!.code} · ${model.selected!.category}',
      _ => '',
    },
    collapsed: model.mode == CampusMapMode.explore,
    onClose: model.closeContext,
    onHeight: onHeight,
    footer: model.mode == CampusMapMode.planning
        ? CampusPlannerActions(model: model)
        : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (model.error case final error?)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FormMessage(error),
          ),
        switch (model.mode) {
          CampusMapMode.explore => CampusExploreCard(
            fixture: model.data!.fixture,
            routingAvailable: model.data!.routingAvailable,
            onBrowse: model.beginSearch,
          ),
          CampusMapMode.selected => CampusDestinationSheet(
            destination: model.selected!,
            directionsAvailable: model.directionsAvailable,
            onDirections: model.directions,
          ),
          CampusMapMode.planning => CampusRoutePlanner(model: model),
          CampusMapMode.navigating ||
          CampusMapMode.arrived => CampusNavigationPanel(model: model),
          CampusMapMode.search => const SizedBox.shrink(),
        },
      ],
    ),
  );
}
