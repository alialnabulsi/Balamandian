import '../../domain/models/calendar_models.dart';
import '../services/tools_api_service.dart';

abstract interface class CalendarRepository {
  Future<DateTime> today();
  Future<List<CampusEvent>> list(
    DateTime from,
    DateTime to, {
    required bool member,
  });
  Future<CampusEvent> read(String id, {required bool member});
  Future<CampusEvent> save(Map<String, Object?> body, {String? id});
  Future<void> delete(CampusEvent event);
  Future<CampusEvent> reminder(String id, int? minutes);
  Future<List<CampusEvent>> reminders();
  void cancelPending();
}

class ApiCalendarRepository implements CalendarRepository {
  ApiCalendarRepository(this.api, this.withSession);
  final ToolsApiService api;
  final ToolSessionRequest withSession;
  @override
  Future<DateTime> today() async {
    final j = await _req('GET', '/meta', member: false) as Map;
    return DateTime.parse(j['today'] as String);
  }

  Future<Object?> _req(
    String method,
    String path, {
    Object? body,
    int status = 200,
    Map<String, String>? query,
    bool member = true,
  }) => member
      ? withSession(
          (t) => api.request(
            t,
            method,
            path,
            body: body,
            status: status,
            query: query,
          ),
        )
      : api.request('', method, path, query: query);
  @override
  Future<List<CampusEvent>> list(
    DateTime from,
    DateTime to, {
    required bool member,
  }) async => (await _req(
    'GET',
    member ? '/events' : '/academic',
    member: member,
    query: {'from': calendarDate(from), 'to': calendarDate(to)},
  ) as List).map(CampusEvent.fromJson).toList();
  @override
  Future<CampusEvent> read(String id, {required bool member}) async =>
      CampusEvent.fromJson(
        await _req(
          'GET',
          '/${member ? 'events' : 'academic'}/$id',
          member: member,
        ),
      );
  @override
  Future<CampusEvent> save(Map<String, Object?> body, {String? id}) async =>
      CampusEvent.fromJson(
        await _req(
          id == null ? 'POST' : 'PATCH',
          '/events${id == null ? '' : '/$id'}',
          body: body,
          status: id == null ? 201 : 200,
        ),
      );
  @override
  Future<void> delete(CampusEvent event) async {
    await _req(
      'DELETE',
      '/events/${event.id}',
      status: 204,
      query: {'revision': '${event.revision}'},
    );
  }

  @override
  Future<CampusEvent> reminder(String id, int? minutes) async =>
      CampusEvent.fromJson(
        await _req(
          'PUT',
          '/events/$id/reminder',
          body: {'leadMinutes': minutes},
        ),
      );
  @override
  Future<List<CampusEvent>> reminders() async =>
      (await _req('GET', '/reminders') as List)
          .map(CampusEvent.fromJson)
          .toList();
  @override
  void cancelPending() => api.cancel();
}
