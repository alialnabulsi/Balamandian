import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/community_repository.dart';
import '../../../domain/models/community.dart';

class CommunityInboxModel extends ChangeNotifier {
  CommunityInboxModel(this.repository);
  final CommunityRepository repository;
  List<CommunityActivity> items = const [];
  int unread = 0;
  String? _revision, _visibility, next;
  bool loading = false, loadingMore = false, _active = false, _disposed = false;
  Object? error;
  Timer? _retry;
  int _generation = 0;
  int _failures = 0;

  void active(bool value, {bool clear = false}) {
    if (_active == value && !clear) return;
    _active = value;
    if (clear) {
      items = const [];
      unread = 0;
      _revision = _visibility = next = null;
      error = null;
    }
    _generation++;
    _retry?.cancel();
    loading = false;
    loadingMore = false;
    _publish();
    if (value) unawaited(refresh());
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    _retry?.cancel();
    loading = true;
    loadingMore = false;
    error = null;
    _publish();
    try {
      final result = await repository.inbox();
      if (!_current(generation)) return;
      _set(result);
      _failures = 0;
    } catch (e) {
      if (_current(generation)) {
        error = e;
        _failures++;
      }
    } finally {
      if (_current(generation)) {
        loading = false;
        _publish();
        _schedule(generation);
      }
    }
  }

  void _set(CommunityInbox result) {
    final changed = _visibility != null && result.visibility != _visibility;
    _visibility = result.visibility;
    items = result.page.items;
    next = result.page.next;
    unread = result.unread;
    _revision = result.revision;
    error = null;
    if (changed) repository.invalidate();
  }

  void _schedule(int generation) {
    if (!_active || !_current(generation)) return;
    final duration = Duration(
      milliseconds: _failures == 0 ? 350 : 1000 * (1 << _failures.clamp(0, 4)),
    );
    _retry = Timer(duration, () => unawaited(_poll(generation)));
  }

  Future<void> _poll(int generation) async {
    if (!_active || !_current(generation)) return;
    try {
      final result = await repository.inbox(revision: _revision);
      if (!_current(generation)) return;
      if (result.revision != _revision) _set(result);
      error = null;
      _failures = 0;
      _publish();
    } catch (e) {
      if (_current(generation)) {
        error = e;
        _failures++;
        _publish();
      }
    } finally {
      _schedule(generation);
    }
  }

  Future<void> more() async {
    final cursor = next;
    if (cursor == null || loadingMore || loading) return;
    final generation = _generation;
    final revision = _revision;
    loadingMore = true;
    _publish();
    try {
      final result = await repository.inbox(cursor: cursor);
      if (!_current(generation) || revision != _revision) return;
      items = List.unmodifiable(
        {
          for (final item in [...items, ...result.page.items]) item.id: item,
        }.values,
      );
      next = result.page.next;
    } catch (e) {
      if (_current(generation)) error = e;
    } finally {
      if (_current(generation)) {
        loadingMore = false;
        _publish();
      }
    }
  }

  Future<void> mark(String? id) async {
    await repository.mutate(
      id == null ? 'notifications/read-all' : 'notifications/$id/read',
    );
    await refresh();
  }

  bool _current(int generation) => !_disposed && _generation == generation;
  void _publish() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    super.dispose();
  }
}
