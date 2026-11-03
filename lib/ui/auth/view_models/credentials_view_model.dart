import 'package:flutter/foundation.dart';

class CredentialsViewModel extends ChangeNotifier {
  CredentialsViewModel({required this.signingUp});
  final bool signingUp;
  String? identifierError, passwordError;
  bool passwordVisible = false;
  bool validate(String identifier, String password) {
    identifierError = identifier.trim().isEmpty
        ? 'Enter your ${signingUp ? 'SIS ID' : 'email or SIS ID'}.'
        : null;
    passwordError = password.isEmpty ? 'Enter your password.' : null;
    notifyListeners();
    return identifierError == null && passwordError == null;
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
}
