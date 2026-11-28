import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/guide_ai_links.dart';
import '../../../domain/models/guide_models.dart';
import '../../core/themes/app_tokens.dart';
import '../../core/ui/feedback/content_state.dart';
import '../view_models/guide_session.dart';
import '../view_models/guide_browse_view_models.dart';
import 'guide_frame.dart';
import 'guide_loading.dart';
import 'guide_section_tile.dart';
import 'guide_article_tile.dart';
import 'guide_breadcrumbs.dart';
import 'guide_pagination_footer.dart';

class GuideSectionScreen extends StatefulWidget {
  const GuideSectionScreen({
    super.key,
    required this.session,
    required this.sectionId,
  });
  final GuideSession session;
  final String sectionId;
  @override
  State<GuideSectionScreen> createState() => _GuideSectionScreenState();
}

class _GuideSectionScreenState extends State<GuideSectionScreen> {
  late final _model = GuideSectionViewModel(widget.session, widget.sectionId);
  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _model,
    builder: (context, _) {
      final detail = _model.detail;
      return GuideFrame(
        title: detail?.section.label ?? 'Section',
        session: widget.session,
        onRefresh: () => _model.load(refresh: true),
        child: Directionality(
          textDirection: widget.session.locale == GuideLocale.ar
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppTokens.gutter),
            children: [
              if (_model.loading && detail == null) const GuideLoading(),
              if (detail != null) ...[
                GuideBreadcrumbs(
                  sections: detail.breadcrumb,
                  onOpen: (id) => context.push(guideSectionLocation(id)),
                ),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(
                    detail.section.label,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: 24),
                for (final child in detail.subsections)
                  GuideSectionTile(
                    section: child,
                    onOpen: () => context.push(guideSectionLocation(child.id)),
                  ),
                if (detail.subsections.isNotEmpty && _model.items.isNotEmpty)
                  const SizedBox(height: 16),
                for (final a in _model.items)
                  GuideArticleTile(
                    article: a,
                    bookmarks: widget.session.bookmarks,
                    onOpen: () => context.push(guideArticleLocation(a.id)),
                  ),
                if (detail.subsections.isEmpty &&
                    _model.items.isEmpty &&
                    _model.error == null &&
                    !_model.loading)
                  const ContentState(
                    title: 'No articles yet',
                    message: 'This section has no published articles in the selected language.',
                    icon: Icons.menu_book_rounded,
                  ),
              ],
              if (!_model.loading || detail != null)
                GuidePaginationFooter(model: _model),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    },
  );
}
