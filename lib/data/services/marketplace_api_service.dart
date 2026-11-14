import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/auth_failure.dart';
import '../../domain/models/marketplace_models.dart';
import '../../domain/models/marketplace_json.dart';

class MarketplaceApiService {
  MarketplaceApiService({
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
      throw ArgumentError('Marketplace timeout must be bounded to 30 seconds.');
    }
  }
  final http.Client _client;
  final Uri _baseUrl;
  final Duration timeout;
  Future<List<MarketplaceCategory>> categories(String token) => _request(
    token,
    'GET',
    ['categories'],
    (v) => MarketplaceJson.list(v, (j) => MarketplaceCategory.fromJson(j)),
  );
  Future<MarketplacePage<MarketplacePlaceSummary>> places(
    String token, {
    String? search,
    String? category,
    int page = 1,
    int limit = 20,
  }) => _request(
    token,
    'GET',
    ['places'],
    (v) => MarketplacePage.fromJson(v, MarketplacePlaceSummary.fromJson),
    query: {
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      'category': ?category,
      'page': '$page',
      'limit': '$limit',
    },
  );
  Future<MarketplacePlaceDetail> place(String token, String id) =>
      _request(token, 'GET', ['places', id], MarketplacePlaceDetail.fromJson);
  Future<MarketplacePage<MarketplacePost>> posts(
    String token, {
    String? type,
    String? placeId,
    int page = 1,
    int limit = 20,
  }) => _request(
    token,
    'GET',
    ['posts'],
    (v) => MarketplacePage.fromJson(v, MarketplacePost.fromJson),
    query: {
      'type': ?type,
      'placeId': ?placeId,
      'page': '$page',
      'limit': '$limit',
    },
  );
  Future<MarketplaceFavoriteResult> favorite(
    String token,
    String id,
    bool value,
  ) => _request(token, value ? 'PUT' : 'DELETE', [
    'places',
    id,
    'favorite',
  ], MarketplaceFavoriteResult.fromJson);
  Future<MarketplaceRatingResult> rating(String token, String id, int? value) =>
      _request(
        token,
        value == null ? 'DELETE' : 'PUT',
        ['places', id, 'rating'],
        MarketplaceRatingResult.fromJson,
        body: value == null ? null : {'rating': value},
      );
  Future<T> _request<T>(
    String token,
    String method,
    List<String> segments,
    T Function(Object?) parse, {
    Map<String, String>? query,
    Map<String, int>? body,
  }) async {
    final abort = Completer<void>();
    final uri = _baseUrl.replace(
      pathSegments: ['api', 'marketplace', ...segments],
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
              throw TimeoutException('Marketplace timeout');
            },
          );
      if (response.statusCode != 200) {
        String? code;
        try {
          final payload = jsonDecode(utf8.decode(response.bodyBytes));
          if (payload case {'error': {'code': String value}}) code = value;
        } on FormatException {
          /* Untrusted proxy errors may not be JSON. */
        }
        if (response.statusCode == 401 && code == 'UNAUTHENTICATED') {
          throw AuthFailure.fromApi(code, statusCode: 401);
        }
        final seconds = int.tryParse(response.headers['retry-after'] ?? '');
        throw MarketplaceFailure.fromApi(
          code,
          retryAfter: seconds != null && seconds > 0
              ? Duration(seconds: seconds.clamp(1, 900))
              : null,
        );
      }
      final payload = jsonDecode(utf8.decode(response.bodyBytes));
      if (payload case {'data': final data}) return parse(data);
      throw const FormatException('Missing marketplace data.');
    } on TimeoutException {
      throw MarketplaceFailure.network;
    } on SocketException {
      throw MarketplaceFailure.network;
    } on http.ClientException {
      throw MarketplaceFailure.network;
    } on FormatException {
      throw MarketplaceFailure.invalidResponse;
    }
  }

  void close() => _client.close();
}
