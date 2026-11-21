import 'package:flutter/material.dart';

import '../../../domain/models/campus/campus_data.dart';
import '../../core/ui/feedback/content_state.dart';
import '../../core/ui/app_surface.dart';
import 'campus_destination_row.dart';

class CampusSearchResults extends StatelessWidget {
  const CampusSearchResults({
    super.key,
    required this.results,
    required this.onSelected,
    this.loading = false,
    this.error,
    this.onRetry,
  });
  final List<CampusDestination> results;
  final ValueChanged<CampusDestination> onSelected;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => AppSurface(
    padding: EdgeInsets.zero,
    child: loading
        ? const Padding(
            padding: EdgeInsets.all(24),
            child: LinearProgressIndicator(semanticsLabel: 'Loading places'),
          )
        : error != null
        ? SingleChildScrollView(
            child: ContentState(
              compact: true,
              title: 'Search unavailable',
              message: error!,
              onRetry: onRetry,
            ),
          )
        : results.isEmpty
        ? const SingleChildScrollView(
            child: ContentState(
              compact: true,
              title: 'No campus places found',
              message: 'Try another name, code, category or alias.',
              icon: Icons.search_off_rounded,
            ),
          )
        : ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: results.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => CampusDestinationRow(
              destination: results[i],
              onSelected: () => onSelected(results[i]),
            ),
          ),
  );
}
