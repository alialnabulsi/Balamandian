import 'package:flutter/foundation.dart';

import '../../../data/repositories/profile_repository.dart';
import '../../../domain/models/profile_models.dart';

class UserProfileViewModel extends ChangeNotifier {
  UserProfileViewModel({required this._repository, this.userId}) {
    _repository.addListener(_changed);
  }
  final ProfileRepository _repository;
  final String? userId;
  bool loading = false, following = false, _disposed = false;
  String? error;
  UserProfile? _loaded;
  UserProfile? get profile => userId == null
      ? _repository.currentUser
      : _repository.cached(userId!) ?? _loaded;
  void _changed() {
    if (_repository.currentUserId == null) {
      _loaded = null;
    } else if (userId != null) {
      _loaded = _repository.cached(userId!) ?? _loaded;
    }
    if (!_disposed) notifyListeners();
  }

  Future<Uint8List> avatar(String path) => _repository.avatar(path);
  Future<void> load({bool refresh = false}) async {
    if (loading || _disposed) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (userId == null) {
        await _repository.loadOwn(refresh: refresh);
      } else {
        _loaded = await _repository.profile(userId!, refresh: refresh);
      }
    } on ProfileFailure catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Your profile could not be loaded. Please retry.';
    } finally {
      loading = false;
      _changed();
    }
  }

  Future<void> toggleFollow() async {
    final value = profile;
    if (value == null || value.isSelf || following || _disposed) return;
    following = true;
    error = null;
    notifyListeners();
    try {
      await _repository.follow(value.identity.id, !value.isFollowing);
    } on ProfileFailure catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Could not update following. Please retry.';
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
