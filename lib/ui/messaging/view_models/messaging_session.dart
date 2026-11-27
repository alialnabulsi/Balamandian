import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/messaging_repository.dart';
import '../../../domain/models/messaging.dart';

class MessagingSession extends ChangeNotifier {
  MessagingSession(this.repository);
  final MessagingRepository repository;
  String? _user, _thread;
  bool _active = false, _disposed = false;
  int _generation = 0;
  bool reconnecting = false;
  int unread = 0;
  ChatSync? snapshot;
  Timer? _retry;
  Completer<void>? _cancel;

  String? get focusedThread => _thread;

  void activate(String? user, bool visible) {
    final active = visible && user != null;
    if (_user == user && _active == active) return;
    if (_active && !active && _user == user) {
      unawaited(
        repository
            .object('presence', method: 'PUT', data: {'visible': false})
            .then<void>((_) {}, onError: (Object _) {}),
      );
    }
    if (_user != user) {
      _thread = null;
      unread = 0;
      snapshot = null;
      reconnecting = false;
    }
    _user = user;
    _active = active;
    _restart();
    notifyListeners();
  }

  void focus(String? thread, {String? whenClosing}) {
    if (_disposed ||
        _thread == thread ||
        (whenClosing != null && _thread != whenClosing)) {
      return;
    }
    _thread = thread;
    snapshot = null;
    _restart();
  }

  void _restart() {
    final generation = ++_generation;
    _retry?.cancel();
    _cancel?.complete();
    _cancel = null;
    if (_active) unawaited(_poll(generation, null, 0));
  }

  Future<void> _poll(int generation, String? revision, int attempts) async {
    if (!_current(generation)) return;
    final cancel = Completer<void>();
    _cancel = cancel;
    try {
      final result = await repository.sync(revision, _thread, cancel.future);
      if (!_current(generation)) return;
      final changed =
          snapshot?.revision != result.revision ||
          unread != result.count ||
          reconnecting;
      snapshot = result;
      unread = result.count;
      reconnecting = false;
      if (changed) notifyListeners();
      _retry = Timer(
        const Duration(milliseconds: 350),
        () => unawaited(_poll(generation, result.revision, 0)),
      );
    } catch (_) {
      if (!_current(generation)) return;
      reconnecting = true;
      notifyListeners();
      _retry = Timer(
        Duration(seconds: 1 << attempts.clamp(0, 4)),
        () => unawaited(_poll(generation, revision, attempts + 1)),
      );
    }
  }

  bool _current(int generation) =>
      !_disposed && _active && generation == _generation;

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _cancel?.complete();
    super.dispose();
  }
}
