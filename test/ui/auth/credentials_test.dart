import 'package:balamandian/ui/auth/view_models/auth_ui_controller.dart';
import 'package:balamandian/ui/auth/widgets/credentials_screen.dart';
import 'package:balamandian/ui/core/ui/action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../startup_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadStartupFonts);
  testWidgets(
    'Accessible controls are labeled and meet Android touch targets',
    (tester) async {
      await pumpStartup(tester, screen: 'sign-in');
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp('Email or SIS ID')), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('Password')), findsWidgets);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final signup in [false, true]) {
    testWidgets(
      '${signup ? 'Sign up' : 'Sign in'} validates, reveals, submits once and clears password',
      (tester) async {
        var calls = 0;
        String? identifier;
        void receive(Credentials value) {
          calls++;
          identifier = value.identifier;
          expect(value.password, 'entered password');
        }

        final host = AuthUiController(onSignIn: receive, onSignUp: receive);
        addTearDown(host.dispose);
        await pumpStartup(
          tester,
          screen: signup ? 'sign-up' : 'sign-in',
          host: host,
        );
        final submit = find.byType(ActionButton);
        await tester.tap(submit);
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
        await tester.enterText(
          find.byType(TextField).first,
          '  entered identifier  ',
        );
        await tester.enterText(find.byType(TextField).last, 'entered password');
        await tester.tap(find.byTooltip('Show password'));
        await tester.pump();
        expect(
          tester.widget<TextField>(find.byType(TextField).last).obscureText,
          isFalse,
        );
        await tester.tap(submit);
        await tester.tap(submit);
        await tester.pump();
        expect(calls, 1);
        expect(identifier, 'entered identifier');
        expect(
          tester
              .widget<TextField>(find.byType(TextField).last)
              .controller!
              .text,
          isEmpty,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField).last).obscureText,
          isTrue,
        );
        expect(find.byType(CredentialsScreen), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('Pending disables controls and external error is presented', (
    tester,
  ) async {
    final host = AuthUiController()
      ..pending = true
      ..formError = 'Please try again.';
    addTearDown(host.dispose);
    await pumpStartup(tester, screen: 'sign-in', host: host);
    expect(find.text('Please wait…'), findsOneWidget);
    expect(find.text('Please try again.'), findsOneWidget);
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.enabled, isFalse);
    }
    host.pending = false;
    host.formError = ' ';
    await tester.pump();
    expect(find.text('Please try again.'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).enabled,
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'Switching clears sensitive input; default host never authenticates',
    (tester) async {
      await pumpStartup(tester, screen: 'sign-in');
      await tester.enterText(find.byType(TextField).first, 'identifier');
      await tester.enterText(find.byType(TextField).last, 'password');
      await tester.tap(find.byType(ActionButton));
      await tester.pump();
      expect(find.textContaining('No service is connected.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'another password');
      await tester.ensureVisible(find.text('Sign up'));
      await tester.tap(find.text('Sign up'));
      await advanceTransition(tester);
      expect(find.text('Create your account'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        isEmpty,
      );
      await tester.tap(find.byTooltip('Back'));
      await advanceTransition(tester);
      expect(find.text('Log in with SIS'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Guest emits callback and remains on entry', (tester) async {
    var calls = 0;
    final host = AuthUiController(onGuest: () => calls++);
    addTearDown(host.dispose);
    await pumpStartup(tester, screen: 'getting-started', host: host);
    await tester.tap(find.text('Continue as guest'));
    await tester.pump();
    expect(calls, 1);
    expect(find.text('Log in with SIS'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
