import 'package:flutter/material.dart';

import '../../../domain/models/guide_models.dart';
import '../../core/themes/app_tokens.dart';
import '../view_models/guide_bookmarks.dart';
import 'guide_bookmark_button.dart';

class GuideArticleTile extends StatelessWidget {
  const GuideArticleTile({
    super.key,
    required this.article,
    required this.onOpen,
    required this.bookmarks,
  });
  final GuideArticleSummary article;
  final VoidCallback onOpen;
  final GuideBookmarks bookmarks;
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: article.locale == GuideLocale.ar
        ? TextDirection.rtl
        : TextDirection.ltr,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTokens.controlRadius),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.all(16),
              onTap: onOpen,
              title: Text(
                article.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(article.summary),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
            if (article.excerpt case final String excerpt)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  excerpt,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 16,
                end: 4,
                bottom: 4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${article.locale == GuideLocale.ar ? 'العربية' : 'English'} · Verified ${article.verifiedOn}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  GuideBookmarkButton(
                    articleId: article.id,
                    bookmarks: bookmarks,
                    compact: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
