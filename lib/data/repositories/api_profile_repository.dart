import 'dart:typed_data';

import '../../domain/models/auth_failure.dart';
import '../../domain/models/profile_models.dart';
import '../services/profile_api_service.dart';
import 'profile_repository.dart';

typedef AuthenticatedProfileRequest = Future<T> Function<T>(
  Future<T> Function(String token) request,
);

class ApiProfileRepository extends ProfileRepository {
  ApiProfileRepository({required this._api, required this._withSession});
  final ProfileApiService _api;
  final AuthenticatedProfileRequest _withSession;
  final _profiles = <String, UserProfile>{};
  final _avatars = <String, Uint8List>{};
  String? _userId, _error;
  Object? _sessionIdentity;
  UserProfile? _own;
  Future<UserProfile>? _pending;
  int _generation = 0;
  bool _disposed = false;
  @override
  UserProfile? get currentUser => _own;
  @override
  String? get currentUserId => _userId;
  @override
  String? get error => _error;
  @override
  bool get loading => _pending != null;
  void _publish() {
    if (!_disposed) notifyListeners();
  }

  @override
  void bindSession(String? userId, Object? sessionIdentity) {
    if (_userId == userId && identical(_sessionIdentity, sessionIdentity)) {
      return;
    }
    _generation++;
    _userId = userId;
    _sessionIdentity = sessionIdentity;
    _own = null;
    _pending = null;
    _error = null;
    _profiles.clear();
    _avatars.clear();
    _publish();
  }

  Future<T> _run<T>(Future<T> Function(String) operation) async {
    final generation = _generation;
    try {
      final result = await _withSession(operation);
      if (_disposed || generation != _generation) {
        throw ProfileFailure.fromCode('SESSION_CHANGED');
      }
      return result;
    } on AuthFailure {
      rethrow;
    } on ProfileFailure {
      rethrow;
    } catch (_) {
      throw ProfileFailure.fromCode(null);
    }
  }

  UserProfile _store(UserProfile value, {bool own = false}) {
    if (_profiles.length >= 100) _profiles.clear();
    _profiles[value.identity.id] = value;
    if (own) _own = value;
    _publish();
    return value;
  }

  @override
  UserProfile? cached(String id) => id == _userId ? _own : _profiles[id];
  @override
  Future<UserProfile> loadOwn({bool refresh = false}) {
    if (_pending != null) return _pending!;
    if (!refresh && _own != null) return Future.value(_own);
    final generation = _generation;
    final pending = _run(_api.own)
        .then((v) {
          _error = null;
          return _store(v, own: true);
        })
        .catchError((Object e) {
          if (generation == _generation) {
            _error = e is ProfileFailure
                ? e.message
                : 'Your profile could not be loaded. Please retry.';
          }
          throw e;
        })
        .whenComplete(() {
          if (generation == _generation) {
            _pending = null;
            _publish();
          }
        });
    _pending = pending;
    _publish();
    return pending;
  }

  @override
  Future<UserProfile> profile(String id, {bool refresh = false}) async {
    if (id == _userId) return loadOwn(refresh: refresh);
    if (!refresh && _profiles[id] != null) return _profiles[id]!;
    return _store(await _run((token) => _api.profile(token, id)));
  }

  @override
  Future<UserProfile> saveBiography(String value) async =>
      _store(await _run((t) => _api.biography(t, value)), own: true);
  @override
  Future<UserProfile> uploadAvatar(Uint8List bytes) async {
    final result = await _run((t) => _api.upload(t, bytes));
    _avatars.clear();
    return _store(result, own: true);
  }

  @override
  Future<UserProfile> removeAvatar() async {
    final result = await _run(_api.removeAvatar);
    _avatars.clear();
    return _store(result, own: true);
  }

  @override
  Future<UserProfile> follow(String id, bool value) async {
    final result = await _run((t) => _api.follow(t, id, value));
    _store(result);
    // Refresh the current user's authoritative following count, without turning a confirmed follow into a failure.
    try {
      await loadOwn(refresh: true);
    } on Object {
      /* The next profile refresh recovers counts. */
    }
    return result;
  }

  @override
  Future<MemberPage> members({
    required MemberListKind kind,
    String? userId,
    String search = '',
    int page = 1,
  }) => _run(
    (t) =>
        _api.members(t, kind: kind, userId: userId, search: search, page: page),
  );
  @override
  Future<Uint8List> avatar(String path) async {
    if (_avatars[path] != null) return _avatars[path]!;
    final bytes = await _run((t) => _api.avatar(t, path));
    if (_avatars.length >= 100) _avatars.clear();
    _avatars[path] = bytes;
    return bytes;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _profiles.clear();
    _avatars.clear();
    super.dispose();
  }
}
