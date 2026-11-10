import 'package:balamandian/domain/models/auth_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../auth_test_support.dart';

void main() {
  test(
    '/me uses bearer auth; /logout accepts empty 204 without parsing JSON',
    () async {
      final paths = <String>[];
      final token = List.filled(43, 'A').join();
      final h = AuthTestHarness((request) async {
        paths.add(request.url.path);
        expect(request.headers['Authorization'] == 'Bearer $token', isTrue);
        expect(request.body, isEmpty);
        expect(request.followRedirects, isFalse);
        if (request.url.path.endsWith('/me')) {
          expect(request.method, 'GET');
          return success({
            'user': sessionData()['user']!,
            'session': {'expiresAt': '2099-11-09T10:02:00.000Z'},
          }, 200);
        }
        expect(request.method, 'POST');
        return http.Response('', 204);
      });
      addTearDown(h.close);
      final result = await h.api.me(token);
      expect(result.user.sisUserId, 'FICTION001');
      expect(result.expiresAt, DateTime.utc(2099, 11, 9, 10, 2));
      await h.api.logout(token);
      expect(paths, ['/api/v1/auth/me', '/api/v1/auth/logout']);
    },
  );

  for (final status in [401, 403, 503]) {
    test(
      'Preserves HTTP $status and recognizes only confirmed invalid sessions',
      () async {
        final h = AuthTestHarness(
          (_) async => failure(
            status == 401 ? 'UNAUTHENTICATED' : 'UNKNOWN',
            status: status,
          ),
        );
        addTearDown(h.close);
        await expectLater(
          h.api.me(List.filled(43, 'A').join()),
          throwsA(
            isA<AuthFailure>()
                .having((e) => e.statusCode, 'status', status)
                .having(
                  (e) => e.invalidSession,
                  'invalidSession',
                  status == 401,
                )
                .having(
                  (e) => e.message.contains('Untrusted'),
                  'safe message',
                  false,
                ),
          ),
        );
      },
    );
  }

  test('Rejects malformed /me identity and missing expiry', () async {
    final h = AuthTestHarness(
      (_) async => success({'user': sessionData()['user']!}, 200),
    );
    addTearDown(h.close);
    await expectLater(
      h.api.me(List.filled(43, 'A').join()),
      throwsA(
        isA<AuthFailure>().having((e) => e.code, 'code', 'INVALID_RESPONSE'),
      ),
    );
  });
}
