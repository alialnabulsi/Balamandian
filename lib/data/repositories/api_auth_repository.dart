import '../../domain/models/auth_failure.dart';
import '../../domain/models/auth_session.dart';
import '../../domain/models/pending_registration.dart';
import '../services/auth_api_service.dart';
import '../services/session_credential_store.dart';
import 'auth_repository.dart';

class ApiAuthRepository implements AuthRepository {
  const ApiAuthRepository({required this._api, required this._credentials});

  final AuthApiService _api;
  final SessionCredentialStore _credentials;

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
    return result.user;
  }
}
