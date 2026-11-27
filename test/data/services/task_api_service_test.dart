import 'dart:convert';

import 'package:balamandian/data/repositories/api_task_repository.dart';
import 'package:balamandian/data/services/task_api_service.dart';
import 'package:balamandian/domain/models/auth_session.dart';
import 'package:balamandian/domain/models/task_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../auth_test_support.dart';
import '../../task_test_support.dart';

http.Response taskResponse(Map<String, Object?> data, int status) =>
    http.Response(jsonEncode({'data': data}), status);

void main() {
  test('Task model maps actual statuses, nullable details, Unicode and invalid data', () {
    for (final status in TaskStatus.values) {
      final task = PlannerTask.fromJson(
        taskJson(title: 'تذكير', status: status),
      );
      expect(task.title, 'تذكير');
      expect(task.details, isNull);
      expect(task.status, status);
    }
    for (final patch in [
      {'status': 'Done'},
      {'details': 3},
      {'title': ''},
      {'id': 'bad'},
      {'updatedAt': 'bad'},
    ]) {
      expect(
        () => PlannerTask.fromJson({...taskJson(), ...patch}),
        throwsFormatException,
      );
    }
  });
  test('Real API paths, authenticated CRUD, details clearing, safe failures and expired session', () async {
    final auth = AuthTestHarness((_) async => success(sessionData(), 200));
    addTearDown(auth.close);
    await auth.repository.login('FICTION001', 'test');
    final requests = <http.Request>[];
    String? failure;
    final api = TaskApiService(
      client: MockClient((request) async {
        requests.add(request);
        if (failure != null) {
          return http.Response(
            jsonEncode({
              'error': {'code': failure, 'message': 'untrusted secret'},
            }),
            failure == 'UNAUTHENTICATED' ? 401 : 403,
          );
        }
        if (request.method == 'DELETE') return http.Response('', 204);
        if (request.method == 'GET') {
          return taskResponse(taskPageJson([taskJson()]), 200);
        }
        return taskResponse({
          ...taskJson(),
          ...jsonDecode(request.body) as Map<String, dynamic>,
        }, request.method == 'POST' ? 201 : 200);
      }),
      baseUrl: Uri.parse('https://example.test'),
    );
    addTearDown(api.close);
    final repository = ApiTaskRepository(
      api: api,
      withSession: auth.repository.withSession,
    );
    expect((await repository.loadAll()).length, 1);
    const draft = TaskDraft(
      title: ' Read ',
      details: '',
      status: TaskStatus.inProgress,
    );
    final task = await repository.create(draft);
    expect(task.details, isNull);
    expect(task.status, TaskStatus.inProgress);
    await repository.update(task.id, draft);
    expect(jsonDecode(requests.last.body), {
      'title': 'Read',
      'details': null,
      'status': 'in_progress',
    });
    await repository.changeStatus(task.id, TaskStatus.done);
    expect(jsonDecode(requests.last.body), {'status': 'done'});
    await repository.delete(task.id);
    expect(requests.last.body, isEmpty);
    expect(requests.first.url.path, '/api/v1/tasks');
    expect(requests.first.url.queryParameters, {'page': '1', 'limit': '50'});
    expect(
      requests.every(
        (request) => request.headers['Authorization'] == 'Bearer ${'A' * 43}',
      ),
      isTrue,
    );
    failure = 'TASKS_FORBIDDEN';
    await expectLater(
      repository.loadAll(),
      throwsA(
        isA<TaskFailure>().having(
          (e) => e.message,
          'message',
          isNot(contains('untrusted')),
        ),
      ),
    );
    expect(auth.repository.status, SessionStatus.authenticated);
    failure = 'UNAUTHENTICATED';
    await expectLater(repository.loadAll(), throwsA(anything));
    expect(auth.repository.status, SessionStatus.unauthenticated);
  });
  test(
    'All pages are loaded and incomplete or drifting collections fail visibly',
    () async {
      var drift = false;
      final api = TaskApiService(
        client: MockClient((request) async {
          final page = int.parse(request.url.queryParameters['page']!);
          return taskResponse(
            taskPageJson(
              [
                for (
                  var i = page == 1 ? 1 : 51;
                  i <= (page == 1 ? 50 : 51);
                  i++
                )
                  taskJson(number: i),
              ],
              page: page,
              total: drift && page == 2 ? 52 : 51,
              completed: 0,
              hasNext: page == 1,
            ),
            200,
          );
        }),
        baseUrl: Uri.parse('https://example.test'),
      );
      addTearDown(api.close);
      Future<T> withSession<T>(Future<T> Function(String) request) =>
          request('token');
      final repository = ApiTaskRepository(api: api, withSession: withSession);
      expect((await repository.loadAll()).length, 51);
      drift = true;
      await expectLater(repository.loadAll(), throwsA(isA<TaskFailure>()));
    },
  );
  test(
    'Malformed proxy data and unavailable networks expose safe messages',
    () async {
      for (final client in [
        MockClient((_) async => http.Response('<html>private</html>', 200)),
        MockClient((_) async => throw http.ClientException('private')),
      ]) {
        final api = TaskApiService(
          client: client,
          baseUrl: Uri.parse('https://example.test'),
        );
        await expectLater(
          api.page('token', 1),
          throwsA(
            isA<TaskFailure>().having(
              (e) => e.message,
              'safe',
              isNot(contains('private')),
            ),
          ),
        );
        api.close();
      }
    },
  );
}
