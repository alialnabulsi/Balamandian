import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:balamandian/domain/models/pending_registration.dart';
import 'package:balamandian/routing/startup_destination.dart';
import 'package:balamandian/ui/auth/widgets/credentials_screen.dart';
import 'package:balamandian/ui/auth/widgets/otp_screen.dart';
import 'package:balamandian/ui/core/ui/action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../auth_test_support.dart';
import '../startup_test_support.dart';

Future<void> openOtp(
  WidgetTester tester,
  AuthTestHarness harness, {
  bool dark = false,
  Size size = const Size(412, 915),
  double textScale = 1,
  double keyboard = 0,
  int cooldown = 60,
  int lifetime = 600,
}) async {
  await pumpStartup(
    tester,
    screen: 'sign-up',
    authRepository: harness.repository,
    dark: dark,
    size: size,
    textScale: textScale,
    keyboard: keyboard,
  );
  GoRouter.of(tester.element(find.byType(CredentialsScreen))).go(
    StartupDestination.verifyEmail.path,
    extra: PendingRegistration.fromJson(
      pendingData(cooldown: cooldown, lifetime: lifetime),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 30));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadStartupFonts);

  testWidgets(
    'OTP validates six digits, filters pasted input and focuses invalid code',
    (tester) async {
      final harness = AuthTestHarness((_) async => failure('OTP_INVALID'));
      addTearDown(harness.close);
      await openOtp(tester, harness);
      await tester.tap(find.byType(ActionButton));
      await tester.pump();
      expect(
        find.text('Enter the six-digit code from your university email.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
      await tester.enterText(find.byType(TextField), '00a428199');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text ==
            '004281',
        isTrue,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(
        find.text('That code is incorrect. Please try again.'),
        findsOneWidget,
      );
      expect(find.byType(OtpScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Resend displays progress, suppresses duplicate taps and clears old code',
    (tester) async {
      var calls = 0;
      final reply = Completer<http.Response>();
      final harness = AuthTestHarness((request) {
        calls++;
        return reply.future;
      });
      addTearDown(harness.close);
      await openOtp(tester, harness, cooldown: 0);
      await tester.enterText(find.byType(TextField), '004281');
      await tester.tap(find.text('Resend code'));
      await tester.tap(find.text('Resend code'));
      await tester.pump();
      expect(find.text('Sending code…'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      reply.complete(success(pendingData(cooldown: 43), 202));
      await tester.pump();
      expect(calls, 1);
      expect(
        tester
            .widget<TextField>(find.byType(TextField))
            .controller!
            .text
            .isEmpty,
        isTrue,
      );
      expect(find.textContaining('latest email'), findsOneWidget);
      expect(find.text('Resend code in 43s'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Expired code disables verification and offers resend', (
    tester,
  ) async {
    final harness = AuthTestHarness((_) async => success(pendingData(), 202));
    addTearDown(harness.close);
    await openOtp(tester, harness, lifetime: -1, cooldown: 0);
    expect(find.textContaining('Your code has expired.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.text('Resend code'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Delivery cooldown does not block verifying an existing code', (
    tester,
  ) async {
    final harness = AuthTestHarness(
      (_) async => failure('OTP_COOLDOWN', status: 429, retryAfter: 19),
    );
    addTearDown(harness.close);
    await openOtp(tester, harness, cooldown: 0);
    await tester.tap(find.text('Resend code'));
    await tester.pump();
    expect(find.text('Resend code in 19s'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Expired registration and consumed verification storage failure offer recovery',
    (tester) async {
      final harness = AuthTestHarness((_) async => success(sessionData(), 201));
      harness.store.fail = true;
      addTearDown(harness.close);
      await openOtp(tester, harness);
      await tester.enterText(find.byType(TextField), '004281');
      await tester.tap(find.byType(ActionButton));
      await tester.pump();
      expect(find.textContaining('Your email is verified'), findsOneWidget);
      expect(find.text('Log in'), findsOneWidget);
      await tester.tap(find.byType(ActionButton));
      await advanceTransition(tester);
      expect(find.text('Welcome back'), findsOneWidget);
      GoRouter.of(tester.element(find.byType(CredentialsScreen)))
          .go(StartupDestination.verifyEmail.path);
      await tester.pump();
      expect(find.text('Start again'), findsOneWidget);
      await tester.tap(find.byType(ActionButton));
      await advanceTransition(tester);
      expect(find.text('Create your account'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final variant in ['light', 'dark', 'narrow-keyboard']) {
    testWidgets('OTP $variant layout, accessibility and capture', (
      tester,
    ) async {
      final harness = AuthTestHarness((_) async => failure('OTP_INVALID'));
      addTearDown(harness.close);
      final narrow = variant == 'narrow-keyboard';
      final size = narrow ? const Size(320, 640) : const Size(412, 915);
      await openOtp(
        tester,
        harness,
        dark: variant == 'dark',
        size: size,
        textScale: narrow ? 2 : 1,
        keyboard: narrow ? 280 : 0,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Verify email'));
      await tester.pump();
      expect(find.text('Verify email').hitTestable(), findsOneWidget);
      if (!narrow) {
        final semantics = tester.ensureSemantics();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      }
      await tester.runAsync(() async {
        RenderRepaintBoundary? boundary;
        void visit(RenderObject object) {
          if (boundary != null) return;
          if (object is RenderRepaintBoundary && object.size == size) {
            boundary = object;
            return;
          }
          object.visitChildren(visit);
        }

        visit(tester.binding.renderViews.single);
        final rendered = await boundary!.toImage(pixelRatio: 1);
        final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/ui-verification/auth/otp-$variant.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        rendered.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
