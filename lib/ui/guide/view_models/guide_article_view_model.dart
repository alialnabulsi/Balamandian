import 'dart:async';

import '../../../data/services/external_url_service.dart';
import '../../../domain/models/guide_models.dart';
import 'guide_browse_view_models.dart';

class GuideArticleViewModel extends GuideViewModel {
  GuideArticleViewModel(
    super.session,
    this.id, {
    this.citedVersion,
    required this.externalUrls,
  }) {
    unawaited(load());
  }
  final String id;
  final int? citedVersion;
  final ExternalUrlService externalUrls;
  GuideArticle? article;
  bool unavailable = false;
  String? linkError;
  bool get revisionChanged =>
      article != null &&
      citedVersion != null &&
      citedVersion != article!.summary.version;
  @override
  void sessionChanged() {
    unawaited(load());
  }

  Future<void> load() async {
    final version = ++request, epoch = session.epoch;
    article = null;
    error = null;
    unavailable = false;
    linkError = null;
    loading = session.active;
    notifyListeners();
    if (!session.active) return;
    try {
      final data = await session.repository.article(id);
      if (current(version, epoch)) {
        article = data;
        unawaited(session.bookmarks.check(id));
      }
    } catch (e) {
      if (current(version, epoch)) {
        unavailable = e is GuideFailure && e.unavailable;
        error = message(e);
      }
    } finally {
      if (current(version, epoch)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> openLink(String? text) async {
    final epoch = session.epoch;
    final uri = text == null ? null : Uri.tryParse(text);
    var opened = false;
    if (uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty) {
      try {
        opened = await externalUrls.launch(uri);
      } catch (_) {
        /* Safe inline feedback below. */
      }
    }
    if (alive && epoch == session.epoch && session.active) {
      linkError = opened ? null : 'This link could not be opened. Only secure web links are supported.';
      notifyListeners();
    }
  }
}
