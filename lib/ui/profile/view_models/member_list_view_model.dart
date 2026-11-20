import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/profile_repository.dart';
import '../../../domain/models/profile_models.dart';

class MemberListViewModel extends ChangeNotifier {
  MemberListViewModel({
    required this._repository,
    required this.kind,
    this.userId,
  }) {
    _sessionUserId = _repository.currentUserId;
    _repository.addListener(_sessionChanged);
  }
  final ProfileRepository _repository;
  final MemberListKind kind;
  final String? userId;
  List<UserProfile> items = [];
  final pending = <String>{};
  String search = '', currentSearch = '';
  String? error;
  bool loading = false, hasMore = false, _disposed = false;
  bool hasLoaded = false, searching = false, loadingMore = false;
  bool paginationFailed = false;
  int? total;
  int _page = 0, _generation = 0;
  Timer? _timer;
  String? _sessionUserId;
  void _sessionChanged() {
    final id = _repository.currentUserId;
    if (id != null && id == _sessionUserId) return;
    _sessionUserId = id;
    _generation++;
    _timer?.cancel();
    items = [];
    pending.clear();
    total = null;
    loading = searching = loadingMore = hasLoaded = false;
    _publish();
  }

  Future<Uint8List> avatar(String path) => _repository.avatar(path);
  void _publish() {
    if (!_disposed) notifyListeners();
  }

  void searchChanged(String value) {
    search = value;
    _timer?.cancel();
    _generation++;
    loading = false;
    searching = true;
    _publish();
    _timer = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(load(refresh: true)),
    );
  }

  Future<void> load({bool refresh = false}) async {
    if (_disposed || (loading && !refresh)) return;
    final generation = ++_generation;
    loading = true;
    loadingMore = !refresh && items.isNotEmpty;
    paginationFailed = false;
    error = null;
    final query = refresh ? search.trim() : currentSearch;
    if (refresh && query != currentSearch) {
      items = [];
      hasLoaded = false;
    }
    currentSearch = query;
    _publish();
    try {
      final result = await _repository.members(
        kind: kind,
        userId: userId,
        search: currentSearch,
        page: refresh ? 1 : _page + 1,
      );
      if (_disposed || generation != _generation) return;
      final byId = {
        if (!refresh)
          for (final item in items) item.identity.id: item,
        for (final item in result.items) item.identity.id: item,
      };
      items = List.unmodifiable(byId.values);
      _page = result.page;
      hasMore = result.hasMore;
      total = result.total;
      hasLoaded = true;
    } on ProfileFailure catch (e) {
      if (generation == _generation) {
        error = e.message;
        paginationFailed = loadingMore;
      }
    } catch (_) {
      if (generation == _generation) {
        error = 'Members could not be loaded. Please retry.';
        paginationFailed = loadingMore;
      }
    } finally {
      if (generation == _generation) {
        loading = false;
        searching = loadingMore = false;
        _publish();
      }
    }
  }

  Future<void> toggle(UserProfile member) async {
    final id = member.identity.id;
    if (member.isSelf || pending.contains(id) || _disposed) return;
    pending.add(id);
    error = null;
    _publish();
    try {
      final updated = await _repository.follow(id, !member.isFollowing);
      if (!_disposed &&
          _repository.currentUserId == _sessionUserId &&
          _sessionUserId != null) {
        items = List.unmodifiable(
          items.map((v) => v.identity.id == id ? updated : v),
        );
        // A list membership may have changed; keep the rows while revalidating.
        unawaited(load(refresh: true));
      }
    } on ProfileFailure catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Could not update following. Please retry.';
    } finally {
      pending.remove(id);
      _publish();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _repository.removeListener(_sessionChanged);
    _generation++;
    _timer?.cancel();
    super.dispose();
  }
}
