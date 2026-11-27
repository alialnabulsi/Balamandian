import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../domain/models/auth_session.dart';
import '../../../domain/models/auth_failure.dart';
import '../../../domain/models/task_models.dart';

enum PlannerAccess { guest, loading, profileError, ineligible, eligible }

enum PlannerView { list, kanban }

class TaskPlannerViewModel extends ChangeNotifier {
  TaskPlannerViewModel({
    required this._auth,
    required this._profiles,
    required this._repository,
  }) {
    _auth.addListener(_sync);
    _profiles.addListener(_sync);
    _sync();
  }
  final AuthRepository _auth;
  final ProfileRepository _profiles;
  final TaskRepository _repository;
  Object? _identity;
  int _epoch = 0, _request = 0;
  bool _disposed = false, _loading = false, _busy = false, _loaded = false;
  String? _error, _pendingId;
  String _activity = 'Saving changes…';
  List<PlannerTask> _tasks = const [];
  PlannerAccess _access = PlannerAccess.loading;
  PlannerView _view = PlannerView.list;
  PlannerAccess get access => _access;
  PlannerView get view => _view;
  List<PlannerTask> get tasks => _tasks;
  int get epoch => _epoch;
  bool get loading => _loading;
  bool get busy => _busy;
  bool get canMutate =>
      _access == PlannerAccess.eligible && _loaded && !_busy && !_loading;
  String? get error => _error;
  String? get pendingId => _pendingId;
  String get activity => _activity;
  int get completed =>
      _tasks.where((task) => task.status == TaskStatus.done).length;
  double get progress => _tasks.isEmpty ? 0 : completed / _tasks.length;

  PlannerAccess _resolveAccess() {
    if (_auth.status == SessionStatus.unauthenticated && _auth.user == null) {
      return PlannerAccess.guest;
    }
    if (_auth.status != SessionStatus.authenticated) {
      return PlannerAccess.loading;
    }
    final profile = _profiles.currentUser;
    final id = _auth.user?.id;
    if (profile == null ||
        profile.identity.id != id ||
        _profiles.currentUserId != id) {
      return _profiles.loading
          ? PlannerAccess.loading
          : _profiles.error != null
          ? PlannerAccess.profileError
          : PlannerAccess.loading;
    }
    final roles = profile.account?.roles ?? profile.identity.roles;
    return roles.any((role) => role == 'student' || role == 'advisor')
        ? PlannerAccess.eligible
        : PlannerAccess.ineligible;
  }

  void _sync() {
    final next = _resolveAccess();
    if (!identical(_identity, _auth.user) || next != _access) {
      _identity = _auth.user;
      _epoch++;
      _request++;
      _tasks = const [];
      _busy = _loading = _loaded = false;
      _error = _pendingId = null;
      _view = PlannerView.list;
      _access = next;
      if (next == PlannerAccess.eligible) scheduleMicrotask(refresh);
    }
    _publish();
  }

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  bool _current(int epoch, int request) =>
      !_disposed &&
      epoch == _epoch &&
      request == _request &&
      _access == PlannerAccess.eligible;
  String _message(Object error) => switch (error) {
    TaskFailure() => error.message,
    AuthFailure() => error.message,
    _ => 'Your planner is unavailable. Please try again.',
  };
  void selectView(PlannerView view) {
    _view = view;
    _publish();
  }

  Future<void> retryProfile() async {
    if (_disposed || _auth.user == null || _profiles.loading) return;
    try {
      await _profiles.loadOwn(refresh: true);
    } catch (_) {
      /* Repository publishes profile errors. */
    }
  }

  Future<void> refresh() async {
    if (_disposed || _access != PlannerAccess.eligible || _busy || _loading) {
      return;
    }
    final epoch = _epoch, request = ++_request;
    _loading = true;
    _error = null;
    _publish();
    try {
      final result = await _repository.loadAll();
      if (_current(epoch, request)) {
        _tasks = List.unmodifiable(result);
        _loaded = true;
      }
    } catch (error) {
      if (_current(epoch, request)) {
        _error = _message(error);
        if (error is TaskFailure && error.code == 'TASKS_FORBIDDEN') {
          _tasks = const [];
          _loaded = false;
          _access = PlannerAccess.ineligible;
          _epoch++;
          _loading = false;
        }
      }
    } finally {
      if (!_disposed && epoch == _epoch && request == _request) {
        _loading = false;
        _publish();
      } else if (!_disposed) {
        _publish();
      }
    }
  }

  Future<bool> _mutate(
    String? id,
    Future<void> Function() operation, {
    bool deleting = false,
  }) async {
    if (!canMutate) return false;
    final epoch = _epoch, request = ++_request;
    _busy = true;
    _activity = deleting ? 'Deleting task…' : 'Saving changes…';
    _pendingId = id;
    _error = null;
    _publish();
    try {
      await operation();
      return _current(epoch, request);
    } catch (error) {
      if (_current(epoch, request)) {
        _error = _message(error);
        if (error is TaskFailure && error.code == 'TASKS_FORBIDDEN') {
          _tasks = const [];
          _loaded = false;
          _access = PlannerAccess.ineligible;
          _epoch++;
          _busy = false;
          _pendingId = null;
        }
      }
      return false;
    } finally {
      if (_current(epoch, request)) {
        _busy = false;
        _pendingId = null;
      }
      _publish();
    }
  }

  Future<bool> save(TaskDraft draft, {PlannerTask? original}) {
    final epoch = _epoch;
    return _mutate(original?.id, () async {
      final saved = original == null
          ? await _repository.create(draft)
          : await _repository.update(original.id, draft);
      if (!_disposed && epoch == _epoch && _access == PlannerAccess.eligible) {
        _tasks = List.unmodifiable(
          original == null
              ? [..._tasks, saved]
              : _tasks.map((task) => task.id == saved.id ? saved : task),
        );
      }
    });
  }

  Future<bool> changeStatus(PlannerTask task, TaskStatus status) {
    if (task.status == status || !_tasks.any((item) => identical(item, task))) {
      return Future.value(false);
    }
    final epoch = _epoch;
    return _mutate(task.id, () async {
      final saved = await _repository.changeStatus(task.id, status);
      if (!_disposed && epoch == _epoch) {
        _tasks = List.unmodifiable(
          _tasks.map((item) => item.id == saved.id ? saved : item),
        );
      }
    });
  }

  Future<bool> delete(PlannerTask task) {
    final epoch = _epoch;
    return _mutate(task.id, () async {
      await _repository.delete(task.id);
      if (!_disposed && epoch == _epoch) {
        _tasks = List.unmodifiable(_tasks.where((item) => item.id != task.id));
      }
    }, deleting: true);
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _tasks = const [];
    _auth.removeListener(_sync);
    _profiles.removeListener(_sync);
    super.dispose();
  }
}
