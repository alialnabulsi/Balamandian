import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:balamandian/data/services/auth_api_service.dart';
import 'package:balamandian/domain/models/auth_failure.dart';
import 'package:balamandian/domain/models/pending_registration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../auth_test_support.dart';

TypeMatcher<AuthFailure> hasCode(String code) =>
    isA<AuthFailure>().having((e) => e.code, 'code', code);

void main() {
  test(
    'Register serializes only credentials and parses pending registration',
    () async {
      final instant = DateTime.utc(2026, 11, 3, 12);
      final harness = AuthTestHarness((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/auth/register');
        expect(request.followRedirects, isFalse);
        expect(request.headers['Content-Type'], contains('application/json'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.keys, unorderedEquals(['identifier', 'password']));
        expect(body['identifier'], 'FICTION001');
        expect(body['password'] == ' unchanged password ', isTrue);
        return success(pendingData(now: instant), 202);
      });
      addTearDown(harness.close);
      final pending = await harness.api.register(
        'FICTION001',
        ' unchanged password ',
      );
      expect(pending.id, registrationId);
      expect(pending.otpExpiresAt, instant.add(const Duration(minutes: 10)));
      expect(
        pending.resendAvailableAt,
        instant.add(const Duration(minutes: 1)),
      );
      expect(harness.store.writes, 0);
    },
  );

  test('Pending parsing rejects invalid identifiers, timestamps and missing fields', () {
    for (final data in [
      <String, dynamic>{},
      {...pendingData(), 'pendingRegistrationId': 'invalid'},
      {...pendingData(), 'otpExpiresAt': 'invalid'},
      {...pendingData(), 'resendAvailableAt': 23},
    ]) {
      expect(() => PendingRegistration.fromJson(data), throwsFormatException);
    }
  });

  test(
    'Verify keeps leading zeroes; resend uses the pending ID only',
    () async {
      final paths = <String>[];
      final harness = AuthTestHarness((request) async {
        paths.add(request.url.path);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['pendingRegistrationId'], registrationId);
        if (request.url.path.endsWith('/verify')) {
          expect(body.keys, unorderedEquals(['pendingRegistrationId', 'otp']));
          expect(body['otp'] == '004281', isTrue);
          return success(sessionData(), 201);
        }
        expect(body.keys, ['pendingRegistrationId']);
        return success(pendingData(), 202);
      });
      addTearDown(harness.close);
      final verified = await harness.api.verify(registrationId, '004281');
      expect(verified.user.sisUserId, 'FICTION001');
      final resent = await harness.api.resend(registrationId);
      expect(resent.id, registrationId);
      expect(paths, [
        '/api/v1/auth/register/verify',
        '/api/v1/auth/register/resend',
      ]);
    },
  );

  for (final code in [
    'SIS_INVALID_CREDENTIALS',
    'ACCOUNT_EXISTS',
    'REGISTRATION_REQUIRED',
    'EMAIL_NOT_VERIFIED',
    'ACCOUNT_DISABLED',
    'OTP_INVALID',
    'OTP_EXPIRED',
    'OTP_COOLDOWN',
    'OTP_ATTEMPT_LIMIT',
    'OTP_RESEND_LIMIT',
    'REGISTRATION_INVALID',
    'SIS_UNAVAILABLE',
    'EMAIL_UNAVAILABLE',
  ]) {
    test('Maps $code without exposing backend text', () async {
      final harness = AuthTestHarness(
        (_) async => failure(code, retryAfter: 37),
      );
      addTearDown(harness.close);
      await expectLater(
        harness.api.login('FICTION001', 'test'),
        throwsA(
          hasCode(code)
              .having(
                (e) => e.message.contains('Untrusted'),
                'safe message',
                isFalse,
              )
              .having((e) => e.retryAfter?.inSeconds, 'retry', 37),
        ),
      );
    });
  }

  for (final mode in [
    'network',
    'socket',
    'timeout',
    'html',
    'malformed',
    'wrong-status',
    'wrong-session',
    'redirect',
  ]) {
    test('Handles $mode failure safely', () async {
      final harness = AuthTestHarness((_) async {
        switch (mode) {
          case 'network':
            throw http.ClientException('untrusted transport text');
          case 'socket':
            throw const SocketException('untrusted transport text');
          case 'timeout':
            return Completer<http.Response>().future;
          case 'html':
            return http.Response('<html>Unavailable</html>', 503);
          case 'malformed':
            return http.Response('{"data": []}', 200);
          case 'wrong-status':
            return success(sessionData(), 202);
          case 'wrong-session':
            return success({
              ...sessionData(),
              'session': {'token': 'invalid'},
            }, 200);
          default:
            return http.Response(
              '',
              307,
              headers: {'location': 'https://other.test'},
            );
        }
      }, timeout: const Duration(milliseconds: 10));
      addTearDown(harness.close);
      final expected = ['network', 'socket', 'timeout'].contains(mode)
          ? 'NETWORK_ERROR'
          : ['malformed', 'wrong-session'].contains(mode)
          ? 'INVALID_RESPONSE'
          : 'SERVICE_ERROR';
      await expectLater(
        harness.api.login('FICTION001', 'test'),
        throwsA(hasCode(expected)),
      );
    });
  }

  test('Base URL accepts HTTPS or debug loopback origins only', () {
    final client = MockClient((_) async => http.Response('', 500));
    addTearDown(client.close);
    for (final origin in [
      'https://api.example.test',
      'http://10.0.2.2:3000',
      'http://127.0.0.1:3000',
    ]) {
      expect(
        () => AuthApiService(client: client, baseUrl: Uri.parse(origin)),
        returnsNormally,
      );
    }
    for (final origin in [
      '',
      'http://remote.example.test',
      'https://api.test/path',
      'https://user:pass@api.test',
      'https://api.test?key=value',
    ]) {
      expect(
        () => AuthApiService(client: client, baseUrl: Uri.parse(origin)),
        throwsArgumentError,
      );
    }
  });
}
