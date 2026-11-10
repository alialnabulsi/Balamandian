import 'package:flutter/foundation.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../domain/models/auth_session.dart';

class SessionViewModel extends ChangeNotifier {
  SessionViewModel({required this._repository}) {
    _repository.addListener(notifyListeners);
  }

  final AuthRepository _repository;
  SessionStatus get status => _repository.status;
  AuthUser? get user => _repository.user;
  String? get error => _repository.sessionError;
  bool get busy =>
      status == SessionStatus.initializing ||
      status == SessionStatus.signingOut;
  String get activityLabel => status == SessionStatus.signingOut
      ? 'Signing out…'
      : 'Connecting to Balamandian…';

  Future<void> retry() => _repository.retrySession();
  Future<void> logout({bool localOnly = false}) =>
      _repository.logout(localOnly: localOnly);

  @override
  void dispose() {
    _repository.removeListener(notifyListeners);
    super.dispose();
  }
}
