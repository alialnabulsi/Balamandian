import 'package:flutter/foundation.dart';

import '../../../data/repositories/community_repository.dart';
import '../../../domain/models/community.dart';

class CommunityCommentsModel extends ChangeNotifier {
  CommunityCommentsModel(this.repository, this.post);
  final CommunityRepository repository;
  final CommunityEntry post;
  List<CommunityComment> items = const [];
  CommunityComment? parent;
  String? next;
  Object? error;
  bool loading = false, sending = false, _disposed = false;
  bool? _currentCanWrite;
  bool get canWrite => _currentCanWrite ?? (post.canComment && !post.archived);
  int _generation = 0;
  String? _sendId, _sendText;
  final _likes = <String, bool>{};
  final _pending = <String>{};
  bool liked(CommunityComment comment) => _likes[comment.id] ?? comment.liked;
  bool pending(CommunityComment comment) => _pending.contains(comment.id);

  Future<void> thread(CommunityComment? root) async {
    parent = root;
    items = const [];
    next = null;
    _sendId = _sendText = null;
    await load(reset: true);
  }

  Future<void> revalidate() async {
    final generation = ++_generation;
    items = const [];
    next = null;
    parent = null;
    loading = true;
    _currentCanWrite = false;
    _publish();
    try {
      final current = await repository.entry(post.id);
      if (!_current(generation)) return;
      _currentCanWrite = current.canComment && !current.archived;
      await load(reset: true);
    } catch (e) {
      if (_current(generation)) {
        error = e;
        loading = false;
        _publish();
      }
    }
  }

  Future<void> load({bool reset = false}) async {
    if (!reset && loading) return;
    final generation = ++_generation;
    final cursor = reset ? null : next;
    loading = true;
    error = null;
    _publish();
    try {
      final page = await repository.page(
        'entries/${post.id}/comments',
        CommunityComment.fromJson,
        cursor: cursor,
        query: {if (parent != null) 'parent': parent!.id},
      );
      if (!_current(generation)) return;
      items = List.unmodifiable(
        {
          if (!reset)
            for (final item in items) item.id: item,
          for (final item in page.items) item.id: item,
        }.values,
      );
      next = page.next;
    } catch (e) {
      if (_current(generation)) {
        error = e;
        if (e is CommunityFailure && e.unavailable) items = const [];
      }
    } finally {
      if (_current(generation)) {
        loading = false;
        _publish();
      }
    }
  }

  Future<bool> send(String raw) async {
    final value = raw.trim();
    if (value.isEmpty || sending) return false;
    if (value.runes.length > 1000) {
      error = const CommunityFailure(
        'Comments can contain up to 1,000 characters.',
      );
      _publish();
      return false;
    }
    if (_sendText != value) {
      _sendId = CommunityRepository.newId();
      _sendText = value;
    }
    sending = true;
    error = null;
    _publish();
    try {
      await repository.mutate(
        'entries/${post.id}/comments/$_sendId',
        data: {'text': value, 'parentId': parent?.id},
      );
      _sendId = _sendText = null;
      await load(reset: true);
      return true;
    } catch (e) {
      error = e;
      return false;
    } finally {
      sending = false;
      _publish();
    }
  }

  Future<void> toggle(CommunityComment comment) async {
    if (!_pending.add(comment.id)) return;
    final was = liked(comment);
    _likes[comment.id] = !was;
    error = null;
    _publish();
    try {
      await repository.mutate(
        'entries/${post.id}/comments/${comment.id}/like',
        method: was ? 'DELETE' : 'PUT',
      );
    } catch (e) {
      _likes[comment.id] = was;
      error = e;
    } finally {
      _pending.remove(comment.id);
      _publish();
    }
  }

  Future<void> remove(CommunityComment comment) async {
    try {
      await repository.mutate(
        'entries/${post.id}/comments/${comment.id}',
        method: 'DELETE',
      );
      await load(reset: true);
    } catch (e) {
      error = e;
      _publish();
    }
  }

  bool _current(int generation) => !_disposed && _generation == generation;
  void _publish() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
