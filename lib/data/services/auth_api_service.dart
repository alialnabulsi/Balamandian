import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/auth_failure.dart';
import '../../domain/models/auth_session.dart';
import '../../domain/models/pending_registration.dart';

class AuthApiService {
  AuthApiService({
    required this._client,
    required Uri baseUrl,
    this.timeout = const Duration(seconds: 30),
  }) : _baseUrl = baseUrl {
    final local = const {
      '10.0.2.2',
      '127.0.0.1',
      'localhost',
    }.contains(baseUrl.host);
    if (!baseUrl.hasAuthority ||
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
  }

  static const configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kDebugMode ? 'http://10.0.2.2:3000' : '',
  );

  final http.Client _client;
  final Uri _baseUrl;
  final Duration timeout;

  Future<PendingRegistration> register(String identifier, String password) =>
      _post(
        '/register',
        {'identifier': identifier, 'password': password},
        202,
        PendingRegistration.fromJson,
      );

  Future<AuthSession> login(String identifier, String password) => _post(
    '/login',
    {'identifier': identifier, 'password': password},
    200,
    AuthSession.fromJson,
  );

  Future<AuthSession> verify(String id, String otp) => _post(
    '/register/verify',
    {'pendingRegistrationId': id, 'otp': otp},
    201,
    AuthSession.fromJson,
  );

  Future<PendingRegistration> resend(String id) => _post(
    '/register/resend',
    {'pendingRegistrationId': id},
    202,
    PendingRegistration.fromJson,
  );

  Future<T> _post<T>(
    String path,
    Map<String, String> body,
    int successStatus,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final abort = Completer<void>();
    final request =
        http.AbortableRequest(
            'POST',
            _baseUrl.resolve('/api/v1/auth$path'),
            abortTrigger: abort.future,
          )
          ..followRedirects = false
          ..headers.addAll({
            'Content-Type': 'application/json; charset=UTF-8',
            'Accept': 'application/json',
          })
          ..body = jsonEncode(body);
    try {
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(
            timeout,
            onTimeout: () {
              abort.complete();
              throw TimeoutException('Authentication request timed out.');
            },
          );
      if (response.statusCode != successStatus) {
        String? code;
        try {
          final payload = jsonDecode(utf8.decode(response.bodyBytes));
          if (payload case {'error': {'code': String value}}) code = value;
        } on FormatException {
          // Proxies and unavailable services may return non-JSON error bodies.
        }
        final seconds = int.tryParse(response.headers['retry-after'] ?? '');
        throw AuthFailure.fromApi(
          code,
          retryAfter: seconds != null && seconds > 0
              ? Duration(seconds: seconds.clamp(1, 3600))
              : null,
        );
      }
      final payload = jsonDecode(utf8.decode(response.bodyBytes));
      if (payload case {'data': Map<String, dynamic> data}) return parse(data);
      throw const FormatException('Missing authentication data.');
    } on TimeoutException {
      throw const AuthFailure(
        'NETWORK_ERROR',
        'The request timed out. Check your connection and try again.',
      );
    } on SocketException {
      throw const AuthFailure(
        'NETWORK_ERROR',
        'Cannot reach the service. Check your connection and try again.',
      );
    } on http.ClientException {
      throw const AuthFailure(
        'NETWORK_ERROR',
        'Cannot reach the service. Check your connection and try again.',
      );
    } on FormatException {
      throw const AuthFailure(
        'INVALID_RESPONSE',
        'The service returned an unexpected response. Please try again later.',
      );
    }
  }

  void close() => _client.close();
}
