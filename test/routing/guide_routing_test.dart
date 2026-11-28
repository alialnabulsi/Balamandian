import 'package:balamandian/app.dart';
import 'package:balamandian/routing/guide_ai_links.dart';
import 'package:balamandian/ui/guide/widgets/guide_home_screen.dart';
import 'package:balamandian/ui/guide/widgets/guide_markdown_body.dart';
import 'package:balamandian/ui/home/widgets/app_shell.dart';
import 'package:balamandian/ui/home/widgets/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../auth_test_support.dart';
import '../guide_test_support.dart';
import '../profile_test_support.dart';
import '../marketplace_test_support.dart';
import '../ui/startup_test_support.dart';

void main() {
  testWidgets(
    'default Guide replaces its placeholder inside Home and preserves AI/session guards',
    (tester) async {
      mockNativeSplash(tester);
      final auth = AuthTestHarness((_) async => success(sessionData(), 200));
      addTearDown(auth.close);
      await auth.repository.login('FICTION001', 'test');
      final guide = FakeGuideRepository();
      await tester.pumpWidget(
        MainApp(
          authRepository: auth.repository,
          guideRepository: guide,
          profileRepository: FakeProfileRepository(),
          marketplaceRepository: FakeMarketplaceRepository(),
          onboardingRepository: testOnboardingRepository(),
          externalUrls: FakeExternalUrlService(),
          initialLocation: '/',
        ),
      );
      await prepareAppSplash(tester);
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
      router.go('/guide');
      await tester.pumpAndSettle();
      expect(find.byType(GuideHomeScreen), findsOneWidget);
      expect(find.byType(AppShell), findsOneWidget);
      expect(router.canPop(), isTrue);
      router.push(guideArticleLocation(guideArticleId, citedVersion: 8));
      await tester.pumpAndSettle();
      expect(find.byType(GuideMarkdownBody), findsOneWidget);
      expect(
        find.textContaining('updated since the cited revision'),
        findsOneWidget,
      );
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(GuideHomeScreen), findsOneWidget);
      router.go('/ai');
      await tester.pumpAndSettle();
      expect(find.text('AI coming soon'), findsOneWidget);
      await auth.repository.logout(localOnly: true);
      await tester.pumpAndSettle();
      router.go(guideArticleLocation(guideArticleId));
      await tester.pumpAndSettle();
      expect(find.byType(GuideMarkdownBody), findsNothing);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/welcome/sign-in',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
}
