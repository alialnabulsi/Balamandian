import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/auth_failure.dart';
import '../../domain/models/task_models.dart';

class TaskApiService {
  TaskApiService({
    required this._client,
    required Uri baseUrl,
    this.timeout = const Duration(seconds: 20),
  }) : _baseUrl = baseUrl {
    final local = const {
      '10.0.2.2',
      '127.0.0.1',
      'localhost',
    }.contains(baseUrl.host);
    if (!baseUrl.hasAuthority ||
        baseUrl.host.isEmpty ||
        baseUrl.userInfo.isNotEmpty ||
        baseUrl.hasQuery ||
        baseUrl.hasFragment ||
        (baseUrl.path.isNotEmpty && baseUrl.path != '/') ||
        (baseUrl.scheme != 'https' &&
            !(kDebugMode && local && baseUrl.scheme == 'http'))) {
      throw ArgumentError(
        'API_BASE_URL must be an HTTPS origin (local HTTP is debug-only).',
      );
    }
    if (timeout <= Duration.zero || timeout > const Duration(seconds: 30)) {
      throw ArgumentError('Task timeout must be bounded to 30 seconds.');
    }
  }
  final http.Client _client;
  final Uri _baseUrl;
  final Duration timeout;
  Future<TaskPage> page(String token, int page) => _request(
    token,
    'GET',
    '',
    TaskPage.fromJson,
    query: {'page': '$page', 'limit': '50'},
  );
  Future<PlannerTask> create(String token, TaskDraft draft) => _request(
    token,
    'POST',
    '',
    PlannerTask.fromJson,
    body: draft.toJson(),
    expected: 201,
  );
  Future<PlannerTask> update(
    String token,
    String id,
    Map<String, Object?> fields,
  ) => _request(token, 'PATCH', id, PlannerTask.fromJson, body: fields);
  Future<void> delete(String token, String id) =>
      _request(token, 'DELETE', id, (_) {}, expected: 204);

  Future<T> _request<T>(
    String token,
    String method,
    String id,
    T Function(Object?) parse, {
    Map<String, Object?>? body,
    Map<String, String>? query,
    int expected = 200,
  }) async {
    final abort = Completer<void>();
    final uri = _baseUrl.replace(
      pathSegments: ['api', 'v1', 'tasks', if (id.isNotEmpty) id],
      queryParameters: query,
    );
    final request =
        http.AbortableRequest(method, uri, abortTrigger: abort.future)
          ..followRedirects = false
          ..headers.addAll({
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          });
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=UTF-8';
      request.body = jsonEncode(body);
    }
    try {
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(
            timeout,
            onTimeout: () {
              abort.complete();
              throw TimeoutException('Task timeout');
            },
          );
      if (response.statusCode != expected) {
        String? code;
        try {
          final payload = jsonDecode(utf8.decode(response.bodyBytes));
          if (payload case {'error': {'code': String value}}) code = value;
        } on FormatException {
          /* Ignore untrusted proxy/error text. */
        }
        if (response.statusCode == 401 && code == 'UNAUTHENTICATED') {
          throw AuthFailure.fromApi(code, statusCode: 401);
        }
        throw TaskFailure.fromCode(code);
      }
      if (expected == 204) return parse(null);
      final payload = jsonDecode(utf8.decode(response.bodyBytes));
      if (payload case {'data': final data}) return parse(data);
      throw const FormatException('Missing task data.');
    } on TimeoutException {
      throw TaskFailure.network;
    } on SocketException {
      throw TaskFailure.network;
    } on http.ClientException {
      throw TaskFailure.network;
    } on FormatException {
      throw TaskFailure.invalidResponse;
    }
  }

  void close() => _client.close();
}
