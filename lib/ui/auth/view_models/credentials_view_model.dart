import 'package:flutter/foundation.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../domain/models/auth_failure.dart';
import '../../../domain/models/auth_session.dart';
import '../../../domain/models/pending_registration.dart';

class CredentialsViewModel extends ChangeNotifier {
  CredentialsViewModel({required this.signingUp, required this._repository});

  final AuthRepository _repository;
  final bool signingUp;
  String? identifierError, passwordError;
  String? formError;
  PendingRegistration? pendingRegistration;
  AuthUser? authenticatedUser;
  bool passwordVisible = false;
  bool pending = false, _disposed = false;
  DateTime? _retryAt;

  bool validate(String identifier, String password) {
    identifierError = identifier.trim().isEmpty
        ? 'Enter your ${signingUp ? 'SIS ID' : 'email or SIS ID'}.'
        : identifier.length > 254 ||
              RegExp(r'[\s\x00-\x1f\x7f-\x9f]').hasMatch(identifier.trim())
        ? 'Enter a valid SIS ID or email without spaces.'
        : null;
    passwordError = password.isEmpty
        ? 'Enter your password.'
        : password.length > 1024 || password.contains('\u0000')
        ? 'Enter a valid SIS password.'
        : null;
    notifyListeners();
    return identifierError == null && passwordError == null;
  }

  Future<bool> submit(String identifier, String password) async {
    if (pending || _disposed) return false;
    if (!validate(identifier, password)) return false;
    if (_retryAt?.isAfter(DateTime.now()) == true) return false;
    pending = true;
    formError = null;
    pendingRegistration = null;
    authenticatedUser = null;
    notifyListeners();
    try {
      if (signingUp) {
        pendingRegistration = await _repository.register(
          identifier.trim(),
          password,
        );
      } else {
        authenticatedUser = await _repository.login(
          identifier.trim(),
          password,
        );
      }
      return true;
    } on AuthFailure catch (error) {
      formError = error.message;
      if (error.retryAfter case final delay?) {
        _retryAt = DateTime.now().add(delay);
        formError = '${error.message} Try again in ${delay.inSeconds} seconds.';
      }
      return false;
    } catch (_) {
      formError = 'Something went wrong. Please try again.';
      return false;
    } finally {
      pending = false;
      if (!_disposed) notifyListeners();
    }
  }

  void editIdentifier() {
    if (identifierError != null) {
      identifierError = null;
      notifyListeners();
    }
  }

  void editPassword() {
    if (passwordError != null) {
      passwordError = null;
      notifyListeners();
    }
  }

  void toggleVisibility() {
    passwordVisible = !passwordVisible;
    notifyListeners();
  }

  void conceal() {
    passwordVisible = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
