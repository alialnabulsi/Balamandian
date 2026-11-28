import 'package:go_router/go_router.dart';

import '../../data/services/external_url_service.dart';
import '../../routing/guide_ai_links.dart';
import 'view_models/guide_session.dart';
import 'widgets/guide_home_screen.dart';
import 'widgets/guide_section_screen.dart';
import 'widgets/guide_article_screen.dart';

GoRoute createGuideRoute({
  required GuideSession session,
  required ExternalUrlService externalUrls,
  bool aiAvailable = false,
}) => GoRoute(
  path: 'guide',
  builder: (_, state) => GuideHomeScreen(
    key: state.pageKey,
    session: session,
    externalUrls: externalUrls,
  ),
  routes: [
    GoRoute(
      path: 'sections/:sectionId',
      builder: (_, state) => GuideSectionScreen(
        key: state.pageKey,
        session: session,
        sectionId: state.pathParameters['sectionId']!,
      ),
    ),
    GoRoute(
      path: 'articles/:articleId',
      builder: (context, state) => GuideArticleScreen(
        key: state.pageKey,
        session: session,
        articleId: state.pathParameters['articleId']!,
        citedVersion: int.tryParse(state.uri.queryParameters['rev'] ?? ''),
        externalUrls: externalUrls,
        onAskAi: aiAvailable
            ? (articleId) => context.push(aiLocation(articleId: articleId))
            : null,
      ),
    ),
  ],
);
