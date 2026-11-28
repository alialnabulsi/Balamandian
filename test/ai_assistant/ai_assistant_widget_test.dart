import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:balamandian/app.dart';
import 'package:balamandian/domain/models/ai_conversation.dart';
import 'package:balamandian/routing/guide_ai_links.dart';
import 'package:balamandian/ui/ai_assistant/view_models/ai_assistant_view_model.dart';
import 'package:balamandian/ui/ai_assistant/widgets/ai_assistant_screen.dart';
import 'package:balamandian/ui/ai_assistant/widgets/ai_markdown.dart';
import 'package:balamandian/ui/ai_assistant/widgets/ai_markdown_document.dart';
import 'package:balamandian/ui/core/themes/app_theme.dart';
import 'package:balamandian/ui/core/ui/brand.dart';
import 'package:balamandian/ui/home/widgets/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../auth_test_support.dart';
import '../marketplace_test_support.dart';
import '../profile_test_support.dart';
import '../ui/startup_test_support.dart';
import 'ai_fixture.dart';

const capture = bool.fromEnvironment('CAPTURE_UI');
const fallback = 'AiEvidenceArabic';

Future<void> screenshot(
  WidgetTester tester,
  GlobalKey boundary,
  String name,
) async {
  if (!capture) return;
  await tester.runAsync(() async {
    final context = tester.element(find.byType(UniversityCrest).first);
    await precacheImage(AssetImage(StartupAssets.image('uob-logo')), context);
  });
  await tester.pump();
  await tester.runAsync(() async {
    final image =
        await (boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 1.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('build/ai-verification/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
  });
}

class _Host {
  _Host(this.repo, this.auth, this.model, this.router, this.boundary);
  final FixtureAiRepository repo;
  final AuthTestHarness auth;
  final AiAssistantViewModel model;
  final GoRouter router;
  final GlobalKey boundary;
}

Future<_Host> _host(
  WidgetTester tester, {
  String location = '/ai',
  FixtureAiRepository? fixtures,
  bool guide = false,
  Size size = const Size(390, 844),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
  final auth = AuthTestHarness((request) async {
    final data = sessionData();
    if (request.url.path.endsWith('/login') &&
        jsonDecode(request.body)['identifier'] == 'other') {
      final user = data['user'] as Map<String, Object>;
      user['id'] = '22222222-2222-4222-8222-222222222222';
      user['sisUserId'] = 'FICTION002';
    }
    return success(data, 200);
  });
  await auth.repository.login('F', 'test');
  final repo = fixtures ?? FixtureAiRepository();
  final model = AiAssistantViewModel(repo, auth.repository);
  final boundary = GlobalKey();
  final router = GoRouter(
    initialLocation: location,
    routes: [
      ShellRoute(
        builder: (_, _, child) => Scaffold(body: SafeArea(child: child)),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const SizedBox.shrink(),
            routes: [
              aiAssistantRoute(
                model: model,
                externalUrls: FakeExternalUrlService(),
                guideAvailable: guide,
              ),
              if (guide)
                GoRoute(
                  path: 'guide/articles/:articleId',
                  builder: (_, state) => Text(
                    'Guide revision ${state.uri.queryParameters['rev']}',
                  ),
                ),
            ],
          ),
        ],
      ),
    ],
  );
  addTearDown(() {
    router.dispose();
    model.dispose();
    auth.close();
  });
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: MaterialApp.router(
        theme: capture
            ? appTheme.copyWith(
                textTheme: appTheme.textTheme.apply(
                  fontFamilyFallback: const [fallback],
                ),
              )
            : appTheme,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Host(repo, auth, model, router, boundary);
}

void main() {
  setUpAll(() async {
    if (!capture) return;
    await loadStartupFonts();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final font = File('C:/Windows/Fonts/segoeui.ttf');
    if (font.existsSync()) {
      await (FontLoader(fallback)..addFont(
            Future.value(ByteData.sublistView(font.readAsBytesSync())),
          ))
          .load();
    }
  });

  testWidgets('welcome capture and suggestion opens an editable draft', (
    tester,
  ) async {
    final ui = await _host(tester);
    await screenshot(tester, ui.boundary, '00-welcome');
    await tester.tap(find.text('How do I request an official transcript?'));
    await tester.pumpAndSettle();
    expect(ui.model.draft, 'How do I request an official transcript?');
    expect(ui.repo.requests, isEmpty);
  });

  testWidgets(
    'welcome, context, mixed input and keyboard at small dimensions',
    (tester) async {
      final ui = await _host(
        tester,
        location: aiLocation(articleId: articleId),
        size: const Size(320, 654),
      );
      expect(find.text('Balamandian AI'), findsOneWidget);
      expect(find.text('Guide article attached'), findsOneWidget);
      expect(ui.repo.created, 0);
      await screenshot(tester, ui.boundary, '01-welcome-guide-context');
      await tester.tap(find.byTooltip('Remove Guide article context'));
      await tester.pump();
      expect(find.text('Guide article attached'), findsNothing);
      await tester.enterText(find.byType(TextField), arabicQuestion);
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).textDirection,
        TextDirection.rtl,
      );
      expect(
        tester.getBottomRight(find.byType(TextField)).dy,
        lessThan(654 - 250),
      );
      await screenshot(
        tester,
        ui.boundary,
        '02-small-arabic-composer-keyboard-inset',
      );
      tester.view.resetViewInsets();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(ui.repo.requests.single.context, isNull);
      expect(ui.repo.requests.single.locale, 'ar');
      expect(ui.repo.requests.single.text, arabicQuestion);
      expect(
        ui.router.routeInformationProvider.value.uri.path,
        aiConversationLocation(chatId),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'streaming, saved English answer, copy, feedback, and cited revision navigation',
    (tester) async {
      final ui = await _host(tester, guide: true);
      await tester.enterText(
        find.byType(TextField),
        'How do I request a transcript?',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(ui.repo.created, 1);
      expect(ui.repo.requests.single.locale, 'en');
      final run = ui.repo.requests.single;
      run.start();
      run.delta('Contact the **Office of the Reg');
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump();
      expect(
        find.textContaining('Office of the Reg', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('**Office', findRichText: true), findsNothing);
      expect(await ui.model.send('en'), isNull);
      await screenshot(tester, ui.boundary, '03-streaming');
      ui.repo.complete(englishAnswer, citations: citedSources.take(1).toList());
      await tester.pumpAndSettle();
      expect(
        find.text('Official transcript', findRichText: true),
        findsOneWidget,
      );
      expect(find.byTooltip('Source 1'), findsOneWidget);
      await screenshot(tester, ui.boundary, '04-english-answer');
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.tap(find.byTooltip('Copy answer'));
      expect(copied, englishAnswer);
      await tester.tap(find.byTooltip('Good answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Poor answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Poor answer'));
      await tester.pumpAndSettle();
      expect(ui.repo.votes, [
        (chatId, run.ids.assistant, 1),
        (chatId, run.ids.assistant, -1),
        (chatId, run.ids.assistant, null),
      ]);
      await tester.tap(find.byTooltip('Source 1'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cited revision 4'), findsOneWidget);
      await tester.tap(find.text('Open in University Guide'));
      await tester.pumpAndSettle();
      expect(find.text('Guide revision 4'), findsOneWidget);
    },
  );

  testWidgets(
    'mixed Markdown, Arabic numbered list and table, updated and unavailable sources',
    (tester) async {
      final unavailable = AiCitation(
        citedSources.first.article,
        null,
        AiAvailability.unavailable,
        null,
      );
      final repo = FixtureAiRepository()
        ..threads[chatId] = [
          fixtureTurn(
            1,
            arabicQuestion,
            mixedAnswer,
            citations: [citedSources.last, unavailable],
          ),
        ];
      final ui = await _host(
        tester,
        location: aiConversationLocation(chatId),
        fixtures: repo,
        size: const Size(390, 1000),
      );
      final list = find.byType(CustomScrollView);
      await tester.drag(list, const Offset(0, 1200));
      await tester.pumpAndSettle();
      final arabic = tester.widget<RichText>(
        find.textContaining('إذا كنت بحاجة إلى', findRichText: true),
      );
      expect(arabic.textDirection, TextDirection.rtl);
      final marker = find.text('١.');
      final line = find.text('افتح صفحة المسجّل.', findRichText: true);
      expect(
        tester.getCenter(marker).dx,
        greaterThan(tester.getCenter(line).dx),
      );
      expect(find.byType(Table), findsOneWidget);
      await screenshot(tester, ui.boundary, '05-arabic-mixed-list-table');
      final tableScroll = find
          .ancestor(
            of: find.byType(Table),
            matching: find.byType(SingleChildScrollView),
          )
          .first;
      expect(
        tester.widget<SingleChildScrollView>(tableScroll).scrollDirection,
        Axis.horizontal,
      );
      await tester.drag(list, const Offset(0, -950));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RichText>(
              find.textContaining('For help with delivery', findRichText: true),
            )
            .textDirection,
        TextDirection.ltr,
      );
      await screenshot(tester, ui.boundary, '06-multiple-sources');
      await tester.tap(find.text('Student forms'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Article updated since this answer'),
        findsOneWidget,
      );
      expect(find.text('Open in University Guide'), findsNothing);
      expect(find.text('Open official source'), findsOneWidget);
      ui.router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar services'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cited revision 4'), findsOneWidget);
      expect(find.text('Open official source'), findsNothing);
    },
  );

  testWidgets(
    'history pages, opens saved conversation, loads older, renames and deletes with confirmation',
    (tester) async {
      final repo = FixtureAiRepository()
        ..items.addAll([
          AiConversation(
            chatId,
            'Registrar questions',
            DateTime.utc(2026, 12, 3),
          ),
          AiConversation(
            otherChatId,
            'Library visit',
            DateTime.utc(2026, 12, 2),
          ),
        ])
        ..threads[chatId] = [fixtureTurn(2, 'Latest question', 'Latest answer')]
        ..older[chatId] = [
          fixtureTurn(1, 'Earlier question', 'Earlier answer'),
        ];
      final ui = await _host(tester, fixtures: repo);
      await tester.tap(find.byTooltip('Conversation history'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Load more conversations'));
      await tester.pumpAndSettle();
      expect(repo.historyCursors, [null, 'history-cursor']);
      expect(find.text('Library visit'), findsOneWidget);
      await screenshot(tester, ui.boundary, '07-history');
      await tester.tap(find.text('Registrar questions'));
      await tester.pumpAndSettle();
      expect(find.text('Latest question'), findsOneWidget);
      await tester.tap(find.text('Load earlier messages'));
      await tester.pumpAndSettle();
      expect(repo.fetched, contains((chatId, 'turn-cursor')));
      expect(ui.model.turns.map((turn) => turn.number), [1, 2]);
      await tester.tap(find.byTooltip('Conversation history'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Conversation options').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        'Transcript requests',
      );
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Transcript requests'), findsOneWidget);
      await tester.tap(find.byTooltip('Conversation options').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(repo.items.map((item) => item.id), contains(chatId));
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(repo.items.map((item) => item.id), isNot(contains(chatId)));
      expect(ui.router.routeInformationProvider.value.uri.path, '/ai');
    },
  );

  testWidgets(
    'interruption checks canonical state, then regeneration can be stopped',
    (tester) async {
      final ui = await _host(tester);
      await tester.enterText(find.byType(TextField), 'Where is the library?');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      final original = ui.repo.requests.single;
      original.start();
      original.delta('Provisional response');
      ui.repo.generationFailure = const AiFailure('OFFLINE');
      original.interrupt();
      await tester.pumpAndSettle();
      expect(find.text('Check saved answer'), findsOneWidget);
      expect(
        find.text('Provisional response', findRichText: true),
        findsNothing,
      );
      expect(ui.repo.requests, hasLength(1));
      await screenshot(tester, ui.boundary, '08-interrupted');
      ui.repo.generationFailure = null;
      ui.repo.saved = AiGeneration(
        original.ids,
        AiStatus.completed,
        'Recovered from history.',
        const [],
        null,
      );
      await tester.tap(find.text('Check saved answer'));
      await tester.pumpAndSettle();
      expect(
        find.text('Recovered from history.', findRichText: true),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Regenerate answer'));
      await tester.pump();
      final regenerated = ui.repo.requests.last;
      expect(regenerated.regenerate, original.ids.user);
      expect(regenerated.key, isNot(original.key));
      regenerated.start();
      await tester.tap(find.byTooltip('Stop generation'));
      await tester.pumpAndSettle();
      expect(regenerated.aborted, isTrue);
      expect(ui.repo.cancellations, [regenerated.ids.generation]);
      expect(
        find.text('Recovered from history.', findRichText: true),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'rate limit is recoverable and logout clears the view and aborts the connection',
    (tester) async {
      final ui = await _host(
        tester,
        location: aiLocation(articleId: articleId),
      );
      ui.repo.sendFailure = const AiFailure(
        'RATE_LIMITED',
        httpStatus: 429,
        retryAfter: Duration(seconds: 15),
      );
      await tester.enterText(
        find.byType(TextField),
        'When does the semester start?',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(find.textContaining('15 seconds'), findsOneWidget);
      expect(ui.model.draft, 'When does the semester start?');
      expect(ui.repo.requests.single.context, articleId);
      await screenshot(tester, ui.boundary, '09-rate-limit');
      ui.repo.sendFailure = null;
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      final active = ui.repo.requests.last;
      active.start();
      active.delta('Private draft');
      await ui.auth.repository.logout(localOnly: true);
      await tester.pumpAndSettle();
      expect(active.aborted, isTrue);
      expect(ui.model.draft, isEmpty);
      expect(ui.model.turns, isEmpty);
      expect(ui.model.history, isEmpty);
      expect(ui.model.contextArticleId, isNull);
      expect(find.text('Private draft', findRichText: true), findsNothing);
      await ui.auth.repository.login('other', 'test');
      await tester.pumpAndSettle();
      expect(ui.auth.repository.user?.sisUserId, 'FICTION002');
      expect(ui.router.routeInformationProvider.value.uri.path, '/ai');
      expect(find.text('When does the semester start?'), findsNothing);
    },
  );

  testWidgets(
    'safe Markdown links, code copy and emphasis, with inert generated HTML',
    (tester) async {
      final links = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiMarkdown(
              body:
                  '# Section\n\n**Bold**, *italic* and `ENGL 203`.\n\n---\n\n'
                  '[Official](https://example.edu/) [Unsafe](javascript:alert(1)) <script>\n\n'
                  '```text\nReference 203\n```',
              onLink: links.add,
            ),
          ),
        ),
      );
      expect(find.byType(Divider), findsNWidgets(2));
      expect(find.byTooltip('Copy code'), findsOneWidget);
      expect(
        find.textContaining('<script>', findRichText: true),
        findsOneWidget,
      );
      await tester.tap(find.text('Official'));
      expect(links.single, Uri.parse('https://example.edu/'));
      expect(find.byTooltip('javascript:'), findsNothing);
      expect(parseAiInline('***both***').single.kind, AiInlineKind.boldItalic);
    },
  );

  testWidgets(
    'stream growth keeps an earlier scroll position until jumping to latest',
    (tester) async {
      final repo = FixtureAiRepository()
        ..threads[chatId] = [
          for (var n = 1; n <= 14; n++)
            fixtureTurn(
              n,
              'Question $n',
              List.filled(10, 'Balamandian response $n.').join(' '),
            ),
        ];
      final ui = await _host(
        tester,
        location: aiConversationLocation(chatId),
        fixtures: repo,
      );
      await tester.enterText(find.byType(TextField), 'A follow-up question');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      final request = repo.requests.single..start();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 480));
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first;
      final before = tester.state<ScrollableState>(scrollable).position.pixels;
      request.delta(
        '## New information\n\n${List.filled(100, 'More information.').join(' ')}',
      );
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        closeTo(before, 1),
      );
      await tester.tap(find.byTooltip('Scroll to latest message'));
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(scrollable).position.extentAfter,
        lessThan(2),
      );
      expect(ui.repo.requests, hasLength(1));
    },
  );

  testWidgets(
    'a lost start checks history before a manual retransmit with the same key',
    (tester) async {
      final ui = await _host(tester, location: aiConversationLocation(chatId));
      await tester.enterText(
        find.byType(TextField),
        'What is the Registrar’s office?',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      final first = ui.repo.requests.single..interrupt();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(ui.repo.fetched.length, greaterThan(2));
      expect(ui.repo.requests, hasLength(1));
      await tester.tap(find.text('Retry delivery'));
      await tester.pumpAndSettle();
      expect(ui.repo.requests.last.key, first.key);
      expect(ui.repo.requests.last.text, first.text);
    },
  );

  testWidgets('Arabic-only conversation and canonical Arabic response', (
    tester,
  ) async {
    const question = 'أين أجد التقويم الجامعي؟';
    const answer =
        '## التقويم الجامعي\n\nيمكنك مراجعة دليل الجامعة للاطلاع على مواعيد التسجيل والعطل الرسمية.';
    final repo = FixtureAiRepository()
      ..threads[chatId] = [fixtureTurn(1, question, answer)];
    final ui = await _host(
      tester,
      location: aiConversationLocation(chatId),
      fixtures: repo,
    );
    final heading = tester.widget<RichText>(
      find.text('التقويم الجامعي', findRichText: true),
    );
    expect(heading.textDirection, TextDirection.rtl);
    await screenshot(tester, ui.boundary, '10-arabic-conversation');
  });

  testWidgets(
    'opening history after restart reconciles a previously streaming turn',
    (tester) async {
      const ids = AiGenerationIds(
        'saved-generation',
        'saved-user',
        'saved-answer',
      );
      final repo = FixtureAiRepository()
        ..threads[chatId] = [
          AiTurn(1, ids.user, 'Existing question', [
            AiAttempt(
              id: ids.assistant,
              generationId: ids.generation,
              number: 1,
              status: AiStatus.streaming,
            ),
          ]),
        ]
        ..saved = const AiGeneration(
          ids,
          AiStatus.completed,
          'Saved during restart.',
          [],
          null,
        );
      final ui = await _host(
        tester,
        location: aiConversationLocation(chatId),
        fixtures: repo,
      );
      expect(ui.repo.lookup, [ids.generation]);
      expect(ui.repo.requests, isEmpty);
      expect(
        find.text('Saved during restart.', findRichText: true),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'real app shell keeps quick actions clear of the keyboard-open composer',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 760);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearAllTestValues();
      });
      mockNativeSplash(tester);
      final auth = AuthTestHarness((_) async => success(sessionData(), 200));
      final profile = FakeProfileRepository();
      addTearDown(auth.close);
      addTearDown(profile.dispose);
      await auth.repository.login('F', 'test');
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MainApp(
            authRepository: auth.repository,
            aiRepository: FixtureAiRepository()
              ..threads[chatId] = [
                fixtureTurn(
                  1,
                  'How do I request a transcript?',
                  englishAnswer,
                  citations: [citedSources.first],
                ),
              ],
            profileRepository: profile,
            marketplaceRepository: FakeMarketplaceRepository(),
            externalUrls: FakeExternalUrlService(),
            onboardingRepository: testOnboardingRepository(),
            initialLocation: '/',
            themeMode: ThemeMode.light,
          ),
        ),
      );
      await prepareAppSplash(tester);
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.byType(HomeScreen)))
          .go(aiConversationLocation(chatId));
      await tester.pumpAndSettle();
      await screenshot(tester, boundary, '11-installed-app-shell');
      await tester.enterText(
        find.byType(TextField),
        'How do I visit the library?',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 265);
      await tester.pumpAndSettle();
      final submit = tester.getRect(find.byTooltip('Send message'));
      final quickActions = tester.getRect(find.byTooltip('Open quick actions'));
      expect(submit.overlaps(quickActions), isFalse);
      expect(submit.bottom, lessThan(760 - 265));
    },
  );
}
