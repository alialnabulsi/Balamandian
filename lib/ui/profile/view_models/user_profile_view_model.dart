import 'package:flutter/foundation.dart';

import '../../../data/repositories/profile_repository.dart';
import '../../../domain/models/profile_models.dart';

class UserProfileViewModel extends ChangeNotifier {
  UserProfileViewModel({required this._repository, this.userId}) {
    _sessionUserId = _repository.currentUserId;
    _repository.addListener(_changed);
  }
  final ProfileRepository _repository;
  final String? userId;
  bool loading = false, following = false, _disposed = false;
  String? _error, _sessionUserId;
  String? get error =>
      _error ??
      (userId == null || userId == _repository.currentUserId
          ? _repository.error
          : null);
  UserProfile? _loaded;
  int _loadGeneration = 0;
  UserProfile? get profile => userId == null
      ? _repository.currentUser
      : _repository.cached(userId!) ?? _loaded;
  void _changed() {
    final id = _repository.currentUserId;
    if (id == null || id != _sessionUserId) {
      _loaded = null;
    } else if (userId != null) {
      _loaded = _repository.cached(userId!) ?? _loaded;
    }
    _sessionUserId = id;
    if (!_disposed) notifyListeners();
  }

  Future<Uint8List> avatar(String path) => _repository.avatar(path);
  Future<void> load({bool refresh = false, bool revalidate = false}) async {
    if ((loading && !revalidate) || _disposed) return;
    final generation = ++_loadGeneration;
    if (revalidate) _loaded = null;
    loading = true;
    _error = null;
    notifyListeners();
    try {
      if (userId == null) {
        await _repository.loadOwn(refresh: refresh);
      } else {
        final profile = await _repository.profile(userId!, refresh: refresh);
        if (generation == _loadGeneration) _loaded = profile;
      }
    } on ProfileFailure catch (e) {
      if (generation == _loadGeneration) _error = e.message;
    } catch (_) {
      if (generation == _loadGeneration) {
        _error = 'Your profile could not be loaded. Please retry.';
      }
    } finally {
      if (generation == _loadGeneration) {
        loading = false;
        _changed();
      }
    }
  }

  Future<void> toggleFollow() async {
    final value = profile;
    if (value == null || value.isSelf || following || _disposed) return;
    following = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.follow(
        value.identity.id,
        !value.isFollowing && !value.followRequested,
      );
    } on ProfileFailure catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not update following. Please retry.';
    } finally {
      following = false;
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _repository.removeListener(_changed);
    super.dispose();
  }
}
