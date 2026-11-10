import 'dart:convert';

import 'package:balamandian/data/repositories/api_auth_repository.dart';
import 'package:balamandian/data/services/auth_api_service.dart';
import 'package:balamandian/data/services/session_credential_store.dart';
import 'package:balamandian/domain/models/auth_session.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const registrationId = '0b3b97c7-c8fd-44b0-b013-cdbd9cf735f0';

Map<String, Object> pendingData({
  DateTime? now,
  int cooldown = 60,
  int lifetime = 600,
}) {
  final instant = (now ?? DateTime.now()).toUtc();
  return {
    'pendingRegistrationId': registrationId,
    'otpExpiresAt': instant.add(Duration(seconds: lifetime)).toIso8601String(),
    'resendAvailableAt': instant
        .add(Duration(seconds: cooldown))
        .toIso8601String(),
  };
}

Map<String, Object> sessionData() => {
  'user': {
    'id': '11111111-1111-4111-8111-111111111111',
    'sisUserId': 'FICTION001',
    'institutionalEmail': 'member@example.edu',
    'emailVerifiedAt': '2026-11-02T10:02:00.000Z',
  },
  'session': {
    'token': List.filled(43, 'A').join(),
    'tokenType': 'Bearer',
    'expiresAt': '2099-11-09T10:02:00.000Z',
  },
};

http.Response success(Map<String, Object> data, int status) =>
    http.Response(jsonEncode({'data': data}), status);

http.Response failure(String code, {int status = 400, int? retryAfter}) =>
    http.Response(
      jsonEncode({
        'error': {'code': code, 'message': 'Untrusted server text'},
      }),
      status,
      headers: {if (retryAfter != null) 'retry-after': '$retryAfter'},
    );

class MemoryCredentialStore implements SessionCredentialStore {
  IssuedSession? session;
  int writes = 0;
  bool fail = false;
  bool failRead = false, failDelete = false;
  int reads = 0, deletes = 0;
  Future<void>? waitForWrite;
  Future<void>? waitForRead, waitForDelete;

  @override
  Future<IssuedSession?> read() async {
    reads++;
    await waitForRead;
    if (failRead) throw StateError('Storage unavailable');
    return session;
  }

  @override
  Future<void> delete() async {
    deletes++;
    await waitForDelete;
    if (failDelete) throw StateError('Storage unavailable');
    session = null;
  }

  @override
  Future<void> save(IssuedSession value) async {
    await waitForWrite;
    if (fail) throw StateError('Storage unavailable');
    session = value;
    writes++;
  }
}

class AuthTestHarness {
  AuthTestHarness(
    Future<http.Response> Function(http.Request) handler, {
    Duration timeout = const Duration(seconds: 30),
    Duration credentialTimeout = const Duration(seconds: 10),
  }) {
    api = AuthApiService(
      client: MockClient(handler),
      baseUrl: Uri.parse('https://api.example.test'),
      timeout: timeout,
    );
    repository = ApiAuthRepository(
      api: api,
      credentials: store,
      credentialTimeout: credentialTimeout,
    );
  }

  final store = MemoryCredentialStore();
  late final AuthApiService api;
  late final ApiAuthRepository repository;
  void close() {
    repository.dispose();
    api.close();
  }
}
