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
  final _profileRequests = <String, Future<UserProfile>>{};
  final _avatarRequests = <String, Future<Uint8List>>{};
  final _memberRequests =
      <(MemberListKind, String?, String, int), Future<MemberPage>>{};
  final _revisions = <String, int>{};
  int _pendingRevision = 0;
  String? _userId, _error;
  Object? _sessionIdentity;
  UserProfile? _own;
  Future<UserProfile>? _pending;
  int _generation = 0;
  int _publicGeneration = 0;
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
    _profileRequests.clear();
    _avatarRequests.clear();
    _memberRequests.clear();
    _revisions.clear();
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

  UserProfile _store(
    UserProfile value, {
    bool own = false,
    bool mutation = false,
  }) {
    if (mutation) {
      _revisions[value.identity.id] = (_revisions[value.identity.id] ?? 0) + 1;
    }
    if (_profiles.length >= 100) _profiles.clear();
    _profiles[value.identity.id] = value;
    if (own) _own = value;
    _publish();
    return value;
  }

  @override
  UserProfile? cached(String id) => id == _userId ? _own : _profiles[id];

  @override
  void invalidatePublic() {
    _publicGeneration++;
    _profiles.clear();
    _avatars.clear();
    _profileRequests.clear();
    _avatarRequests.clear();
    _memberRequests.clear();
  }

  @override
  Future<UserProfile> loadOwn({bool refresh = false}) {
    if (_pending != null) {
      if (refresh && _pendingRevision != (_revisions[_userId] ?? 0)) {
        return _pending!.then(
          (_) => loadOwn(refresh: true),
          onError: (Object _) => loadOwn(refresh: true),
        );
      }
      return _pending!;
    }
    if (!refresh && _own != null) return Future.value(_own);
    final generation = _generation;
    final revision = _pendingRevision = _revisions[_userId] ?? 0;
    final pending = _run(_api.own)
        .then((v) {
          if (revision != (_revisions[_userId] ?? 0)) return _own ?? v;
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
    if (_profileRequests[id] case final pending?) return pending;
    final generation = _generation;
    final policy = _publicGeneration;
    final revision = _revisions[id] ?? 0;
    final pending = _run((token) => _api.profile(token, id))
        .then((value) {
          if (policy != _publicGeneration) {
            throw ProfileFailure.fromCode('SESSION_CHANGED');
          }
          return revision == (_revisions[id] ?? 0)
              ? _store(value)
              : cached(id) ?? value;
        })
        .whenComplete(() {
          if (generation == _generation && policy == _publicGeneration) {
            _profileRequests.remove(id);
          }
        });
    _profileRequests[id] = pending;
    return pending;
  }

  @override
  Future<UserProfile> saveBiography(String value) async => _store(
    await _run((t) => _api.biography(t, value)),
    own: true,
    mutation: true,
  );
  @override
  Future<UserProfile> uploadAvatar(Uint8List bytes) async {
    final result = await _run((t) => _api.upload(t, bytes));
    _avatars.clear();
    return _store(result, own: true, mutation: true);
  }

  @override
  Future<UserProfile> removeAvatar() async {
    final result = await _run(_api.removeAvatar);
    _avatars.clear();
    return _store(result, own: true, mutation: true);
  }

  @override
  Future<UserProfile> follow(String id, bool value) async {
    final result = await _run((t) => _api.follow(t, id, value));
    _store(result, mutation: true);
    if (_userId case final ownerId?) {
      _revisions[ownerId] = (_revisions[ownerId] ?? 0) + 1;
    }
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
  }) {
    final key = (kind, userId, search, page);
    if (_memberRequests[key] case final pending?) return pending;
    final generation = _generation;
    final policy = _publicGeneration;
    final pending =
        _run(
              (t) => _api.members(
                t,
                kind: kind,
                userId: userId,
                search: search,
                page: page,
              ),
            )
            .then((result) {
              if (policy != _publicGeneration) {
                throw ProfileFailure.fromCode('SESSION_CHANGED');
              }
              return result;
            })
            .whenComplete(() {
              if (generation == _generation && policy == _publicGeneration) {
                _memberRequests.remove(key);
              }
            });
    _memberRequests[key] = pending;
    return pending;
  }

  @override
  Future<Uint8List> avatar(String path) async {
    if (_avatars[path] != null) return _avatars[path]!;
    if (_avatarRequests[path] case final pending?) return pending;
    final generation = _generation;
    final policy = _publicGeneration;
    final pending = _run((t) => _api.avatar(t, path))
        .then((bytes) {
          if (policy != _publicGeneration) {
            throw ProfileFailure.fromCode('SESSION_CHANGED');
          }
          if (_avatars.length >= 100) _avatars.clear();
          _avatars[path] = bytes;
          return bytes;
        })
        .whenComplete(() {
          if (generation == _generation && policy == _publicGeneration) {
            _avatarRequests.remove(path);
          }
        });
    _avatarRequests[path] = pending;
    return pending;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _profiles.clear();
    _avatars.clear();
    _profileRequests.clear();
    _avatarRequests.clear();
    _memberRequests.clear();
    super.dispose();
  }
}
