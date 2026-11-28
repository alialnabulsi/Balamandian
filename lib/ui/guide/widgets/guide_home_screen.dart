import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/guide_ai_links.dart';
import '../../../data/services/external_url_service.dart';
import '../../../domain/models/guide_models.dart';
import '../../core/themes/app_tokens.dart';
import '../../core/ui/feedback/content_state.dart';
import '../view_models/guide_session.dart';
import '../view_models/guide_browse_view_models.dart';
import 'guide_frame.dart';
import 'guide_loading.dart';
import 'guide_section_tile.dart';
import 'guide_search_screen.dart';
import 'guide_saved_screen.dart';

class GuideHomeScreen extends StatefulWidget {
  const GuideHomeScreen({
    super.key,
    required this.session,
    required this.externalUrls,
  });
  final GuideSession session;
  final ExternalUrlService externalUrls;
  @override
  State<GuideHomeScreen> createState() => _GuideHomeScreenState();
}

class _GuideHomeScreenState extends State<GuideHomeScreen> {
  late final _model = GuideHomeViewModel(widget.session);
  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _model,
    builder: (context, _) => GuideFrame(
      title: 'Guide',
      session: widget.session,
      onRefresh: _model.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTokens.gutter),
        children: [
          Semantics(
            header: true,
            child: Text(
              'University Guide',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Official university information, in one place.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GuideSearchScreen(session: widget.session),
              ),
            ),
            icon: const Icon(Icons.search_rounded),
            label: const Text('Search the Guide'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GuideSavedScreen(session: widget.session),
              ),
            ),
            icon: const Icon(Icons.bookmarks_outlined),
            label: const Text('Saved articles'),
          ),
          const SizedBox(height: 24),
          if (_model.loading)
            const GuideLoading()
          else if (_model.error case final String message)
            ContentState(
              title: 'Guide unavailable',
              message: message,
              icon: Icons.menu_book_rounded,
              onRetry: _model.load,
            )
          else if (_model.sections.isEmpty)
            ContentState(
              title: 'No sections yet',
              message:
                  'University Guide sections will appear here when available.',
              icon: Icons.menu_book_rounded,
              onRetry: _model.load,
            )
          else
            Directionality(
              textDirection: widget.session.locale == GuideLocale.ar
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: Column(
                children: [
                  for (final s in _model.sections)
                    GuideSectionTile(
                      section: s,
                      onOpen: () => context.push(guideSectionLocation(s.id)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}
