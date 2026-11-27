import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/auth_failure.dart';
import '../../domain/models/note_models.dart';
import '../../domain/models/tool_failure.dart';

typedef ToolSessionRequest = Future<T> Function<T>(
  Future<T> Function(String) request,
);

class ToolsApiService {
  ToolsApiService({
    required this.client,
    required this.baseUrl,
    required this.feature,
  }) {
    if (!baseUrl.hasAuthority ||
        baseUrl.userInfo.isNotEmpty ||
        baseUrl.hasQuery ||
        baseUrl.hasFragment ||
        (baseUrl.path.isNotEmpty && baseUrl.path != '/') ||
        (baseUrl.scheme != 'https' &&
            !(kDebugMode &&
                baseUrl.scheme == 'http' &&
                [
                  'localhost',
                  '127.0.0.1',
                  '10.0.2.2',
                ].contains(baseUrl.host)))) {
      throw ArgumentError('Notes API requires an HTTPS origin.');
    }
  }
  final http.Client client;
  final Uri baseUrl;
  final String feature;
  final _pending = <Completer<void>>{};
  void cancel() {
    for (final c in _pending.toList()) {
      if (!c.isCompleted) c.complete();
    }
    _pending.clear();
  }

  Future<Object?> request(
    String token,
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    int status = 200,
    Map<String, String> headers = const {},
    PickedNoteFile? upload,
    void Function(double)? progress,
    bool binary = false,
  }) async {
    final abort = Completer<void>();
    _pending.add(abort);
    final uri = baseUrl.replace(
      path: '/api/v1/$feature$path',
      queryParameters: query,
    );
    final h = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      ...headers,
    };
    late http.BaseRequest req;
    if (upload != null) {
      final stream = http.AbortableStreamedRequest(
        method,
        uri,
        abortTrigger: abort.future,
      )..contentLength = upload.bytes.length;
      req = stream;
      h['Content-Type'] = upload.type;
      h['X-Filename'] = Uri.encodeComponent(upload.name);
      // The callback measures bytes sent to the request stream. 100% is still
      // awaiting server validation/acknowledgment, never a successful save.
      scheduleMicrotask(() async {
        try {
          for (var offset = 0; offset < upload.bytes.length; offset += 16384) {
            if (abort.isCompleted) break;
            final end = (offset + 16384).clamp(0, upload.bytes.length);
            stream.sink.add(upload.bytes.sublist(offset, end));
            progress?.call(end / upload.bytes.length);
            await Future<void>.delayed(Duration.zero);
          }
          await stream.sink.close();
        } catch (_) {
          /* Request error is handled below. */
        }
      });
    } else {
      final r = http.AbortableRequest(method, uri, abortTrigger: abort.future);
      if (body != null) {
        h['Content-Type'] = 'application/json; charset=UTF-8';
        r.body = jsonEncode(body);
      }
      req = r;
    }
    req.followRedirects = false;
    req.headers.addAll(h);
    try {
      final response = await client
          .send(req)
          .then(http.Response.fromStream)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              if (!abort.isCompleted) abort.complete();
              throw TimeoutException('Notes request');
            },
          );
      if (response.statusCode != status) {
        String? code;
        try {
          final p = jsonDecode(utf8.decode(response.bodyBytes));
          if (p case {'error': {'code': String c}}) code = c;
        } catch (_) {
          /* Never display raw bodies. */
        }
        if (response.statusCode == 401 && code == 'UNAUTHENTICATED') {
          throw AuthFailure.fromApi(code, statusCode: 401);
        }
        throw ToolFailure.fromCode(code);
      }
      if (binary) return response.bodyBytes;
      if (status == 204) return null;
      final payload = jsonDecode(utf8.decode(response.bodyBytes));
      if (payload case {'data': final data}) return data;
      throw const FormatException('Missing Notes data');
    } on http.RequestAbortedException {
      throw ToolFailure.fromCode('CANCELED');
    } on TimeoutException {
      throw ToolFailure.fromCode(null);
    } on SocketException {
      throw ToolFailure.fromCode(null);
    } on http.ClientException {
      throw ToolFailure.fromCode(null);
    } on FormatException {
      throw ToolFailure.fromCode(null);
    } finally {
      _pending.remove(abort);
    }
  }

  void close() {
    cancel();
    client.close();
  }
}
