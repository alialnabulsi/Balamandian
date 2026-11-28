import '../../domain/models/guide_models.dart';

abstract class GuideRepository {
  Future<List<GuideSection>> sections(GuideLocale locale);
  Future<GuideSectionDetail> section(
    String id,
    GuideLocale locale, {
    String? cursor,
  });
  Future<GuideArticle> article(String id);
  Future<GuidePage> search(String q, GuideLocale locale, {String? cursor});
  Future<GuidePage> bookmarks({String? cursor});
  Future<void> save(String id);
  Future<void> remove(String id);
  void cancelPending();
}
