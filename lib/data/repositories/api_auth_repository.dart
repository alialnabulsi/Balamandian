import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/auth_failure.dart';
import '../../domain/models/auth_session.dart';
import '../../domain/models/pending_registration.dart';
import '../services/auth_api_service.dart';
import '../services/session_credential_store.dart';
import 'auth_repository.dart';

class ApiAuthRepository extends AuthRepository {
  ApiAuthRepository({
    required this._api,
    required this._credentials,
    this.credentialTimeout = const Duration(seconds: 10),
  });

  final AuthApiService _api;
  final SessionCredentialStore _credentials;
  final Duration credentialTimeout;
  IssuedSession? _session;
  AuthUser? _user;
  SessionStatus _status = SessionStatus.initializing;
  String? _error, _notice;
  Future<void>? _restoring, _signingOut, _deleting;
  bool _initialized = false, _mustDelete = false, _disposed = false;
  int _generation = 0;

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _trace(String stage) {
    if (kDebugMode) debugPrint('[session] $stage');
  }

  @override
  SessionStatus get status => _status;
  @override
  AuthUser? get user => _user;
  @override
  String? get sessionError => _error;
  @override
  String? get sessionNotice => _notice;

  void _publish(SessionStatus status, {String? error}) {
    _status = status;
    _error = error;
    _trace('state: ${status.name}');
    if (!_disposed) notifyListeners();
  }

  @override
  Future<void> restoreSession() {
    if (_disposed) return Future.value();
    if (_restoring != null) return _restoring!;
    if (_initialized) return Future.value();
    final generation = ++_generation;
    return _restoring = _restore(generation)
        .whenComplete(() => _restoring = null);
  }

  @override
  Future<void> retrySession() {
    if (_restoring != null) return _restoring!;
    if (_status != SessionStatus.validationError) return Future.value();
    _initialized = false;
    return restoreSession();
  }

  Future<void> _restore(int generation) async {
    _publish(SessionStatus.initializing);
    try {
      if (_mustDelete) {
        await _clearLocal();
        return;
      }
      IssuedSession? saved;
      try {
        _trace('secure read started');
        saved = await _credentials.read().timeout(credentialTimeout);
      } on FormatException {
        if (!_isCurrent(generation)) return;
        await _invalidate();
        return;
      } catch (_) {
        if (!_isCurrent(generation)) return;
        _publish(
          SessionStatus.validationError,
          error: 'Your saved session could not be read securely. Retry or sign out on this device.',
        );
        return;
      }
      if (!_isCurrent(generation)) return;
      _session = saved;
      final session = saved;
      _trace(session == null ? 'no saved token' : 'saved token present');
      if (session == null) {
        _publish(SessionStatus.unauthenticated);
        return;
      }
      // The server owns session validity, including for locally expired metadata.
      _trace('validation started');
      final result = await _api.me(session.token);
      if (!_isCurrent(generation)) return;
      _trace('validation completed');
      _session = IssuedSession(
        token: session.token,
        expiresAt: result.expiresAt,
      );
      _user = result.user;
      _publish(SessionStatus.authenticated);
    } on AuthFailure catch (error) {
      if (!_isCurrent(generation)) return;
      _trace('validation failed');
      if (error.invalidSession) {
        await _invalidate();
      } else {
        _publish(SessionStatus.validationError, error: error.message);
      }
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publish(
        SessionStatus.validationError,
        error: 'Your session could not be validated. Please try again.',
      );
    } finally {
      if (_isCurrent(generation)) _initialized = true;
    }
  }

  @override
  Future<PendingRegistration> register(String identifier, String password) =>
      _api.register(identifier, password);

  @override
  Future<PendingRegistration> resend(String pendingRegistrationId) =>
      _api.resend(pendingRegistrationId);

  @override
  Future<AuthUser> verify(String pendingRegistrationId, String otp) async =>
      _save(await _api.verify(pendingRegistrationId, otp));

  @override
  Future<AuthUser> login(String identifier, String password) async =>
      _save(await _api.login(identifier, password));

  Future<AuthUser> _save(AuthSession result) async {
    try {
      await _credentials.save(result.session);
    } catch (_) {
      throw const AuthFailure(
        'SESSION_STORAGE_FAILED',
        'Your session could not be saved securely. Please log in again.',
      );
    }
    _generation++;
    _initialized = true;
    _session = result.session;
    _user = result.user;
    _notice = null;
    _publish(SessionStatus.authenticated);
    return result.user;
  }

  /// Future protected API operations share invalid-session handling here.
  /// Public SIS login failures never enter this boundary.
  @override
  Future<T> withSession<T>(Future<T> Function(String token) request) async {
    final session = _session;
    final generation = _generation;
    if (_status != SessionStatus.authenticated || session == null) {
      throw const AuthFailure(
        'UNAUTHENTICATED',
        'Please log in again.',
        statusCode: 401,
      );
    }
    try {
      final result = await request(session.token);
      if (generation != _generation || _status != SessionStatus.authenticated) {
        throw const AuthFailure(
          'SESSION_CHANGED',
          'Your session changed. Please try again.',
        );
      }
      return result;
    } on AuthFailure catch (error) {
      if (error.invalidSession && generation == _generation) {
        await _invalidate();
      }
      rethrow;
    }
  }

  Future<void> _invalidate() async {
    _notice = AuthFailure.messages['UNAUTHENTICATED'];
    await _clearLocal();
  }

  Future<void> _clearLocal() async {
    // Hide identity and block protected navigation even if deletion fails.
    final generation = ++_generation;
    _initialized = true;
    _session = null;
    _user = null;
    _mustDelete = true;
    _publish(SessionStatus.signingOut);
    try {
      // Retain the actual mutation after a timeout. Retry waits for the same
      // deletion instead of starting a competing delete that could finish
      // after a subsequent login writes its token.
      final deleting = _deleting ??= _credentials.delete().whenComplete(
        () => _deleting = null,
      );
      await deleting.timeout(credentialTimeout);
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publish(
        SessionStatus.validationError,
        error: 'Your session could not be removed securely from this device. Retry to finish signing out.',
      );
      return;
    }
    if (!_isCurrent(generation)) return;
    _mustDelete = false;
    _publish(SessionStatus.unauthenticated);
  }

  @override
  Future<void> logout({bool localOnly = false}) {
    if (_signingOut != null) return _signingOut!;
    return _signingOut = _logout(localOnly: localOnly)
        .whenComplete(() => _signingOut = null);
  }

  Future<void> _logout({required bool localOnly}) async {
    // Signing out supersedes startup; it must not await an obsolete read or
    // validation response before removing this device's credentials.
    _generation++;
    _initialized = true;
    final previous = _status;
    _publish(SessionStatus.signingOut);
    if (!localOnly && !_mustDelete && _session != null) {
      try {
        await _api.logout(_session!.token);
      } on AuthFailure catch (error) {
        if (!error.invalidSession) {
          _publish(
            previous,
            error:
                'Server sign-out could not be confirmed. ${error.message} You can retry or sign out on this device only.',
          );
          return;
        }
      } catch (_) {
        _publish(
          previous,
          error: 'Server sign-out could not be confirmed. Retry or sign out on this device only.',
        );
        return;
      }
    }
    _notice = localOnly
        ? 'Your saved session has been removed. Please log in again.'
        : 'You have been logged out.';
    await _clearLocal();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
