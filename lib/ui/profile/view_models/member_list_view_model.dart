import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/profile_repository.dart';
import '../../../domain/models/profile_models.dart';

class MemberListViewModel extends ChangeNotifier {
  MemberListViewModel({
    required this._repository,
    required this.kind,
    this.userId,
  });
  final ProfileRepository _repository;
  final MemberListKind kind;
  final String? userId;
  List<UserProfile> items = [];
  final pending = <String>{};
  String search = '', currentSearch = '';
  String? error;
  bool loading = false, hasMore = false, _disposed = false;
  int _page = 0, _generation = 0;
  Timer? _timer;
  Future<Uint8List> avatar(String path) => _repository.avatar(path);
  void _publish() {
    if (!_disposed) notifyListeners();
  }

  void searchChanged(String value) {
    search = value;
    _timer?.cancel();
    _generation++;
    loading = false;
    _timer = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(load(refresh: true)),
    );
  }

  Future<void> load({bool refresh = false}) async {
    if (_disposed || (loading && !refresh)) return;
    final generation = ++_generation;
    loading = true;
    error = null;
    if (refresh) {
      _page = 0;
      items = [];
      currentSearch = search.trim();
    }
    _publish();
    try {
      final result = await _repository.members(
        kind: kind,
        userId: userId,
        search: currentSearch,
        page: _page + 1,
      );
      if (_disposed || generation != _generation) return;
      final byId = {
        for (final item in items) item.identity.id: item,
        for (final item in result.items) item.identity.id: item,
      };
      items = List.unmodifiable(byId.values);
      _page = result.page;
      hasMore = result.hasMore;
    } on ProfileFailure catch (e) {
      if (generation == _generation) error = e.message;
    } catch (_) {
      if (generation == _generation) {
        error = 'Members could not be loaded. Please retry.';
      }
    } finally {
      if (generation == _generation) {
        loading = false;
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
      await _repository.follow(id, !member.isFollowing);
      if (!_disposed) await load(refresh: true);
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
    _generation++;
    _timer?.cancel();
    super.dispose();
  }
}
