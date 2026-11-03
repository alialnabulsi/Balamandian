import 'dart:async';

import 'package:balamandian/domain/models/auth_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../auth_test_support.dart';

void main() {
  test(
    'Login waits for secure persistence and replaces the previous session',
    () async {
      final harness = AuthTestHarness((_) async => success(sessionData(), 200));
      addTearDown(harness.close);
      final write = Completer<void>();
      harness.store.waitForWrite = write.future;
      var completed = false;
      final result = harness.repository.login('FICTION001', 'test').then((
        user,
      ) {
        completed = true;
        return user;
      });
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      write.complete();
      expect((await result).sisUserId, 'FICTION001');
      expect(harness.store.writes, 1);
      await harness.repository.login('FICTION001', 'test');
      expect(harness.store.writes, 2);
    },
  );

  test('Register and resend do not save sessions; verify does', () async {
    final harness = AuthTestHarness(
      (request) async => request.url.path.endsWith('/verify')
          ? success(sessionData(), 201)
          : success(pendingData(), 202),
    );
    addTearDown(harness.close);
    final pending = await harness.repository.register('FICTION001', 'test');
    await harness.repository.resend(pending.id);
    expect(harness.store.writes, 0);
    await harness.repository.verify(pending.id, '004281');
    expect(harness.store.writes, 1);
  });

  test(
    'Credential and storage failures cannot report authenticated success',
    () async {
      final invalid = AuthTestHarness(
        (_) async => failure('SIS_INVALID_CREDENTIALS', status: 401),
      );
      addTearDown(invalid.close);
      await expectLater(
        invalid.repository.login('FICTION001', 'test'),
        throwsA(isA<AuthFailure>()),
      );
      expect(invalid.store.writes, 0);
      final unavailable = AuthTestHarness(
        (_) async => success(sessionData(), 201),
      );
      addTearDown(unavailable.close);
      unavailable.store.fail = true;
      await expectLater(
        unavailable.repository.verify(registrationId, '004281'),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.code,
            'code',
            'SESSION_STORAGE_FAILED',
          ),
        ),
      );
      expect(unavailable.store.writes, 0);
    },
  );
}
