import '../../marketplace_test_support.dart';

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
  testWidgets(
    'Finishing the tour emits once; entry has no path back to onboarding',
    (tester) async {
      var completions = 0;
      await pumpStartup(
        tester,
        screen: 'assistant',
        onOnboardingCompleted: () => completions++,
      );
      await tester.tap(find.text('Get started'));
      await tester.tap(find.text('Get started'), warnIfMissed: false);
      await advanceTransition(tester);
      expect(completions, 1);
      expect(find.byTooltip('Back to welcome tour'), findsNothing);
      await tester.binding.handlePopRoute();
      await advanceTransition(tester);
      expect(find.text('Log in with SIS'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
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
    mockNativeSplash(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(
      MainApp(
        marketplaceRepository: FakeMarketplaceRepository(),
        externalUrls: FakeExternalUrlService(),
        authRepository: noSessionRepository(),
        onboardingRepository: testOnboardingRepository(),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
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
  testWidgets('Assistant fits the primary Android viewport with safe areas', (
    tester,
  ) async {
    await pumpStartup(
      tester,
      screen: 'assistant',
      padding: const FakeViewPadding(top: 50, bottom: 24),
    );
    final button = find.text('Get started');
    expect(button.hitTestable(), findsOneWidget);
    expect(tester.getBottomRight(button).dy, lessThan(915 - 24));
    expect(find.text('Your campus companion'), findsNothing);
    expect(find.text('Ask your campus\nassistant'), findsNothing);
    expect(find.text('Where can I apply for financial aid?'), findsOneWidget);
    expect(
      find.text("You can apply online through the University's"),
      findsOneWidget,
    );
    expect(find.text('Financial Aid Application.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Assistant action fits the connected Samsung viewport', (
    tester,
  ) async {
    await pumpStartup(
      tester,
      screen: 'assistant',
      size: const Size(384, 832),
      padding: const FakeViewPadding(top: 29, bottom: 24),
    );
    expect(find.text('Get started').hitTestable(), findsOneWidget);
    expect(tester.getBottomRight(find.text('Get started')).dy, lessThan(808));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
