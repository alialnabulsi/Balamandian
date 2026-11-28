import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/auth_failure.dart';
import '../../domain/models/guide_models.dart';

class GuideApiService {
  GuideApiService({
    required this.client,
    required this.baseUrl,
    this.timeout = const Duration(seconds: 20),
  }) {
    if (!baseUrl.hasAuthority ||
        baseUrl.host.isEmpty ||
        baseUrl.userInfo.isNotEmpty ||
        baseUrl.hasQuery ||
        baseUrl.hasFragment ||
        (baseUrl.path.isNotEmpty && baseUrl.path != '/') ||
        (baseUrl.scheme != 'https' &&
            !(kDebugMode &&
                baseUrl.scheme == 'http' &&
                const [
                  '127.0.0.1',
                  'localhost',
                  '10.0.2.2',
                ].contains(baseUrl.host)))) {
      throw ArgumentError(
        'Guide API requires an HTTPS origin (local HTTP is debug-only).',
      );
    }
    if (timeout <= Duration.zero || timeout > const Duration(seconds: 30)) {
      throw ArgumentError('Guide timeout must be bounded.');
    }
  }
  final http.Client client;
  final Uri baseUrl;
  final Duration timeout;
  final _pending = <Completer<void>>{};

  Future<List<GuideSection>> sections(String token, GuideLocale locale) =>
      _request(
        token,
        'GET',
        ['sections'],
        (data) => List.unmodifiable((data as List).map(GuideSection.fromJson)),
        query: {'locale': locale.name},
      );
  Future<GuideSectionDetail> section(
    String token,
    String id,
    GuideLocale locale,
    String? cursor,
  ) => _request(
    token,
    'GET',
    ['sections', id],
    GuideSectionDetail.fromJson,
    query: {'locale': locale.name, 'articleCursor': ?cursor},
  );
  Future<GuideArticle> article(String token, String id) =>
      _request(token, 'GET', ['articles', id], GuideArticle.fromJson);
  Future<GuidePage> search(
    String token,
    String q,
    GuideLocale locale,
    String? cursor,
  ) => _request(
    token,
    'GET',
    ['search'],
    GuidePage.fromJson,
    query: {'q': q, 'locale': locale.name, 'cursor': ?cursor},
  );
  Future<GuidePage> bookmarks(String token, String? cursor) => _request(
    token,
    'GET',
    ['bookmarks'],
    GuidePage.fromJson,
    query: {'cursor': ?cursor},
  );
  Future<void> save(String token, String id) =>
      _request(token, 'PUT', ['bookmarks', id], (_) {}, expected: 204);
  Future<void> remove(String token, String id) =>
      _request(token, 'DELETE', ['bookmarks', id], (_) {}, expected: 204);

  Future<T> _request<T>(
    String token,
    String method,
    List<String> path,
    T Function(Object?) parse, {
    Map<String, String>? query,
    int expected = 200,
  }) async {
    final abort = Completer<void>();
    _pending.add(abort);
    final request =
        http.AbortableRequest(
            method,
            baseUrl.replace(
              pathSegments: ['api', 'v1', 'guide', ...path],
              queryParameters: query,
            ),
            abortTrigger: abort.future,
          )
          ..followRedirects = false
          ..headers.addAll({
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          });
    try {
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(
            timeout,
            onTimeout: () {
              if (!abort.isCompleted) abort.complete();
              throw TimeoutException('Guide request');
            },
          );
      if (response.statusCode != expected) {
        String? code;
        try {
          final payload = jsonDecode(utf8.decode(response.bodyBytes));
          if (payload case {'error': {'code': String c}}) code = c;
        } catch (_) {
          /* Never display raw response text. */
        }
        if (response.statusCode == 401) {
          throw AuthFailure.fromApi('UNAUTHENTICATED', statusCode: 401);
        }
        throw GuideFailure.fromCode(code);
      }
      if (expected == 204) return parse(null);
      final payload = jsonDecode(utf8.decode(response.bodyBytes));
      if (payload case {'data': final data}) return parse(data);
      throw const FormatException('Missing Guide data');
    } on http.RequestAbortedException {
      throw GuideFailure.canceled;
    } on TimeoutException {
      throw GuideFailure.network;
    } on SocketException {
      throw GuideFailure.network;
    } on http.ClientException {
      throw GuideFailure.network;
    } on FormatException {
      throw GuideFailure.invalidResponse;
    } on TypeError {
      throw GuideFailure.invalidResponse;
    } on ArgumentError {
      throw GuideFailure.invalidResponse;
    } finally {
      _pending.remove(abort);
    }
  }

  void cancelPending() {
    for (final abort in _pending.toList()) {
      if (!abort.isCompleted) abort.complete();
    }
    _pending.clear();
  }

  void close() {
    cancelPending();
    client.close();
  }
}
