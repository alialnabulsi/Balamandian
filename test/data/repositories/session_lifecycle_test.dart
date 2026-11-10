import 'dart:async';

import 'package:balamandian/domain/models/auth_failure.dart';
import 'package:balamandian/domain/models/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../auth_test_support.dart';

void main() {
  test(
    'Unresolved secure read reaches recovery without deleting the token',
    () async {
      final read = Completer<void>();
      final h = AuthTestHarness(
        (_) async => fail('No request expected'),
        credentialTimeout: const Duration(milliseconds: 10),
      );
      addTearDown(h.close);
      h.store.session = AuthSession.fromJson(sessionData()).session;
      h.store.waitForRead = read.future;
      await h.repository.restoreSession();
      expect(h.repository.status, SessionStatus.validationError);
      expect(h.store.session, isNotNull);
      expect(h.store.deletes, 0);
      await h.repository.logout(localOnly: true);
      read.complete();
      await Future<void>.delayed(Duration.zero);
      expect(h.repository.status, SessionStatus.unauthenticated);
      expect(h.repository.user, isNull);
    },
  );

  test(
    'A timed-out delete is shared with retry until its actual completion',
    () async {
      final deletion = Completer<void>();
      final h = AuthTestHarness(
        (_) async => success(sessionData(), 200),
        credentialTimeout: const Duration(milliseconds: 10),
      );
      addTearDown(h.close);
      await h.repository.login('FICTION001', 'test');
      h.store.waitForDelete = deletion.future;
      await h.repository.logout(localOnly: true);
      expect(h.repository.status, SessionStatus.validationError);
      expect(h.repository.user, isNull);
      final retry = h.repository.retrySession();
      await Future<void>.delayed(Duration.zero);
      expect(h.store.deletes, 1);
      deletion.complete();
      await retry;
      expect(h.repository.status, SessionStatus.unauthenticated);
      expect(h.store.session, isNull);
      expect(h.store.deletes, 1);
    },
  );

  for (final invalid in [false, true]) {
    test(
      'Late startup ${invalid ? '401' : 'success'} cannot override logout and a newer login',
      () async {
        final validation = Completer<http.Response>();
        final h = AuthTestHarness((request) async {
          if (request.url.path.endsWith('/me')) return validation.future;
          return success({
            ...sessionData(),
            'user': {
              ...sessionData()['user'] as Map,
              'institutionalEmail': 'new@example.edu',
            },
          }, 200);
        });
        addTearDown(h.close);
        h.store.session = AuthSession.fromJson(sessionData()).session;
        final restoration = h.repository.restoreSession();
        await Future<void>.delayed(Duration.zero);
        await h.repository.logout(localOnly: true);
        await h.repository.login('FICTION001', 'test');
        validation.complete(
          invalid
              ? failure('UNAUTHENTICATED', status: 401)
              : success(sessionData(), 200),
        );
        await restoration;
        expect(h.repository.status, SessionStatus.authenticated);
        expect(h.repository.user!.institutionalEmail, 'new@example.edu');
        expect(h.store.deletes, 1);
        expect(h.store.session, isNotNull);
      },
    );
  }

  test('No saved token finishes initialization without a request', () async {
    final h = AuthTestHarness((_) async => fail('No request expected'));
    addTearDown(h.close);
    await h.repository.restoreSession();
    await h.repository.restoreSession();
    expect(h.repository.status, SessionStatus.unauthenticated);
    expect(h.repository.user, isNull);
    expect(h.store.reads, 1);
  });

  test(
    'Restoration deduplicates reads and /me and uses authoritative identity',
    () async {
      final response = Completer<http.Response>();
      var calls = 0;
      final h = AuthTestHarness((request) {
        calls++;
        expect(request.url.path, '/api/v1/auth/me');
        return response.future;
      });
      addTearDown(h.close);
      h.store.session = AuthSession.fromJson(sessionData()).session;
      final first = h.repository.restoreSession();
      final second = h.repository.restoreSession();
      expect(identical(first, second), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(h.repository.status, SessionStatus.initializing);
      expect(h.repository.user, isNull);
      response.complete(
        success({
          'user': {
            ...sessionData()['user'] as Map,
            'institutionalEmail': 'updated@example.edu',
          },
          'session': {'expiresAt': '2099-12-01T00:00:00.000Z'},
        }, 200),
      );
      await first;
      await h.repository.restoreSession();
      expect(h.repository.status, SessionStatus.authenticated);
      expect(h.repository.user!.institutionalEmail, 'updated@example.edu');
      expect(calls, 1);
      expect(h.store.reads, 1);
      expect(h.store.writes, 0);
    },
  );

  test('Revoked token is deleted and exposes the expiration notice', () async {
    final h = AuthTestHarness(
      (_) async => failure('UNAUTHENTICATED', status: 401),
    );
    addTearDown(h.close);
    h.store.session = AuthSession.fromJson(sessionData()).session;
    await h.repository.restoreSession();
    expect(h.repository.status, SessionStatus.unauthenticated);
    expect(h.store.session, isNull);
    expect(h.store.deletes, 1);
    expect(h.repository.sessionNotice, contains('session has expired'));
  });

  for (final mode in [
    'network',
    'timeout',
    'server',
    'forbidden',
    'malformed',
  ]) {
    test(
      '$mode validation failure keeps credentials and allows retry',
      () async {
        var calls = 0;
        final h = AuthTestHarness((_) async {
          if (++calls > 1) return success(sessionData(), 200);
          return switch (mode) {
            'network' => throw http.ClientException('private transport error'),
            'timeout' => Completer<http.Response>().future,
            'server' => failure('INTERNAL_ERROR', status: 503),
            'forbidden' => failure('ACCOUNT_DISABLED', status: 403),
            _ => http.Response('{"data": {}}', 200),
          };
        }, timeout: const Duration(milliseconds: 10));
        addTearDown(h.close);
        h.store.session = AuthSession.fromJson(sessionData()).session;
        await h.repository.restoreSession();
        expect(h.repository.status, SessionStatus.validationError);
        expect(h.repository.user, isNull);
        expect(h.store.session, isNotNull);
        expect(h.store.deletes, 0);
        await h.repository.retrySession();
        expect(h.repository.status, SessionStatus.authenticated);
        expect(calls, 2);
      },
    );
  }

  test('Storage read errors block content and can be retried', () async {
    final h = AuthTestHarness((_) async => fail('No request expected'));
    addTearDown(h.close);
    h.store.failRead = true;
    await h.repository.restoreSession();
    expect(h.repository.status, SessionStatus.validationError);
    expect(h.store.deletes, 0);
    h.store.failRead = false;
    await h.repository.retrySession();
    expect(h.repository.status, SessionStatus.unauthenticated);
  });

  for (final invalid in [false, true]) {
    test(
      'Logout ${invalid ? 'already invalid' : 'success'} deduplicates and deletes credentials',
      () async {
        final response = Completer<http.Response>();
        var calls = 0;
        final h = AuthTestHarness((request) async {
          if (request.url.path.endsWith('/login')) {
            return success(sessionData(), 200);
          }
          calls++;
          expect(request.url.path, '/api/v1/auth/logout');
          return response.future;
        });
        addTearDown(h.close);
        await h.repository.login('FICTION001', 'test');
        final first = h.repository.logout();
        final second = h.repository.logout();
        expect(identical(first, second), isTrue);
        expect(h.repository.status, SessionStatus.signingOut);
        expect(h.store.deletes, 0);
        response.complete(
          invalid
              ? failure('UNAUTHENTICATED', status: 401)
              : http.Response('', 204),
        );
        await first;
        expect(calls, 1);
        expect(h.repository.status, SessionStatus.unauthenticated);
        expect(h.repository.user, isNull);
        expect(h.store.session, isNull);
        expect(h.store.deletes, 1);
      },
    );
  }

  test(
    'Failed server logout retains session; explicit local sign-out clears it',
    () async {
      var calls = 0;
      final h = AuthTestHarness((request) async {
        if (request.url.path.endsWith('/login')) {
          return success(sessionData(), 200);
        }
        calls++;
        throw http.ClientException('offline');
      });
      addTearDown(h.close);
      await h.repository.login('FICTION001', 'test');
      await h.repository.logout();
      expect(h.repository.status, SessionStatus.authenticated);
      expect(h.repository.user, isNotNull);
      expect(h.store.deletes, 0);
      expect(
        h.repository.sessionError,
        contains('Server sign-out could not be confirmed'),
      );
      await h.repository.logout();
      expect(calls, 2);
      await h.repository.logout(localOnly: true);
      expect(calls, 2);
      expect(h.repository.status, SessionStatus.unauthenticated);
      expect(h.repository.user, isNull);
      expect(h.store.session, isNull);
    },
  );

  for (final revoked in [false, true]) {
    test(
      'Deletion failure after ${revoked ? 'revocation' : 'logout'} hides identity and retries cleanup only',
      () async {
        var logoutCalls = 0;
        final h = AuthTestHarness((request) async {
          if (request.url.path.endsWith('/login')) {
            return success(sessionData(), 200);
          }
          if (request.url.path.endsWith('/logout')) {
            logoutCalls++;
            return http.Response('', 204);
          }
          return failure('UNAUTHENTICATED', status: 401);
        });
        addTearDown(h.close);
        h.store.failDelete = true;
        if (revoked) {
          h.store.session = AuthSession.fromJson(sessionData()).session;
          await h.repository.restoreSession();
        } else {
          await h.repository.login('FICTION001', 'test');
          await h.repository.logout();
        }
        expect(h.repository.status, SessionStatus.validationError);
        expect(h.repository.user, isNull);
        expect(h.store.session, isNotNull);
        h.store.failDelete = false;
        await h.repository.retrySession();
        expect(h.repository.status, SessionStatus.unauthenticated);
        expect(h.store.session, isNull);
        expect(logoutCalls, revoked ? 0 : 1);
      },
    );
  }

  test('Protected 401 invalidates once; SIS 401, 403 and 5xx do not', () async {
    var rejectLogin = false;
    final h = AuthTestHarness(
      (_) async => rejectLogin
          ? failure('SIS_INVALID_CREDENTIALS', status: 401)
          : success(sessionData(), 200),
    );
    addTearDown(h.close);
    await h.repository.login('FICTION001', 'test');
    rejectLogin = true;
    await expectLater(
      h.repository.login('FICTION001', 'wrong'),
      throwsA(isA<AuthFailure>()),
    );
    for (final error in [
      AuthFailure.fromApi('ACCOUNT_DISABLED', statusCode: 403),
      AuthFailure.fromApi('INTERNAL_ERROR', statusCode: 500),
      const AuthFailure('NETWORK_ERROR', 'Offline'),
    ]) {
      await expectLater(
        h.repository.withSession<void>((_) async => throw error),
        throwsA(isA<AuthFailure>()),
      );
      expect(h.repository.status, SessionStatus.authenticated);
      expect(h.store.deletes, 0);
    }
    final first = Completer<void>(), second = Completer<void>();
    final a = h.repository.withSession((_) => first.future);
    final b = h.repository.withSession((_) => second.future);
    final checkA = expectLater(a, throwsA(isA<AuthFailure>()));
    final checkB = expectLater(b, throwsA(isA<AuthFailure>()));
    final invalid = AuthFailure.fromApi('UNAUTHENTICATED', statusCode: 401);
    first.completeError(invalid);
    second.completeError(invalid);
    await Future.wait([checkA, checkB]);
    expect(h.store.deletes, 1);
    expect(h.repository.status, SessionStatus.unauthenticated);
  });

  test(
    'Late responses from a previous session cannot affect a new account',
    () async {
      final h = AuthTestHarness((_) async => success(sessionData(), 200));
      addTearDown(h.close);
      await h.repository.login('FICTION001', 'test');
      final late = Completer<void>();
      final request = h.repository.withSession((_) => late.future);
      final check = expectLater(request, throwsA(isA<AuthFailure>()));
      await h.repository.logout(localOnly: true);
      await h.repository.login('FICTION001', 'test');
      late.completeError(
        AuthFailure.fromApi('UNAUTHENTICATED', statusCode: 401),
      );
      await check;
      expect(h.repository.status, SessionStatus.authenticated);
      expect(h.store.deletes, 1);
    },
  );
}
