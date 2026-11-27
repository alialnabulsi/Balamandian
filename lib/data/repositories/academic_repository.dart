import '../../domain/models/academic_profile.dart';

abstract interface class AcademicRepository {
  /// Reads only the saved owner profile. Never initiates SIS synchronization.
  Future<AcademicProfile> loadSaved();
  Future<AcademicProfile> synchronize();
}
