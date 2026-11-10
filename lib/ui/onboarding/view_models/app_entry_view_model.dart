import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/onboarding_repository.dart';
import '../../../domain/models/auth_session.dart';
import '../../../routing/startup_destination.dart';

/// Coordinates entry readiness; the splash owns its animation and the auth
/// repository remains the only owner of credentials and account identity.
class AppEntryViewModel extends ChangeNotifier {
  AppEntryViewModel({
    required this._auth,
    required this._onboarding,
    this.initialLocation = '/welcome/splash',
    this.firstDestination = StartupDestination.campus,
  }) {
    _auth.addListener(_sessionChanged);
  }

  final AuthRepository _auth;
  final OnboardingRepository _onboarding;
  final String initialLocation;
  final StartupDestination firstDestination;
  Future<void>? _initialization;
  bool _dataReady = false, _animationFinished = false, _disposed = false;
  bool _startupCompleted = false, _backgrounded = false, _reentering = false;
  int _reentryId = 0;
  String? _error, _onboardingError;

  bool get startupReady => _dataReady && _animationFinished;
  bool get startupCompleted => _startupCompleted;
  bool get reentering => _reentering;
  int get reentryId => _reentryId;
  String? get error => _error;
  String? get onboardingError => _onboardingError;

  String? get destination {
    if (!startupReady) return null;
    if (_error != null || _auth.status == SessionStatus.validationError) {
      return '/session';
    }
    if (_auth.status == SessionStatus.authenticated) {
      return !initialLocation.startsWith('/welcome/') &&
              initialLocation != '/session'
          ? initialLocation
          : '/';
    }
    if (_auth.sessionNotice != null) return StartupDestination.signIn.path;
    if (initialLocation != StartupDestination.splash.path) {
      return initialLocation;
    }
    return _onboarding.completed
        ? StartupDestination.gettingStarted.path
        : firstDestination.path;
  }

  Future<void> initialize() => _initialization ??= _resolve();

  Future<void> _resolve() async {
    _error = null;
    try {
      await Future.wait([_auth.restoreSession(), _onboarding.load()]);
      // Existing installed accounts predate this metadata. A restored or
      // expired issued session proves this is already a returning user.
      if (_auth.user != null || _auth.sessionNotice != null) {
        await _onboarding.markCompleted();
      }
    } catch (_) {
      _error = 'Your app preferences could not be loaded. Please retry.';
    }
    _dataReady = true;
    _trace('startup destination resolved');
    _notify();
  }

  Future<void> retryPreferences() async {
    await _resolve();
  }

  void animationCompleted() {
    if (_animationFinished) return;
    _animationFinished = true;
    _trace('startup animation completed');
    _notify();
  }

  void completeStartup() {
    if (!startupReady || _startupCompleted) return;
    _startupCompleted = true;
    _trace('startup destination opened');
    _notify();
  }

  Future<bool> completeOnboarding() async {
    _onboardingError = null;
    try {
      await _onboarding.markCompleted();
      _notify();
      return true;
    } catch (_) {
      _onboardingError =
          'Your progress could not be saved. Tap Get started to retry.';
      _notify();
      return false;
    }
  }

  void _sessionChanged() {
    if (_startupCompleted &&
        (_auth.user != null || _auth.sessionNotice != null) &&
        !_onboarding.completed) {
      unawaited(_rememberReturningAccount());
    }
    _notify();
  }

  Future<void> _rememberReturningAccount() async {
    try {
      await _onboarding.markCompleted();
    } catch (_) {
      _error = 'Your app preferences could not be saved. Please retry.';
      _notify();
    }
  }

  void backgrounded() {
    if (_startupCompleted && !_reentering) _backgrounded = true;
  }

  void resumed() {
    if (!_backgrounded) return;
    _backgrounded = false;
    if (!_startupCompleted || _reentering) return;
    _reentering = true;
    _reentryId++;
    _trace('foreground splash started');
    _notify();
  }

  void completeReentry() {
    if (!_reentering) return;
    _reentering = false;
    _trace('foreground splash completed');
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _trace(String stage) {
    if (kDebugMode) debugPrint('[entry] $stage');
  }

  @override
  void dispose() {
    _disposed = true;
    _auth.removeListener(_sessionChanged);
    super.dispose();
  }
}
