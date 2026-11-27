import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/academic_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../domain/models/academic_profile.dart';
import '../../../domain/models/auth_failure.dart';
import '../../../domain/models/auth_session.dart';
import '../../../domain/models/profile_models.dart';

enum StudentAccess { guest, loading, profileError, ineligible, eligible }

class AcademicProfileViewModel extends ChangeNotifier {
  AcademicProfileViewModel({
    required this._auth,
    required this._profiles,
    required this._repository,
    this.autoLoad = false,
  }) {
    _auth.addListener(_sync);
    _profiles.addListener(_sync);
    _sync();
  }
  final AuthRepository _auth;
  final ProfileRepository _profiles;
  final AcademicRepository _repository;
  final bool autoLoad;
  Object? _identity;
  bool _disposed = false, loading = false;
  int epoch = 0, _request = 0;
  StudentAccess access = StudentAccess.loading;
  AcademicProfile? snapshot;
  String? error;

  StudentAccess _resolve() {
    if (_auth.status == SessionStatus.unauthenticated && _auth.user == null) {
      return StudentAccess.guest;
    }
    if (_auth.status != SessionStatus.authenticated) {
      return StudentAccess.loading;
    }
    final own = _profiles.currentUser;
    if (own == null ||
        own.identity.id != _auth.user?.id ||
        _profiles.currentUserId != _auth.user?.id) {
      return !_profiles.loading && _profiles.error != null
          ? StudentAccess.profileError
          : StudentAccess.loading;
    }
    return (own.account?.roles ?? own.identity.roles).contains('student')
        ? StudentAccess.eligible
        : StudentAccess.ineligible;
  }

  void _sync() {
    final next = _resolve();
    if (!identical(_identity, _auth.user) || access != next) {
      _identity = _auth.user;
      access = next;
      epoch++;
      invalidate();
      if (autoLoad && access == StudentAccess.eligible) scheduleMicrotask(load);
    }
    if (!_disposed) notifyListeners();
  }

  /// Cancel pending imports when a temporary scenario is reset or left.
  void invalidate() {
    _request++;
    loading = false;
    snapshot = null;
    error = null;
  }

  Future<void> retryProfile() async {
    if (_disposed || _auth.user == null || _profiles.loading) return;
    try {
      await _profiles.loadOwn(refresh: true);
    } catch (_) {
      /* Repository publishes. */
    }
  }

  Future<void> load({bool synchronize = false}) async {
    if (_disposed || access != StudentAccess.eligible || loading) return;
    final request = ++_request, generation = epoch;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final value = await (synchronize
          ? _repository.synchronize()
          : _repository.loadSaved());
      if (!_disposed && generation == epoch && request == _request) {
        snapshot = value;
      }
    } catch (failure) {
      if (!_disposed && generation == epoch && request == _request) {
        error = switch (failure) {
          ProfileFailure() => failure.message,
          AuthFailure() => failure.message,
          _ => 'Saved academic information could not be loaded. Please retry.',
        };
        if (failure is ProfileFailure &&
            failure.code == 'ACADEMICS_FORBIDDEN') {
          access = StudentAccess.ineligible;
          epoch++;
          snapshot = null;
        }
      }
    } finally {
      if (!_disposed && request == _request) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    _auth.removeListener(_sync);
    _profiles.removeListener(_sync);
    super.dispose();
  }
}
