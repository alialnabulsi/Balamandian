import 'package:balamandian/app.dart';
import 'package:balamandian/domain/models/auth_session.dart';
import 'package:balamandian/ui/home/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../auth_test_support.dart';
import '../../marketplace_test_support.dart';
import '../startup_test_support.dart';

Future<void> pumpMarketplace(
  WidgetTester tester, {
  required FakeMarketplaceRepository repository,
  FakeExternalUrlService? external,
  bool dark = false,
  Size size = const Size(390, 844),
  double textScale = 1,
  String location = '/market',
}) async {
  mockNativeSplash(tester);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
  final auth = AuthTestHarness((r) async {
    if (r.url.path.endsWith('login')) return success(sessionData(), 200);
    fail('Unexpected authentication network request: ${r.url.path}');
  });
  addTearDown(auth.close);
  await auth.repository.login('FICTION001', 'test');
  expect(auth.repository.status, SessionStatus.authenticated);
  await tester.pumpWidget(
    MainApp(
      authRepository: auth.repository,
      marketplaceRepository: repository,
      externalUrls: external ?? FakeExternalUrlService(),
      onboardingRepository: testOnboardingRepository(),
      initialLocation: location,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    ),
  );
  await prepareAppSplash(tester);
  await tester.pumpAndSettle();
}

GoRouter marketplaceRouter(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(AppShell)));
