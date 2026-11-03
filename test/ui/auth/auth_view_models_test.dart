import 'dart:async';

import 'package:balamandian/domain/models/pending_registration.dart';
import 'package:balamandian/ui/auth/view_models/credentials_view_model.dart';
import 'package:balamandian/ui/auth/view_models/otp_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../auth_test_support.dart';

void main() {
  test('Credential validation follows the backend limits', () {
    final harness = AuthTestHarness((_) async => failure('VALIDATION_ERROR'));
    addTearDown(harness.close);
    final model = CredentialsViewModel(
      signingUp: true,
      repository: harness.repository,
    );
    addTearDown(model.dispose);
    expect(model.validate('', ''), isFalse);
    expect(model.validate('has space', 'password'), isFalse);
    expect(model.validate('has\u0000control', 'password'), isFalse);
    expect(model.validate(List.filled(255, 'x').join(), 'password'), isFalse);
    expect(
      model.validate('FICTION001', List.filled(1025, 'x').join()),
      isFalse,
    );
    expect(
      model.validate('member@example.edu', ' unchanged password '),
      isTrue,
    );
  });

  for (final signup in [true, false]) {
    test(
      'Credentials ${signup ? 'register' : 'login'} prevent concurrent submissions',
      () async {
        var calls = 0;
        final reply = Completer<http.Response>();
        final harness = AuthTestHarness((_) {
          calls++;
          return reply.future;
        });
        addTearDown(harness.close);
        final model = CredentialsViewModel(
          signingUp: signup,
          repository: harness.repository,
        );
        addTearDown(model.dispose);
        final request = model.submit('FICTION001', 'test');
        expect(model.pending, isTrue);
        expect(await model.submit('FICTION001', 'test'), isFalse);
        reply.complete(
          signup ? success(pendingData(), 202) : success(sessionData(), 200),
        );
        expect(await request, isTrue);
        expect(calls, 1);
        expect(model.pending, isFalse);
        expect(model.pendingRegistration != null, signup);
      },
    );
  }

  test('Registration failure exposes a safe error and permits retry', () async {
    var calls = 0;
    final harness = AuthTestHarness(
      (_) async => ++calls == 1
          ? failure('ACCOUNT_EXISTS', status: 409)
          : success(pendingData(), 202),
    );
    addTearDown(harness.close);
    final model = CredentialsViewModel(
      signingUp: true,
      repository: harness.repository,
    );
    addTearDown(model.dispose);
    expect(await model.submit('FICTION001', 'test'), isFalse);
    expect(model.formError, contains('already exists'));
    expect(await model.submit('FICTION001', 'test'), isTrue);
    expect(model.formError, isNull);
  });

  test('OTP expiration and resend cooldown use returned timestamps, including new resends', () async {
    var instant = DateTime.utc(2026, 11, 3, 12);
    final harness = AuthTestHarness(
      (_) async => success(pendingData(now: instant, cooldown: 25), 202),
    );
    addTearDown(harness.close);
    final model = OtpViewModel(
      repository: harness.repository,
      registration: PendingRegistration.fromJson(
        pendingData(now: instant, cooldown: 37),
      ),
      now: () => instant,
    );
    addTearDown(model.dispose);
    expect(model.resendSeconds, 37);
    expect(await model.resend(), isFalse);
    instant = instant.add(const Duration(seconds: 37));
    expect(model.canResend, isTrue);
    expect(await model.resend(), isTrue);
    expect(model.resendSeconds, 25);
    instant = instant.add(const Duration(minutes: 10));
    expect(model.expired, isTrue);
    expect(await model.verify('004281'), isFalse);
    expect(model.canResend, isTrue);
    expect(await model.resend(), isTrue);
    expect(model.expired, isFalse);
    expect(model.notice, contains('latest email'));
  });

  test('OTP locks verify/resend against concurrent requests and enforces six digits', () async {
    final reply = Completer<http.Response>();
    var calls = 0;
    final harness = AuthTestHarness((_) {
      calls++;
      return reply.future;
    });
    addTearDown(harness.close);
    final model = OtpViewModel(
      repository: harness.repository,
      registration: PendingRegistration.fromJson(pendingData(cooldown: 0)),
    );
    addTearDown(model.dispose);
    expect(await model.verify('123'), isFalse);
    expect(model.codeError, isNotNull);
    final request = model.verify('004281');
    expect(await model.verify('004281'), isFalse);
    expect(await model.resend(), isFalse);
    reply.complete(success(sessionData(), 201));
    expect(await request, isTrue);
    expect(calls, 1);
  });

  for (final code in [
    'OTP_INVALID',
    'OTP_EXPIRED',
    'OTP_ATTEMPT_LIMIT',
    'REGISTRATION_INVALID',
    'SESSION_STORAGE_FAILED',
    'OTP_COOLDOWN',
    'OTP_RESEND_LIMIT',
    'EMAIL_UNAVAILABLE',
  ]) {
    test('OTP handles $code', () async {
      var instant = DateTime.utc(2026, 11, 3, 12);
      final harness = AuthTestHarness(
        (_) async => code == 'SESSION_STORAGE_FAILED'
            ? success(sessionData(), 201)
            : failure(code, retryAfter: 13),
      );
      harness.store.fail = code == 'SESSION_STORAGE_FAILED';
      addTearDown(harness.close);
      final model = OtpViewModel(
        repository: harness.repository,
        registration: PendingRegistration.fromJson(
          pendingData(now: instant, cooldown: 0),
        ),
        now: () => instant,
      );
      addTearDown(model.dispose);
      expect(await model.verify('004281'), isFalse);
      expect(model.formError ?? model.codeError, isNotNull);
      expect(model.pending, isFalse);
      if (code == 'REGISTRATION_INVALID') expect(model.requiresRestart, isTrue);
      if (code == 'SESSION_STORAGE_FAILED') expect(model.requiresLogin, isTrue);
      if (code == 'OTP_EXPIRED') expect(model.expired, isTrue);
      if (code != 'SESSION_STORAGE_FAILED') {
        expect(model.retrySeconds, 13);
        expect(model.canResend, isFalse);
        instant = instant.add(const Duration(seconds: 13));
        expect(model.retrySeconds, 0);
      }
      if (['OTP_ATTEMPT_LIMIT', 'EMAIL_UNAVAILABLE'].contains(code)) {
        expect(model.canVerify, isFalse);
      }
    });
  }

  test(
    'Missing pending registration requires restarting without a request',
    () {
      final harness = AuthTestHarness(
        (_) async => throw StateError('No request expected'),
      );
      addTearDown(harness.close);
      final model = OtpViewModel(
        repository: harness.repository,
        registration: null,
      );
      addTearDown(model.dispose);
      expect(model.requiresRestart, isTrue);
      expect(model.canVerify || model.canResend, isFalse);
    },
  );

  test(
    'Completing requests after view-model disposal does not notify listeners',
    () async {
      final reply = Completer<http.Response>();
      final harness = AuthTestHarness((_) => reply.future);
      addTearDown(harness.close);
      final model = CredentialsViewModel(
        signingUp: true,
        repository: harness.repository,
      );
      final request = model.submit('FICTION001', 'test');
      model.dispose();
      reply.complete(success(pendingData(), 202));
      expect(await request, isTrue);
    },
  );
}
