import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/ai_conversation.dart';
import '../../domain/models/auth_failure.dart';

class AiAssistantApiService {
  AiAssistantApiService(this.client, this.baseUrl);

  final http.Client client;
  final Uri baseUrl;
  static const _timeout = Duration(seconds: 25);

  Future<AiJson> json(
    String token,
    String method,
    String path, {
    Map<String, String>? query,
    AiJson? body,
  }) async {
    final abort = Completer<void>();
    final deadline = Timer(_timeout, abort.complete);
    try {
      final request = _request(
        token,
        method,
        path,
        abort.future,
        query: query,
        body: body,
      );
      final response = await _network(
        () async =>
            http.Response.fromStream(await client.send(request))
                .timeout(_timeout),
      );
      _check(response);
      return response.statusCode == 204 ? {} : _data(response);
    } finally {
      deadline.cancel();
    }
  }

  Future<void> generate(
    String token,
    String path, {
    required String key,
    required Future<void> abort,
    required AiJson body,
    required void Function(AiStreamEvent) onEvent,
  }) async {
    final deadline = Completer<void>();
    final stop = Future.any([abort, deadline.future]);
    final timer = Timer(_timeout, deadline.complete);
    try {
      final request = _request(token, 'POST', path, stop, body: body);
      request.headers.addAll({
        'Accept': 'text/event-stream, application/json',
        'Idempotency-Key': key,
      });
      final response = await _network(
        () => client.send(request).timeout(_timeout),
      );
      timer.cancel();
      final type = response.headers['content-type']
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      if (response.statusCode != 200 || type == 'application/json') {
        final buffered = await _network(
          () => http.Response.fromStream(response).timeout(_timeout),
        );
        _check(buffered);
        onEvent(
          AiStart(AiGenerationIds.fromJson(_data(buffered)), replay: true),
        );
        return;
      }
      if (type != 'text/event-stream') {
        throw const AiFailure('INVALID_RESPONSE');
      }
      await _network(() async {
        await for (final event in parseAiEvents(
          response.stream.timeout(_timeout),
        )) {
          onEvent(event);
        }
      });
    } finally {
      timer.cancel();
      if (!deadline.isCompleted) deadline.complete();
    }
  }

  http.AbortableRequest _request(
    String token,
    String method,
    String path,
    Future<void> abort, {
    Map<String, String>? query,
    AiJson? body,
  }) {
    final uri = baseUrl
        .resolve('/api/v1/ai$path')
        .replace(queryParameters: query);
    final request = http.AbortableRequest(method, uri, abortTrigger: abort)
      ..followRedirects = false
      ..headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.bodyBytes = utf8.encode(jsonEncode(body));
    }
    return request;
  }

  AiJson _data(http.Response response) =>
      (jsonDecode(utf8.decode(response.bodyBytes)) as AiJson)['data'] as AiJson;

  void _check(http.Response response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) return;
    final retry = int.tryParse(response.headers['retry-after'] ?? '');
    String? code;
    try {
      code =
          (jsonDecode(utf8.decode(response.bodyBytes))
                  as AiJson)['error']['code']
              as String?;
    } on Object {
      // A proxy can return an error without the API's JSON envelope.
    }
    if (status == 401) {
      throw AuthFailure.fromApi('UNAUTHENTICATED', statusCode: status);
    }
    throw AiFailure(
      code ?? (status == 429 ? 'RATE_LIMITED' : 'SERVICE_ERROR'),
      httpStatus: status,
      retryAfter: retry != null && retry >= 0 ? Duration(seconds: retry) : null,
    );
  }

  Future<T> _network<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on http.ClientException {
      throw const AiFailure('OFFLINE');
    } on TimeoutException {
      throw const AiFailure('OFFLINE');
    }
  }

  void close() => client.close();
}

/// Decodes UTF-8 and lines incrementally. Only delimiter-terminated events
/// take effect, even when the socket closes halfway through a terminal frame.
Stream<AiStreamEvent> parseAiEvents(Stream<List<int>> bytes) async* {
  final data = <String>[];
  String? kind;
  AiGenerationIds? ids;
  var sequence = 0;
  await for (final line
      in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (data.isEmpty) {
        kind = null;
        continue;
      }
      final event = kind;
      final payload = data.join('\n');
      data.clear();
      kind = null;
      if (!const {'start', 'delta', 'done', 'error'}.contains(event)) continue;
      final json = jsonDecode(payload) as AiJson;
      if (event == 'start') {
        if (ids != null) throw const AiFailure('INVALID_STREAM');
        ids = AiGenerationIds.fromJson(json);
        yield AiStart(ids);
        continue;
      }
      final active = ids;
      if (active == null) throw const AiFailure('INVALID_STREAM');
      if (event == 'delta') {
        if (json['sequence'] != ++sequence) {
          throw const AiFailure('INVALID_STREAM');
        }
        yield AiDelta(json['text'] as String);
        continue;
      }
      final status = AiStatus.values.byName(json['status'] as String);
      if (active.generation != json['generationId'] ||
          (event == 'done' && status != AiStatus.completed) ||
          (event == 'error' &&
              status != AiStatus.failed &&
              status != AiStatus.cancelled)) {
        throw const AiFailure('INVALID_STREAM');
      }
      yield AiTerminal(
        AiGeneration(
          active,
          status,
          event == 'done' ? json['body'] as String : null,
          event == 'done' ? aiCitations(json) : const [],
          json['code'] as String?,
        ),
      );
      return;
    }
    if (line.startsWith(':')) continue;
    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    if (field == 'event') kind = value;
    if (field == 'data') data.add(value);
  }
  throw const AiFailure('STREAM_INTERRUPTED');
}
