import 'package:balamandian/app.dart';
import 'package:balamandian/domain/models/ai_conversation.dart';
import 'package:balamandian/domain/models/guide_article_ref.dart';
import 'package:balamandian/routing/guide_ai_links.dart';
import 'package:balamandian/ui/ai_assistant/widgets/ai_assistant_screen.dart';
import 'package:balamandian/ui/guide/widgets/guide_home_screen.dart';
import 'package:balamandian/ui/guide/widgets/guide_markdown_body.dart';
import 'package:balamandian/ui/home/widgets/app_shell.dart';
import 'package:balamandian/ui/home/widgets/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../ai_assistant/ai_fixture.dart';
import '../auth_test_support.dart';
import '../guide_test_support.dart';
import '../profile_test_support.dart';
import '../marketplace_test_support.dart';
import '../ui/startup_test_support.dart';

void main() {
  testWidgets(
    'Guide and AI link to each other inside Home and require a session',
    (tester) async {
      mockNativeSplash(tester);
      final auth = AuthTestHarness((_) async => success(sessionData(), 200));
      addTearDown(auth.close);
      await auth.repository.login('FICTION001', 'test');
      final guide = FakeGuideRepository();
      final ai = FixtureAiRepository()
        ..threads[chatId] = [
          fixtureTurn(
            1,
            'Where are the official academic dates?',
            'See the academic calendar. [1]',
            citations: [
              AiCitation(
                const GuideArticleRef(
                  articleId: guideArticleId,
                  version: 8,
                  title: 'Academic calendar',
                ),
                null,
                AiAvailability.updated,
                citedSources.first.source,
              ),
            ],
          ),
        ];
      await tester.pumpWidget(
        MainApp(
          authRepository: auth.repository,
          guideRepository: guide,
          aiRepository: ai,
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
      router.push(guideArticleLocation(guideArticleId));
      await tester.pumpAndSettle();
      expect(find.byType(GuideMarkdownBody), findsOneWidget);
      await tester.tap(find.text('Ask AI'));
      await tester.pumpAndSettle();
      final assistant = find.byType(AiAssistantScreen);
      expect(
        tester.widget<AiAssistantScreen>(assistant).articleId,
        guideArticleId,
      );
      expect(find.text('Guide article attached'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'When does registration open?',
      );
      expect(ai.created, 0);
      expect(ai.requests, isEmpty);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(GuideMarkdownBody), findsOneWidget);

      router.go(aiConversationLocation(chatId));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Source 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open in University Guide'));
      await tester.pumpAndSettle();
      expect(find.byType(GuideMarkdownBody), findsOneWidget);
      expect(
        find.textContaining('updated since the cited revision'),
        findsOneWidget,
      );
      router.pop();
      await tester.pumpAndSettle();
      expect(
        tester.widget<AiAssistantScreen>(assistant).conversationId,
        chatId,
      );

      await auth.repository.logout(localOnly: true);
      await tester.pumpAndSettle();
      router.go(aiConversationLocation(chatId));
      await tester.pumpAndSettle();
      expect(assistant, findsNothing);
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
