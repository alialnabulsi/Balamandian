import '../../domain/models/academic_profile.dart';
import '../services/profile_api_service.dart';
import 'academic_repository.dart';

typedef AuthenticatedAcademicRequest = Future<T> Function<T>(
  Future<T> Function(String token) request,
);

class ApiAcademicRepository implements AcademicRepository {
  ApiAcademicRepository({required this.api, required this.withSession});
  final ProfileApiService api;
  final AuthenticatedAcademicRequest withSession;
  @override
  Future<AcademicProfile> synchronize() => withSession(api.syncAcademics);
  @override
  Future<AcademicProfile> loadSaved() => withSession(api.academics);
}
