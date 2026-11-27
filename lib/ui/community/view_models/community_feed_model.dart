import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/community_repository.dart';
import '../../../domain/models/community.dart';

class CommunityFeedModel extends ChangeNotifier {
  CommunityFeedModel(
    this.repository, {
    this.path = 'feed',
    this.query = const {},
    this.hasStories = false,
  }) {
    repository.addListener(_invalidate);
  }
  final CommunityRepository repository;
  final String path;
  final Map<String, String> query;
  final bool hasStories;
  List<CommunityEntry> items = const [], stories = const [];
  String? next;
  String mode = 'for-you';
  Object? error, storiesError;
  bool loading = true, loadingMore = false;
  bool _disposed = false;
  Timer? _storyExpiry;
  int _generation = 0;
  int _storyGeneration = 0;
  final Set<String> _pending = {};
  final Set<String> _reportedViews = {};
  bool busy(String id, String action) => _pending.contains('$id:$action');

  void _invalidate() => unawaited(refresh(clear: true));
  Future<void> select(String value) async {
    if (mode == value) return;
    mode = value;
    await refresh(clear: true, refreshStories: false);
  }

  Future<void> refresh({bool clear = false, bool refreshStories = true}) async {
    final generation = ++_generation;
    if (clear) {
      items = const [];
      next = null;
      if (refreshStories) {
        stories = const [];
        _storyExpiry?.cancel();
      }
    }
    loading = true;
    loadingMore = false;
    error = null;
    _publish();
    await Future.wait([
      _load(generation, null),
      if (hasStories && refreshStories) _stories(++_storyGeneration),
    ]);
  }

  Future<void> _stories(int generation) async {
    try {
      final result = await repository.stories();
      if (_disposed || generation != _storyGeneration) return;
      stories = result;
      storiesError = null;
      _scheduleExpiry();
    } catch (e) {
      if (_disposed || generation != _storyGeneration) return;
      storiesError = e;
      stories = const [];
      _storyExpiry?.cancel();
    }
    _publish();
  }

  void _scheduleExpiry() {
    _storyExpiry?.cancel();
    final now = DateTime.now();
    stories = List.unmodifiable(
      stories.where((v) => v.expiresAt?.isAfter(now) == true),
    );
    final dates = stories.map((v) => v.expiresAt!).toList()..sort();
    if (dates.isEmpty) return;
    _storyExpiry = Timer(
      dates.first.difference(now) + const Duration(milliseconds: 100),
      () {
        _scheduleExpiry();
        _publish();
      },
    );
  }

  Future<void> more() async {
    if (loading || loadingMore || next == null) return;
    loadingMore = true;
    error = null;
    _publish();
    await _load(_generation, next);
  }

  Future<void> _load(int generation, String? cursor) async {
    try {
      var page = await repository.entries(
        path,
        cursor: cursor,
        query: {...query, if (path == 'feed') 'mode': mode},
      );
      // A ranked page can lose every item to current visibility rules.
      for (
        var attempts = 0;
        page.items.isEmpty && page.next != null && attempts < 3;
        attempts++
      ) {
        if (!_current(generation)) return;
        page = await repository.entries(
          path,
          cursor: page.next,
          query: {...query, if (path == 'feed') 'mode': mode},
        );
      }
      if (!_current(generation)) return;
      items = List.unmodifiable(
        {
          if (cursor != null)
            for (final item in items) item.id: item,
          for (final item in page.items) item.id: item,
        }.values,
      );
      next = page.next;
    } catch (e) {
      if (!_current(generation)) return;
      error = e;
      if (cursor == null) {
        items = const [];
        next = null;
      }
    } finally {
      if (_current(generation)) {
        loading = loadingMore = false;
        _publish();
      }
    }
  }

  void _replace(CommunityEntry updated) {
    items = List.unmodifiable(
      items.map((item) => item.id == updated.id ? updated : item),
    );
    stories = List.unmodifiable(
      stories.map((item) => item.id == updated.id ? updated : item),
    );
    _publish();
  }

  Future<void> toggle(CommunityEntry item, String action) async {
    final key = '${item.id}:$action';
    if (!_pending.add(key)) return;
    final generation = _generation;
    final on = action == 'like' ? !item.liked : !item.saved;
    _replace(
      action == 'like'
          ? item.withInteraction(liked: on)
          : item.withInteraction(saved: on),
    );
    try {
      await repository.mutate(
        'entries/${item.id}/$action',
        method: on ? 'PUT' : 'DELETE',
      );
      if (_current(generation) && path == 'saved' && action == 'save' && !on) {
        items = List.unmodifiable(items.where((v) => v.id != item.id));
      }
    } catch (e) {
      if (_current(generation)) {
        final current = [
          ...items,
          ...stories,
        ].where((value) => value.id == item.id).firstOrNull;
        if (current != null) {
          _replace(
            action == 'like'
                ? current.withInteraction(liked: item.liked)
                : current.withInteraction(saved: item.saved),
          );
        }
        if (e is CommunityFailure && e.unavailable) repository.invalidate();
      }
      rethrow;
    } finally {
      _pending.remove(key);
      _publish();
    }
  }

  Future<void> seen(CommunityEntry item) async {
    if (item.seen || item.isOwn || !_reportedViews.add(item.id)) return;
    try {
      await repository.mutate('entries/${item.id}/seen');
    } catch (_) {
      _reportedViews.remove(item.id);
    }
  }

  bool _current(int generation) => !_disposed && generation == _generation;
  void _publish() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _storyExpiry?.cancel();
    repository.removeListener(_invalidate);
    super.dispose();
  }
}
