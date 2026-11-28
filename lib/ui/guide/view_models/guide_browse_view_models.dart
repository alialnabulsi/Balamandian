import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../domain/models/guide_models.dart';
import 'guide_session.dart';

abstract class GuideViewModel extends ChangeNotifier {
  GuideViewModel(this.session) {
    session.addListener(sessionChanged);
  }
  final GuideSession session;
  bool alive = true;
  int request = 0;
  String? error;
  bool loading = false;
  void sessionChanged();
  bool current(int version, int epoch) =>
      alive && request == version && session.epoch == epoch && session.active;
  String message(Object error) => error is GuideFailure
      ? error.message
      : 'Unable to load the University Guide. Please retry.';
  @override
  void dispose() {
    alive = false;
    request++;
    session.removeListener(sessionChanged);
    super.dispose();
  }
}

class GuideHomeViewModel extends GuideViewModel {
  GuideHomeViewModel(super.session) {
    unawaited(load());
  }
  List<GuideSection> sections = const [];
  @override
  void sessionChanged() {
    sections = const [];
    unawaited(load());
  }

  Future<void> load() async {
    final version = ++request, epoch = session.epoch;
    sections = const [];
    error = null;
    loading = session.active;
    notifyListeners();
    if (!session.active) return;
    try {
      final data = await session.repository.sections(session.locale);
      if (current(version, epoch)) sections = data;
    } catch (e) {
      if (current(version, epoch)) error = message(e);
    } finally {
      if (current(version, epoch)) {
        loading = false;
        notifyListeners();
      }
    }
  }
}

class GuideListResult {
  const GuideListResult(this.page, [this.section]);
  final GuidePage page;
  final GuideSectionDetail? section;
}

abstract class GuidePagedViewModel extends GuideViewModel {
  GuidePagedViewModel(super.session);
  List<GuideArticleSummary> items = const [];
  String? nextCursor;
  bool loaded = false, cursorExpired = false;
  bool unavailable = false;
  final _seenCursors = <String>{};
  Future<GuideListResult> fetch(String? cursor);
  void received(GuideListResult result) {}
  void clear() {}
  @override
  void sessionChanged() {
    unawaited(load(refresh: true));
  }

  Future<void> load({bool refresh = false}) async {
    if (!refresh && (loading || (loaded && nextCursor == null))) return;
    final version = ++request, epoch = session.epoch;
    final after = refresh ? null : nextCursor;
    if (refresh) {
      items = const [];
      nextCursor = null;
      loaded = false;
      _seenCursors.clear();
      clear();
    }
    error = null;
    unavailable = false;
    cursorExpired = false;
    loading = session.active;
    notifyListeners();
    if (!session.active) return;
    try {
      final result = await fetch(after);
      if (!current(version, epoch)) return;
      final next = result.page.nextCursor;
      if (next != null && (!_seenCursors.add(next) || next == after)) {
        throw GuideFailure.invalidResponse;
      }
      items = List.unmodifiable(
        <String, GuideArticleSummary>{
          for (final a in items) a.id: a,
          for (final a in result.page.items) a.id: a,
        }.values,
      );
      nextCursor = next;
      loaded = true;
      received(result);
    } catch (e) {
      if (current(version, epoch)) {
        unavailable = e is GuideFailure && e.unavailable;
        cursorExpired =
            after != null && e is GuideFailure && e.code == 'INVALID_REQUEST';
        error = cursorExpired
            ? 'This list changed or the server restarted. Reload from the beginning.'
            : message(e);
        if (cursorExpired) nextCursor = null;
      }
    } finally {
      if (current(version, epoch)) {
        loading = false;
        notifyListeners();
      }
    }
  }
}

class GuideSectionViewModel extends GuidePagedViewModel {
  GuideSectionViewModel(super.session, this.id) {
    unawaited(load());
  }
  final String id;
  GuideSectionDetail? detail;
  @override
  void clear() {
    detail = null;
  }

  @override
  Future<GuideListResult> fetch(String? cursor) async {
    final result = await session.repository.section(
      id,
      session.locale,
      cursor: cursor,
    );
    return GuideListResult(result.articles, result);
  }

  @override
  void received(GuideListResult result) {
    detail = result.section;
  }
}

class GuideSearchViewModel extends GuidePagedViewModel {
  GuideSearchViewModel(super.session) {
    _epoch = session.epoch;
  }
  int _epoch = 0;
  String query = '';
  Timer? _debounce;
  void setQuery(String text) {
    _debounce?.cancel();
    request++;
    query = text.trim();
    items = const [];
    nextCursor = null;
    loaded = false;
    error = null;
    loading = false;
    if (query.runes.length > 500 ||
        RegExp(r'[\x00-\x1F\x7F]').hasMatch(query)) {
      error =
          'Use a search of at most 500 characters without control characters.';
    } else if (query.isNotEmpty) {
      _debounce = Timer(const Duration(milliseconds: 350), () {
        if (alive) unawaited(load(refresh: true));
      });
    }
    notifyListeners();
  }

  @override
  void sessionChanged() {
    final changedAccount = _epoch != session.epoch;
    _epoch = session.epoch;
    setQuery(changedAccount ? '' : query);
  }

  @override
  Future<GuideListResult> fetch(String? cursor) async => GuideListResult(
    await session.repository.search(query, session.locale, cursor: cursor),
  );
  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

class GuideSavedViewModel extends GuidePagedViewModel {
  GuideSavedViewModel(super.session) {
    _changes = session.bookmarks.changes;
    session.bookmarks.addListener(_bookmarksChanged);
    unawaited(load());
  }
  int _changes = 0;
  void _bookmarksChanged() {
    if (_changes != session.bookmarks.changes) {
      _changes = session.bookmarks.changes;
      unawaited(load(refresh: true));
    }
  }

  @override
  Future<GuideListResult> fetch(String? cursor) async {
    final serial = session.bookmarks.mutationSerial;
    final page = await session.repository.bookmarks(cursor: cursor);
    // Membership is observed only after the inherited request/session guard.
    return _GuideSavedResult(page, serial);
  }

  @override
  void received(GuideListResult result) {
    session.bookmarks.observe(
      result.page.items,
      (result as _GuideSavedResult).serial,
    );
  }

  @override
  void dispose() {
    session.bookmarks.removeListener(_bookmarksChanged);
    super.dispose();
  }
}

class _GuideSavedResult extends GuideListResult {
  const _GuideSavedResult(super.page, this.serial);
  final int serial;
}
