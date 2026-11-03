import 'dart:async';
import 'dart:convert';

import 'package:balamandian/ui/auth/view_models/auth_ui_controller.dart';
import 'package:balamandian/ui/auth/widgets/credentials_screen.dart';
import 'package:balamandian/ui/auth/widgets/otp_screen.dart';
import 'package:balamandian/ui/core/ui/action_button.dart';
import 'package:balamandian/ui/home/widgets/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../auth_test_support.dart';
import '../startup_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadStartupFonts);

  testWidgets('Accessible controls meet Android touch targets', (tester) async {
    await pumpStartup(tester, screen: 'sign-in');
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel(RegExp('Email or SIS ID')), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('Password')), findsWidgets);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final signup in [false, true]) {
    testWidgets(
      '${signup ? 'Registration' : 'Login'} validates and submits once, retaining failed input',
      (tester) async {
        var calls = 0;
        final reply = Completer<http.Response>();
        final harness = AuthTestHarness((request) {
          calls++;
          expect(
            request.url.path,
            signup ? '/api/v1/auth/register' : '/api/v1/auth/login',
          );
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload.keys, unorderedEquals(['identifier', 'password']));
          expect(payload['identifier'], 'FICTION001');
          expect(payload['password'] == ' entered password ', isTrue);
          return reply.future;
        });
        addTearDown(harness.close);
        await pumpStartup(
          tester,
          screen: signup ? 'sign-up' : 'sign-in',
          authRepository: harness.repository,
        );
        await tester.tap(find.byType(ActionButton));
        await tester.pump();
        expect(
          find.text(
            signup ? 'Enter your SIS ID.' : 'Enter your email or SIS ID.',
          ),
          findsOneWidget,
        );
        expect(find.text('Enter your password.'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .focusNode!
              .hasFocus,
          isTrue,
        );
        await tester.enterText(find.byType(TextField).first, '  FICTION001  ');
        await tester.enterText(
          find.byType(TextField).last,
          ' entered password ',
        );
        await tester.tap(find.byTooltip('Show password'));
        await tester.pump();
        expect(
          tester.widget<TextField>(find.byType(TextField).last).obscureText,
          isFalse,
        );
        await tester.tap(find.byType(ActionButton));
        await tester.tap(find.byType(ActionButton));
        await tester.pump();
        expect(calls, 1);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        for (final field in tester.widgetList<TextField>(
          find.byType(TextField),
        )) {
          expect(field.enabled, isFalse);
        }
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byType(CredentialsScreen), findsOneWidget);
        reply.complete(failure('SIS_INVALID_CREDENTIALS', status: 401));
        await tester.pumpAndSettle();
        expect(
          find.text('Your SIS ID/email or password is incorrect.'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextField>(find.byType(TextField).last)
              .controller!
              .text
              .isNotEmpty,
          isTrue,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField).last).obscureText,
          isTrue,
        );
        expect(harness.store.writes, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'Registration opens OTP; verification saves session before Home',
    (tester) async {
      final write = Completer<void>();
      final paths = <String>[];
      final harness = AuthTestHarness((request) async {
        paths.add(request.url.path);
        if (request.url.path.endsWith('/register')) {
          return success(pendingData(), 202);
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.keys, unorderedEquals(['pendingRegistrationId', 'otp']));
        expect(body['pendingRegistrationId'], registrationId);
        expect(body['otp'] == '004281', isTrue);
        return success(sessionData(), 201);
      });
      harness.store.waitForWrite = write.future;
      addTearDown(harness.close);
      await pumpStartup(
        tester,
        screen: 'sign-up',
        authRepository: harness.repository,
      );
      await tester.enterText(
        find.byType(TextField).first,
        'member@example.edu',
      );
      await tester.enterText(find.byType(TextField).last, 'test password');
      await tester.tap(find.byType(ActionButton));
      await advanceTransition(tester);
      expect(find.byType(OtpScreen), findsOneWidget);
      expect(find.text('A little about you'), findsNothing);
      expect(harness.store.writes, 0);
      await tester.enterText(find.byType(TextField), '004281');
      await tester.tap(find.byType(ActionButton));
      await tester.pump();
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      write.complete();
      await tester.pumpAndSettle();
      expect(harness.store.writes, 1);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(paths, ['/api/v1/auth/register', '/api/v1/auth/register/verify']);
      expect(
        GoRouter.of(tester.element(find.byType(HomeScreen))).canPop(),
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Login saves session then opens Home', (tester) async {
    final harness = AuthTestHarness((_) async => success(sessionData(), 200));
    addTearDown(harness.close);
    await pumpStartup(
      tester,
      screen: 'sign-in',
      authRepository: harness.repository,
    );
    await tester.enterText(find.byType(TextField).first, 'FICTION001');
    await tester.enterText(find.byType(TextField).last, 'test password');
    await tester.tap(find.byType(ActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(harness.store.writes, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Token storage failure stays on login; switching clears password',
    (tester) async {
      final harness = AuthTestHarness((_) async => success(sessionData(), 200));
      harness.store.fail = true;
      addTearDown(harness.close);
      await pumpStartup(
        tester,
        screen: 'sign-in',
        authRepository: harness.repository,
      );
      await tester.enterText(find.byType(TextField).first, 'FICTION001');
      await tester.enterText(find.byType(TextField).last, 'test password');
      await tester.tap(find.byType(ActionButton));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('could not be saved securely'),
        findsOneWidget,
      );
      expect(find.byType(HomeScreen), findsNothing);
      await tester.ensureVisible(find.text('Sign up'));
      await tester.tap(find.text('Sign up'));
      await advanceTransition(tester);
      expect(
        tester
            .widget<TextField>(find.byType(TextField).last)
            .controller!
            .text
            .isEmpty,
        isTrue,
      );
      await tester.tap(find.byTooltip('Back'));
      await advanceTransition(tester);
      expect(find.text('Log in with SIS'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'External pending disables controls and external error is presented',
    (tester) async {
      final host = AuthUiController()
        ..pending = true
        ..formError = 'Please try again.';
      addTearDown(host.dispose);
      await pumpStartup(tester, screen: 'sign-in', host: host);
      expect(find.text('Please try again.'), findsOneWidget);
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.enabled, isFalse);
      }
      host.pending = false;
      host.formError = ' ';
      await tester.pump();
      expect(find.text('Please try again.'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Guest remains on entry without a connected action', (
    tester,
  ) async {
    await pumpStartup(tester, screen: 'getting-started');
    await tester.tap(find.text('Continue as guest'));
    await tester.pump();
    expect(find.text('Log in with SIS'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
