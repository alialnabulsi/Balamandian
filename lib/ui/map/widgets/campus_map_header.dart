import 'package:flutter/material.dart';

import '../view_models/campus_map_view_model.dart';
import 'campus_category_filters.dart';
import 'campus_search_bar.dart';

class CampusMapHeader extends StatelessWidget {
  const CampusMapHeader({super.key, required this.model});
  final CampusMapViewModel model;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (!model.navigating)
        CampusSearchBar(
          query: model.query,
          searching: model.searching,
          onChanged: model.searchFor,
          onFocus: model.beginSearch,
          onCancel: model.cancelSearch,
        ),
      if (model.searching && model.categories.length > 1) ...[
        const SizedBox(height: 4),
        CampusCategoryFilters(
          categories: model.categories,
          selected: model.queryCategory,
          onSelected: model.category,
        ),
      ],
      if (model.data!.fixture)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'DEMO · Synthetic London network',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                backgroundColor: Theme.of(context).colorScheme.surface,
              ),
            ),
          ),
        ),
      if (model.mapAttached && model.mapLoading && model.mapError == null)
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: LinearProgressIndicator(
            minHeight: 2,
            semanticsLabel: 'Loading map',
          ),
        ),
    ],
  );
}
