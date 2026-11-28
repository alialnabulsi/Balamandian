import '../profile_test_support.dart';
import '../marketplace_test_support.dart';
import '../guide_test_support.dart';

import 'package:balamandian/app.dart';
import 'package:balamandian/domain/models/guide_article_ref.dart';
import 'package:balamandian/routing/guide_ai_links.dart';
import 'package:balamandian/ui/core/themes/app_theme.dart';
import 'package:balamandian/ui/home/widgets/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../auth_test_support.dart';
import '../ui/startup_test_support.dart' show prepareAppSplash;
import '../ui/home/home_shell_test.dart' show loadHomeFonts;

void main() {
  setUpAll(loadHomeFonts);
  testWidgets('Home and theme load, and navigation survives an app rebuild', (
    tester,
  ) async {
    const channel = MethodChannel('balamandian/splash');
    final splashCalls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      splashCalls.add(call.method);
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final appKey = GlobalKey();
    final harness = AuthTestHarness((_) async => success(sessionData(), 200));
    addTearDown(harness.close);
    await harness.repository.login('FICTION001', 'test');
    await tester.pumpWidget(
      MainApp(
        profileRepository: FakeProfileRepository(),
        marketplaceRepository: FakeMarketplaceRepository(),
        externalUrls: FakeExternalUrlService(),
        key: appKey,
        guideRepository: FakeGuideRepository(),
        initialLocation: '/',
        themeMode: ThemeMode.light,
        authRepository: harness.repository,
        onboardingRepository: testOnboardingRepository(),
      ),
    );
    await prepareAppSplash(tester);
    await tester.pumpAndSettle();

    final home = find.byType(HomeScreen);
    expect(home, findsOneWidget);
    expect(splashCalls, containsAllInOrder(['prepare', 'reveal']));
    expect(find.text('Community feed coming soon'), findsOneWidget);
    expect(Theme.of(tester.element(home)).colorScheme, appTheme.colorScheme);

    final router = GoRouter.of(tester.element(home));
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(router.canPop(), isFalse);

    router.go('/?source=route-check');
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MainApp(
        profileRepository: FakeProfileRepository(),
        marketplaceRepository: FakeMarketplaceRepository(),
        externalUrls: FakeExternalUrlService(),
        key: appKey,
        initialLocation: '/',
        themeMode: ThemeMode.light,
        authRepository: harness.repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(home, findsOneWidget);
    expect(GoRouter.of(tester.element(home)), same(router));
    expect(
      router.routeInformationProvider.value.uri.query,
      'source=route-check',
    );

    router.go('/guide');
    await tester.pumpAndSettle();
    expect(find.text('University Guide'), findsOneWidget);
    router.go('/ai');
    await tester.pumpAndSettle();
    expect(find.text('Balamandian AI'), findsOneWidget);
    expect(find.text('What would you like to know?'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('optional Guide and AI routes each replace their own placeholder', (
    tester,
  ) async {
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
    final harness = AuthTestHarness((_) async => success(sessionData(), 200));
    addTearDown(harness.close);
    await harness.repository.login('FICTION001', 'test');
    const article = GuideArticleRef(
      articleId: '688cc525-e178-49e7-8bdb-826d272a62ab',
      version: 4,
      title: 'Article',
    );
    await tester.pumpWidget(
      MainApp(
        profileRepository: FakeProfileRepository(),
        marketplaceRepository: FakeMarketplaceRepository(),
        authRepository: harness.repository,
        onboardingRepository: testOnboardingRepository(),
        initialLocation: '/',
        guideRoute: GoRoute(
          path: 'guide',
          builder: (_, _) => const Text('Guide fixture'),
          routes: [
            GoRoute(
              path: 'articles/:articleId',
              builder: (_, state) => Text(
                '${state.pathParameters['articleId']} v${state.uri.queryParameters['rev']}',
              ),
            ),
          ],
        ),
        aiRoute: GoRoute(
          path: 'ai',
          builder: (_, state) =>
              Text('Context ${state.uri.queryParameters['articleId']}'),
        ),
      ),
    );
    await prepareAppSplash(tester);
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    router.go(guideCitationLocation(article));
    await tester.pumpAndSettle();
    expect(find.text('${article.articleId} v4'), findsOneWidget);
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Guide fixture'), findsOneWidget);
    router.go(aiLocation(articleId: article.articleId));
    await tester.pumpAndSettle();
    expect(find.text('Context ${article.articleId}'), findsOneWidget);
    expect(router.canPop(), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
