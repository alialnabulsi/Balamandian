import '../../domain/models/auth_session.dart';
import '../../domain/models/pending_registration.dart';

abstract class AuthRepository {
  Future<PendingRegistration> register(String identifier, String password);
  Future<PendingRegistration> resend(String pendingRegistrationId);
  Future<AuthUser> verify(String pendingRegistrationId, String otp);
  Future<AuthUser> login(String identifier, String password);
}
