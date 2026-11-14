import '../marketplace_test_support.dart';

import 'package:balamandian/app.dart';
import 'package:balamandian/data/repositories/auth_repository.dart';
import 'package:balamandian/ui/auth/view_models/auth_ui_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth_test_support.dart';
export '../auth_test_support.dart' show testOnboardingRepository;

Future<void> prepareAppSplash(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 80)),
  );
  await tester.pump();
  await tester.pump();
}

AuthRepository noSessionRepository() {
  final harness = AuthTestHarness((request) async {
    fail('Unexpected API request: ${request.url.path}');
  });
  addTearDown(harness.close);
  return harness.repository;
}

Future<void> loadStartupFonts() async {
  final loader = FontLoader('Inter');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(
      rootBundle.load('assets/onboarding/fonts/Inter-$weight.ttf'),
    );
  }
  await loader.load();
}

// Widget tests have no Android overlay. Keep platform replies in the fake-async
// test zone; splash-specific tests override these with controlled acknowledgments.
void mockNativeSplash(WidgetTester tester) {
  const channel = MethodChannel('balamandian/splash');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    (_) async => null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    ),
  );
}

Future<void> pumpStartup(
  WidgetTester tester, {
  String screen = 'campus',
  Size size = const Size(412, 915),
  bool dark = false,
  bool reduced = true,
  AuthUiController? host,
  AuthRepository? authRepository,
  double textScale = 1,
  double keyboard = 0,
  FakeViewPadding padding = FakeViewPadding.zero,
  VoidCallback? onOnboardingCompleted,
}) async {
  mockNativeSplash(tester);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  tester.view.padding = padding;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reduced);
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
  await tester.pumpWidget(
    MainApp(
      marketplaceRepository: FakeMarketplaceRepository(),
      externalUrls: FakeExternalUrlService(),
      key: UniqueKey(),
      initialLocation: '/welcome/$screen',
      holdSplash: screen == 'splash',
      onboardingRepository: testOnboardingRepository(),
      onOnboardingCompleted: onOnboardingCompleted,
      authUi: host,
      authRepository: authRepository ?? noSessionRepository(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    ),
  );
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
  });
  await tester.pump();
  await tester.pump(const Duration(seconds: 3));
  await tester.pump();
  if (screen != 'splash') await advanceTransition(tester);
}

Future<void> advanceTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 25));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}
