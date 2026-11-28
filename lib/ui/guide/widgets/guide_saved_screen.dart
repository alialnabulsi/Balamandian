import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/guide_ai_links.dart';
import '../../core/themes/app_tokens.dart';
import '../../core/ui/feedback/content_state.dart';
import '../view_models/guide_session.dart';
import '../view_models/guide_browse_view_models.dart';
import 'guide_frame.dart';
import 'guide_loading.dart';
import 'guide_article_tile.dart';
import 'guide_pagination_footer.dart';

class GuideSavedScreen extends StatefulWidget {
  const GuideSavedScreen({super.key, required this.session});
  final GuideSession session;
  @override
  State<GuideSavedScreen> createState() => _GuideSavedScreenState();
}

class _GuideSavedScreenState extends State<GuideSavedScreen> {
  late final _model = GuideSavedViewModel(widget.session);
  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _model,
    builder: (context, _) => GuideFrame(
      title: 'Saved articles',
      showLocale: false,
      session: widget.session,
      onRefresh: () => _model.load(refresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTokens.gutter),
        children: [
          Text(
            'Your reading list',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Saved articles in English and Arabic. Unavailable articles are hidden.',
          ),
          const SizedBox(height: 24),
          if (_model.loading && _model.items.isEmpty)
            const GuideLoading()
          else if (_model.loaded &&
              _model.items.isEmpty &&
              _model.error == null)
            const ContentState(
              title: 'Nothing saved yet',
              message: 'Save an article to find it here later.',
              icon: Icons.bookmarks_outlined,
            ),
          for (final a in _model.items)
            GuideArticleTile(
              article: a,
              bookmarks: widget.session.bookmarks,
              onOpen: () => context.push(guideArticleLocation(a.id)),
            ),
          if (!(_model.loading && _model.items.isEmpty))
            GuidePaginationFooter(model: _model),
        ],
      ),
    ),
  );
}
