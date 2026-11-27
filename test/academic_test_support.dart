import 'package:balamandian/data/repositories/academic_repository.dart';
import 'package:balamandian/domain/models/academic_profile.dart';

class FakeAcademicRepository implements AcademicRepository {
  int reads = 0;
  Object? failure;
  Future<AcademicProfile>? pending;
  AcademicProfile? value;
  @override
  Future<AcademicProfile> synchronize() => loadSaved();
  @override
  Future<AcademicProfile> loadSaved() async {
    reads++;
    if (failure case final error?) throw error;
    return pending ?? value ?? const AcademicProfile.unavailable();
  }
}
