import '../../domain/models/schedule_models.dart';
import '../services/tools_api_service.dart';

abstract interface class SchedulerRepository {
  Future<List<AcademicSemester>> semesters();
  Future<ScheduleData> read(String semester);
  Future<ScheduleData> refresh(String semester);
  Future<ScheduleGeneration> generate(
    ScheduleData data,
    List<String> pool,
    double credits,
  );
  Future<void> save(ScheduleData data, ScheduleOption option);
  Future<void> registrationReminder(String semester, int minutes);
  Future<void> deleteDraft(ScheduleData data);
  Future<void> syncSemesters();
  void cancelPending();
}

class ApiSchedulerRepository implements SchedulerRepository {
  ApiSchedulerRepository(this.api, this.withSession);
  final ToolsApiService api;
  final ToolSessionRequest withSession;
  Future<Object?> _req(String method, String path, {Object? body}) =>
      withSession((t) => api.request(t, method, path, body: body));
  @override
  Future<List<AcademicSemester>> semesters() async =>
      ((await _req('GET', '') as Map)['semesters'] as List)
          .map(AcademicSemester.fromJson)
          .toList();
  @override
  Future<ScheduleData> read(String semester) async => ScheduleData.fromJson(
    await _req('GET', '/${Uri.encodeComponent(semester)}'),
  );
  @override
  Future<ScheduleData> refresh(String semester) async => ScheduleData.fromJson(
    await _req('POST', '/${Uri.encodeComponent(semester)}/refresh'),
  );
  Map<String, Object?> versions(ScheduleData data) => {
    'offeringVersion': data.offeringVersion,
    'memberVersion': data.memberVersion,
    'semesterVersion': data.semester.version,
  };
  @override
  Future<ScheduleGeneration> generate(
    ScheduleData data,
    List<String> pool,
    double credits,
  ) async => ScheduleGeneration.fromJson(
    await _req(
      'POST',
      '/${Uri.encodeComponent(data.semester.id)}/generate',
      body: {...versions(data), 'candidateIds': pool, 'targetCredits': credits},
    ),
  );
  @override
  Future<void> save(ScheduleData data, ScheduleOption option) async {
    await _req(
      'PUT',
      '/${Uri.encodeComponent(data.semester.id)}/draft',
      body: {
        ...versions(data),
        'targetCredits': option.credits,
        'revision': data.draftRevision,
        'courseBundles': [
          for (final c in option.courses)
            {'courseId': c.id, 'bundleId': c.bundleId},
        ],
      },
    );
  }

  @override
  Future<void> registrationReminder(String semester, int minutes) async {
    await _req(
      'PUT',
      '/${Uri.encodeComponent(semester)}/reminder',
      body: {'leadMinutes': minutes},
    );
  }

  @override
  Future<void> deleteDraft(ScheduleData data) => withSession((t) async {
    await api.request(
      t,
      'DELETE',
      '/${Uri.encodeComponent(data.semester.id)}/draft',
      query: {'revision': '${data.draftRevision}'},
      status: 204,
    );
  });
  @override
  Future<void> syncSemesters() async {
    await _req('POST', '/sync');
  }

  @override
  void cancelPending() => api.cancel();
}
