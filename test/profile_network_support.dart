import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:balamandian/data/repositories/api_profile_repository.dart';
import 'package:balamandian/data/services/profile_api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'profile_test_support.dart';

/// Test-only transport: virtual-time delays, offline errors and per-request gates.
/// This file is outside lib and cannot be enabled by a release build flag.
class ProfileNetworkHarness {
  ProfileNetworkHarness() {
    api = ProfileApiService(
      client: MockClient((request) async {
        calls.add(request);
        if (intercept != null) {
          final response = await intercept!(request);
          if (response != null) return response;
        }
        if (delay != Duration.zero) await Future<void>.delayed(delay);
        if (offline) throw const SocketException('Test offline');
        if (fail) {
          return http.Response('{"error":{"code":"NETWORK_ERROR"}}', 503);
        }
        final path = request.url.path;
        if (path.endsWith('/follow')) {
          other = {
            ...other,
            'isFollowing': request.method == 'PUT',
            'followersCount': request.method == 'PUT' ? 1 : 0,
          };
          own = {...own, 'followingCount': request.method == 'PUT' ? 1 : 0};
        } else if (request.method == 'PATCH') {
          own = {
            ...own,
            'biography': (jsonDecode(request.body) as Map)['biography'],
          };
        }
        final Object data =
            path == '/api/v1/users' ||
                path.endsWith('/followers') ||
                path.endsWith('/following')
            ? {
                'items': [other],
                'page': int.parse(request.url.queryParameters['page'] ?? '1'),
                'total': 1,
                'hasMore': false,
              }
            : path.endsWith('/me') || path.endsWith('/me/avatar')
            ? own
            : other;
        return http.Response(jsonEncode({'data': data}), 200);
      }),
      baseUrl: Uri.parse('https://api.example.test'),
      timeout: const Duration(seconds: 12),
    );
    repository = ApiProfileRepository(api: api, withSession: session);
    repository.bindSession(ownId, Object());
  }
  static Future<T> session<T>(Future<T> Function(String token) request) =>
      request('fictional-test-session');
  late final ProfileApiService api;
  late final ApiProfileRepository repository;
  Map<String, Object?> own = profileJson(),
      other = profileJson(id: otherId, own: false);
  Duration delay = Duration.zero;
  bool offline = false, fail = false;
  Future<http.Response?> Function(http.Request)? intercept;
  final calls = <http.Request>[];
  void close() {
    repository.dispose();
    api.close();
  }
}
