import '../../domain/models/guide_models.dart';
import '../services/guide_api_service.dart';
import 'guide_repository.dart';

typedef GuideSessionRequest = Future<T> Function<T>(
  Future<T> Function(String token) request,
);

class ApiGuideRepository implements GuideRepository {
  ApiGuideRepository({required this.api, required this.withSession});
  final GuideApiService api;
  final GuideSessionRequest withSession;
  int _generation = 0;
  Future<T> _run<T>(Future<T> Function(String) request) async {
    final generation = _generation;
    final result = await withSession(request);
    if (generation != _generation) throw GuideFailure.canceled;
    return result;
  }

  @override
  Future<List<GuideSection>> sections(GuideLocale locale) =>
      _run((t) => api.sections(t, locale));
  @override
  Future<GuideSectionDetail> section(
    String id,
    GuideLocale locale, {
    String? cursor,
  }) => _run((t) => api.section(t, id, locale, cursor));
  @override
  Future<GuideArticle> article(String id) => _run((t) => api.article(t, id));
  @override
  Future<GuidePage> search(String q, GuideLocale locale, {String? cursor}) =>
      _run((t) => api.search(t, q, locale, cursor));
  @override
  Future<GuidePage> bookmarks({String? cursor}) =>
      _run((t) => api.bookmarks(t, cursor));
  @override
  Future<void> save(String id) => _run((t) => api.save(t, id));
  @override
  Future<void> remove(String id) => _run((t) => api.remove(t, id));
  @override
  void cancelPending() {
    _generation++;
    api.cancelPending();
  }
}
