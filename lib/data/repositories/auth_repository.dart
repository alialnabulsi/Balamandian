import 'package:flutter/foundation.dart';

import '../../domain/models/auth_session.dart';
import '../../domain/models/pending_registration.dart';

abstract class AuthRepository extends ChangeNotifier {
  SessionStatus get status;
  AuthUser? get user;
  String? get sessionError;
  String? get sessionNotice;
  Future<void> restoreSession();
  Future<void> retrySession();
  Future<void> logout({bool localOnly = false});
  Future<T> withSession<T>(Future<T> Function(String token) request);
  Future<PendingRegistration> register(String identifier, String password);
  Future<PendingRegistration> resend(String pendingRegistrationId);
  Future<AuthUser> verify(String pendingRegistrationId, String otp);
  Future<AuthUser> login(String identifier, String password);
}
