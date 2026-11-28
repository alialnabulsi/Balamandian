import 'package:flutter/material.dart';

import '../../core/ui/feedback/content_state.dart';
import '../view_models/guide_browse_view_models.dart';

class GuidePaginationFooter extends StatelessWidget {
  const GuidePaginationFooter({super.key, required this.model});
  final GuidePagedViewModel model;
  @override
  Widget build(BuildContext context) {
    if (model.loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Loading more articles',
          ),
        ),
      );
    }
    if (model.error case final String message) {
      return ContentState(
        compact: true,
        title: model.cursorExpired
            ? 'Reload this list'
            : model.unavailable
            ? 'Section unavailable'
            : 'Unable to load articles',
        message: message,
        onRetry: () =>
            model.load(refresh: model.cursorExpired || !model.loaded),
      );
    }
    if (model.nextCursor != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: OutlinedButton.icon(
          onPressed: model.load,
          icon: const Icon(Icons.expand_more_rounded),
          label: const Text('Load more articles'),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
