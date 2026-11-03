import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../domain/models/auth_failure.dart';
import '../../../domain/models/pending_registration.dart';

class OtpViewModel extends ChangeNotifier {
  OtpViewModel({
    required this._repository,
    required PendingRegistration? registration,
    DateTime Function()? now,
  }) : _registration = registration,
       _now = now ?? DateTime.now {
    if (registration != null) {
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => notifyListeners(),
      );
    }
  }

  final AuthRepository _repository;
  final DateTime Function() _now;
  PendingRegistration? _registration;
  Timer? _timer;
  DateTime? _retryAt, _verifyRetryAt;
  bool _disposed = false, _invalidRegistration = false;
  bool _codeExpired = false, _codeLocked = false;
  bool verifying = false, resending = false, requiresLogin = false;
  String? formError, codeError, notice;

  bool get pending => verifying || resending;
  bool get requiresRestart => _registration == null || _invalidRegistration;
  bool get expired =>
      _codeExpired || !(_registration?.otpExpiresAt.isAfter(_now()) ?? false);
  bool get canVerify =>
      !pending &&
      !requiresRestart &&
      !requiresLogin &&
      !expired &&
      !_codeLocked &&
      _secondsUntil(_verifyRetryAt) == 0;
  bool get canResend =>
      !pending &&
      !requiresRestart &&
      !requiresLogin &&
      resendSeconds == 0 &&
      retrySeconds == 0;
  int get retrySeconds => _secondsUntil(_retryAt);
  int get resendSeconds => _secondsUntil(_registration?.resendAvailableAt);
  int get expirySeconds => _secondsUntil(_registration?.otpExpiresAt);

  int _secondsUntil(DateTime? value) {
    if (value == null) return 0;
    final milliseconds = value.difference(_now()).inMilliseconds;
    return milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
  }

  void editCode() {
    if (codeError == null) return;
    codeError = null;
    notifyListeners();
  }

  Future<bool> verify(String code) async {
    if (_disposed || !canVerify) return false;
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      codeError = 'Enter the six-digit code from your university email.';
      notifyListeners();
      return false;
    }
    verifying = true;
    formError = codeError = notice = null;
    notifyListeners();
    try {
      await _repository.verify(_registration!.id, code);
      return true;
    } on AuthFailure catch (error) {
      _handleFailure(error);
      return false;
    } catch (_) {
      formError = 'Something went wrong. Please try again.';
      return false;
    } finally {
      verifying = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> resend() async {
    if (_disposed || !canResend) return false;
    resending = true;
    formError = codeError = notice = null;
    notifyListeners();
    try {
      _registration = await _repository.resend(_registration!.id);
      _codeExpired = _codeLocked = false;
      notice = 'A new code was sent. Use the code from the latest email.';
      return true;
    } on AuthFailure catch (error) {
      _handleFailure(error);
      return false;
    } catch (_) {
      formError = 'Something went wrong. Please try again.';
      return false;
    } finally {
      resending = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _handleFailure(AuthFailure error) {
    if (error.code == 'OTP_INVALID') {
      codeError = error.message;
    } else {
      formError = error.message;
    }
    if (error.retryAfter case final delay?) {
      _retryAt = _now().add(delay);
      if (error.code == 'RATE_LIMITED') _verifyRetryAt = _retryAt;
    }
    switch (error.code) {
      case 'OTP_EXPIRED':
        _codeExpired = true;
      case 'OTP_ATTEMPT_LIMIT':
        _codeLocked = true;
      case 'OTP_UNAVAILABLE' || 'EMAIL_UNAVAILABLE':
        _codeLocked = true;
      case 'REGISTRATION_INVALID' || 'REGISTRATION_REPLACED':
        _invalidRegistration = true;
      case 'SESSION_STORAGE_FAILED':
        requiresLogin = true;
        formError = 'Your email is verified, but your session could not be saved securely. Log in to try again.';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
