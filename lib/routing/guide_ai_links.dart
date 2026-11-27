import '../domain/models/guide_article_ref.dart';

String guideSectionLocation(String sectionId) =>
    Uri(pathSegments: ['', 'guide', 'sections', sectionId]).toString();

String guideArticleLocation(String articleId, {int? citedVersion}) => Uri(
  pathSegments: ['', 'guide', 'articles', articleId],
  queryParameters: citedVersion == null ? null : {'rev': '$citedVersion'},
).toString();

String guideCitationLocation(GuideArticleRef article) =>
    guideArticleLocation(article.articleId, citedVersion: article.version);

String aiLocation({String? articleId}) => Uri(
  path: '/ai',
  queryParameters: articleId == null ? null : {'articleId': articleId},
).toString();

String aiConversationLocation(String conversationId) =>
    Uri(pathSegments: ['', 'ai', 'conversations', conversationId]).toString();
