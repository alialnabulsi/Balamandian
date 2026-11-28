import 'package:flutter/material.dart';

import '../../../data/services/external_url_service.dart';
import '../../../domain/models/guide_models.dart';
import '../../core/themes/app_tokens.dart';
import '../../core/ui/feedback/content_state.dart';
import '../view_models/guide_session.dart';
import '../view_models/guide_article_view_model.dart';
import 'guide_frame.dart';
import 'guide_loading.dart';
import 'guide_article_metadata.dart';
import 'guide_bookmark_button.dart';
import 'guide_sources.dart';
import 'guide_markdown_body.dart';

class GuideArticleScreen extends StatefulWidget {
  const GuideArticleScreen({
    super.key,
    required this.session,
    required this.articleId,
    required this.externalUrls,
    this.citedVersion,
    this.onAskAi,
  });
  final GuideSession session;
  final String articleId;
  final int? citedVersion;
  final ExternalUrlService externalUrls;
  final ValueChanged<String>? onAskAi;
  @override
  State<GuideArticleScreen> createState() => _GuideArticleScreenState();
}

class _GuideArticleScreenState extends State<GuideArticleScreen> {
  late final _model = GuideArticleViewModel(
    widget.session,
    widget.articleId,
    citedVersion: widget.citedVersion,
    externalUrls: widget.externalUrls,
  );
  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _model,
    builder: (context, _) {
      final article = _model.article;
      return GuideFrame(
        title: 'Article',
        showLocale: false,
        session: widget.session,
        onRefresh: _model.load,
        child: Directionality(
          textDirection: article?.summary.locale == GuideLocale.ar
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppTokens.gutter),
            children: [
              if (_model.loading)
                const GuideLoading()
              else if (_model.error case final String message)
                ContentState(
                  title: _model.unavailable
                      ? 'Article unavailable'
                      : 'Unable to load article',
                  message: message,
                  icon: Icons.menu_book_rounded,
                  onRetry: _model.load,
                )
              else if (article != null) ...[
                GuideArticleMetadata(article: article),
                if (_model.revisionChanged)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        'This article has been updated since the cited revision. You are reading version ${article.summary.version}.',
                        textDirection: TextDirection.ltr,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                GuideBookmarkButton(
                  articleId: article.summary.id,
                  bookmarks: widget.session.bookmarks,
                ),
                if (widget.onAskAi case final onAskAi?)
                  OutlinedButton.icon(
                    onPressed: () => onAskAi(article.summary.id),
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Ask AI'),
                  ),
                const SizedBox(height: 24),
                GuideMarkdownBody(
                  markdown: article.markdown,
                  onLink: _model.openLink,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Divider(),
                ),
                GuideSources(sources: article.sources, onOpen: _model.openLink),
                if (_model.linkError case final String error)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      );
    },
  );
}
