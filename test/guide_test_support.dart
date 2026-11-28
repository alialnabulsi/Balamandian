import 'package:balamandian/data/repositories/guide_repository.dart';
import 'package:balamandian/domain/models/guide_models.dart';

const guideRootId = '1321750c-7367-4515-89b5-55a9f701691f';
const guideChildId = '4b38031e-18bc-4008-bca6-868d22a23d84';
const guideArticleId = '688cc525-e178-49e7-8bdb-826d272a62ab';

Map<String, Object?> guideSummaryJson({
  String id = guideArticleId,
  String locale = 'en',
  String title = 'Academic calendar',
}) => {
  'articleId': id,
  'version': 1,
  'title': title,
  'slug': 'calendar',
  'sectionId': guideRootId,
  'summary': 'Find official academic dates.',
  'locale': locale,
  'tags': ['calendar'],
  'verifiedOn': '2026-11-27',
};
Map<String, Object?> guideArticleJson({
  String locale = 'en',
  String title = 'Academic calendar',
}) => {
  ...guideSummaryJson(locale: locale, title: title),
  'markdown': '## Registration\n\nRead **carefully**, then:\n\n1. Consult the calendar.\n2. Ask your advisor.\n\n[Official calendar](https://www.balamand.edu.lb/calendar)\n\n<script>alert(1)</script>\n',
  'sources': [
    {
      'key': 'calendar',
      'url': 'https://www.balamand.edu.lb/calendar',
      'label': 'Official calendar',
      'locator': null,
    },
  ],
  'academicYear': null,
  'validFrom': null,
  'validUntil': null,
};
Map<String, Object?> guideSectionJson({bool child = false}) => {
  'sectionId': child ? guideChildId : guideRootId,
  'slug': child ? 'library-services' : 'library',
  'label': child ? 'Library Services' : 'Library',
  'hasChildren': !child,
};
GuideArticleSummary guideSummary({String id = guideArticleId}) =>
    GuideArticleSummary.fromJson(guideSummaryJson(id: id));
GuideSectionDetail guideSectionDetail({bool child = false, GuidePage? page}) =>
    GuideSectionDetail(
      section: GuideSection.fromJson(guideSectionJson(child: child)),
      breadcrumb: [
        GuideSection.fromJson(guideSectionJson()),
        if (child) GuideSection.fromJson(guideSectionJson(child: true)),
      ],
      subsections: [
        if (!child) GuideSection.fromJson(guideSectionJson(child: true)),
      ],
      articles: page ?? GuidePage(items: child ? [guideSummary()] : const []),
    );

class FakeGuideRepository implements GuideRepository {
  int rootCalls = 0,
      articleCalls = 0,
      canceled = 0,
      saveCalls = 0,
      removeCalls = 0;
  final searchCalls = <(String, GuideLocale, String?)>[];
  final bookmarkCalls = <String?>[];
  final sectionCalls = <(String, GuideLocale, String?)>[];
  Future<List<GuideSection>> Function(GuideLocale)? onSections;
  Future<GuideSectionDetail> Function(String, GuideLocale, String?)? onSection;
  Future<GuideArticle> Function(String)? onArticle;
  Future<GuidePage> Function(String, GuideLocale, String?)? onSearch;
  Future<GuidePage> Function(String?)? onBookmarks;
  Future<void> Function(String)? onSave, onRemove;
  @override
  Future<List<GuideSection>> sections(GuideLocale locale) async {
    rootCalls++;
    return onSections != null
        ? onSections!(locale)
        : [GuideSection.fromJson(guideSectionJson())];
  }

  @override
  Future<GuideSectionDetail> section(
    String id,
    GuideLocale locale, {
    String? cursor,
  }) async {
    sectionCalls.add((id, locale, cursor));
    return onSection != null
        ? onSection!(id, locale, cursor)
        : guideSectionDetail(child: id == guideChildId);
  }

  @override
  Future<GuideArticle> article(String id) async {
    articleCalls++;
    return onArticle != null
        ? onArticle!(id)
        : GuideArticle.fromJson(guideArticleJson());
  }

  @override
  Future<GuidePage> search(
    String q,
    GuideLocale locale, {
    String? cursor,
  }) async {
    searchCalls.add((q, locale, cursor));
    return onSearch != null
        ? onSearch!(q, locale, cursor)
        : GuidePage(items: [guideSummary()]);
  }

  @override
  Future<GuidePage> bookmarks({String? cursor}) async {
    bookmarkCalls.add(cursor);
    return onBookmarks != null
        ? onBookmarks!(cursor)
        : const GuidePage(items: []);
  }

  @override
  Future<void> save(String id) async {
    saveCalls++;
    await onSave?.call(id);
  }

  @override
  Future<void> remove(String id) async {
    removeCalls++;
    await onRemove?.call(id);
  }

  @override
  void cancelPending() {
    canceled++;
  }
}
