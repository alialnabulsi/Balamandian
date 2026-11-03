import 'package:balamandian/app.dart';
import 'package:balamandian/ui/onboarding/widgets/startup_flow.dart';
import 'package:balamandian/ui/onboarding/widgets/tour_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../startup_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadStartupFonts);
  testWidgets('A directly opened tour step is remembered by entry Back', (
    tester,
  ) async {
    await pumpStartup(tester, screen: 'assistant');
    await tester.tap(find.text('Get started'));
    await advanceTransition(tester);
    await tester.tap(find.byTooltip('Back to welcome tour'));
    await advanceTransition(tester);
    expect(find.text('Your Campus\nAssistant'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'Enabling reduced motion during a wipe completes the transition',
    (tester) async {
      await pumpStartup(tester, reduced: false);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await advanceTransition(tester);
      expect(find.text('Your people.\nYour campus.'), findsOneWidget);
      expect(
        StartupNavigation.of(tester.element(find.byType(TourScreen))).busy,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Splash advances automatically with reduced motion', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(const MainApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 25));
    await tester.pump();
    expect(find.text('Find your way.\nFeel at home.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Tour progression, progress navigation, swipe and system back', (
    tester,
  ) async {
    await pumpStartup(tester);
    await tester.tap(find.text('Continue'));
    await advanceTransition(tester);
    expect(find.text('Your people.\nYour campus.'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await advanceTransition(tester);
    expect(find.text('Your Campus\nAssistant'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await advanceTransition(tester);
    await tester.tap(find.byTooltip('Back to welcome tour'));
    await advanceTransition(tester);
    expect(find.text('Your Campus\nAssistant'), findsOneWidget);
    await tester.tap(find.byTooltip('Go to step 1: Find your way'));
    await advanceTransition(tester);
    expect(find.text('Find your way.\nFeel at home.'), findsOneWidget);
    await tester.fling(find.byType(TourScreen), const Offset(-200, 0), 500);
    await advanceTransition(tester);
    expect(find.text('Your people.\nYour campus.'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await advanceTransition(tester);
    expect(find.text('Find your way.\nFeel at home.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Curved transition locks repeated taps and advances one step', (
    tester,
  ) async {
    await pumpStartup(tester, reduced: false);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    final flow = find.byType(TourScreen);
    expect(StartupNavigation.of(tester.element(flow)).busy, isTrue);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Continue'), warnIfMissed: false);
    }
    await advanceTransition(tester);
    expect(find.text('Your people.\nYour campus.'), findsOneWidget);
    expect(
      GoRouter.of(tester.element(flow)).routeInformationProvider.value.uri.path,
      '/welcome/community',
    );
    expect(StartupNavigation.of(tester.element(flow)).busy, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
