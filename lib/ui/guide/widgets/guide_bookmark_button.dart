import 'package:flutter/material.dart';

import '../view_models/guide_bookmarks.dart';
import '../../core/ui/buttons/async_action_button.dart';

class GuideBookmarkButton extends StatelessWidget {
  const GuideBookmarkButton({
    super.key,
    required this.articleId,
    required this.bookmarks,
    this.compact = false,
  });
  final String articleId;
  final GuideBookmarks bookmarks;
  final bool compact;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: bookmarks,
    builder: (context, _) {
      final state = bookmarks.status(articleId);
      final saved = state == GuideBookmarkStatus.saved;
      final unknown = state == GuideBookmarkStatus.unknown;
      final busy =
          bookmarks.pending(articleId) || state == GuideBookmarkStatus.loading;
      final label = busy
          ? 'Updating saved status'
          : unknown
          ? 'Check saved status'
          : saved
          ? 'Remove saved article'
          : 'Save article';
      final icon = busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              unknown
                  ? Icons.help_outline_rounded
                  : saved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
            );
      void activate() {
        if (unknown) {
          bookmarks.check(articleId);
        } else {
          bookmarks.setSaved(articleId, !saved);
        }
      }

      if (compact) {
        return IconButton(
          tooltip: bookmarks.error(articleId) ?? label,
          onPressed: busy ? null : activate,
          icon: icon,
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AsyncActionButton(
            onPressed: busy ? null : activate,
            outlined: true,
            running: busy,
            label: label,
          ),
          if (unknown && !busy)
            TextButton(
              onPressed: () => bookmarks.setSaved(articleId, true),
              child: const Text('Save this article'),
            ),
          if (unknown)
            const Text(
              'Saved status is not yet confirmed. You can continue checking or save this article.',
            ),
          if (bookmarks.error(articleId) case final String error)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      );
    },
  );
}
