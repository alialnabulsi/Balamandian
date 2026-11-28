import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/guide_ai_links.dart';
import '../../../domain/models/guide_models.dart';
import '../../core/themes/app_tokens.dart';
import '../../core/ui/feedback/content_state.dart';
import '../view_models/guide_session.dart';
import '../view_models/guide_browse_view_models.dart';
import 'guide_frame.dart';
import 'guide_search_input.dart';
import 'guide_loading.dart';
import 'guide_article_tile.dart';
import 'guide_pagination_footer.dart';

class GuideSearchScreen extends StatefulWidget {
  const GuideSearchScreen({super.key, required this.session});
  final GuideSession session;
  @override
  State<GuideSearchScreen> createState() => _GuideSearchScreenState();
}

class _GuideSearchScreenState extends State<GuideSearchScreen> {
  late final _model = GuideSearchViewModel(widget.session);
  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _model,
    builder: (context, _) => GuideFrame(
      title: 'Search the Guide',
      session: widget.session,
      child: ListView(
        padding: const EdgeInsets.all(AppTokens.gutter),
        children: [
          Directionality(
            textDirection: widget.session.locale == GuideLocale.ar
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: GuideSearchInput(
              key: ValueKey(widget.session.epoch),
              onChanged: _model.setQuery,
            ),
          ),
          const SizedBox(height: 24),
          if (_model.query.isEmpty)
            const ContentState(
              title: 'Find university information',
              message: 'Search articles in English or Arabic using the content language selector.',
              icon: Icons.search_rounded,
            )
          else if (_model.loading && _model.items.isEmpty)
            const GuideLoading()
          else if (_model.loaded &&
              _model.items.isEmpty &&
              _model.error == null)
            const ContentState(
              title: 'No articles found',
              message: 'Try different words or change the content language.',
              icon: Icons.search_off_rounded,
            ),
          for (final a in _model.items)
            GuideArticleTile(
              article: a,
              bookmarks: widget.session.bookmarks,
              onOpen: () => context.push(guideArticleLocation(a.id)),
            ),
          if (_model.query.isNotEmpty &&
              !(_model.loading && _model.items.isEmpty))
            GuidePaginationFooter(model: _model),
        ],
      ),
    ),
  );
}
