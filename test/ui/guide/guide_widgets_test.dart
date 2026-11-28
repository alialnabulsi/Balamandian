import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:balamandian/ui/core/themes/app_theme.dart';
import 'package:balamandian/ui/core/ui/loading/skeleton.dart';
import 'package:balamandian/ui/guide/guide_routes.dart';
import 'package:balamandian/ui/guide/view_models/guide_session.dart';
import 'package:balamandian/ui/guide/widgets/guide_article_metadata.dart';
import 'package:balamandian/ui/guide/widgets/guide_markdown_body.dart';
import 'package:balamandian/ui/guide/widgets/guide_search_screen.dart';
import 'package:balamandian/ui/guide/widgets/guide_saved_screen.dart';
import 'package:balamandian/domain/models/guide_models.dart';
import 'package:balamandian/routing/guide_ai_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../auth_test_support.dart';
import '../../guide_test_support.dart';
import '../home/home_shell_test.dart' show loadHomeFonts;
import 'guide_view_models_test.dart' show RecordingGuideUrls;

void main() {
  late AuthTestHarness auth;
  late FakeGuideRepository repository;
  late GuideSession session;
  late RecordingGuideUrls urls;
  late GoRouter router;
  final boundary = GlobalKey();
  var arabicTestFont = false;
  setUpAll(() async {
    await loadHomeFonts();
    // Flutter's desktop test engine does not inherit Android's Arabic system fonts.
    // A locally installed test-only fallback avoids misleading missing-glyph captures.
    final configured = Platform.environment['GUIDE_ARABIC_TEST_FONT'];
    final path =
        configured ??
        (Platform.isWindows
            ? '${Platform.environment['WINDIR'] ?? 'C:\\Windows'}\\Fonts\\arial.ttf'
            : '');
    if (path.isNotEmpty && await File(path).exists()) {
      final bytes = await File(path).readAsBytes();
      await (FontLoader(
        'GuideArabicTest',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      arabicTestFont = true;
    }
  });
  setUp(() async {
    auth = AuthTestHarness((_) async => success(sessionData(), 200));
    await auth.repository.login('FICTION001', 'test');
    repository = FakeGuideRepository();
    session = GuideSession(auth: auth.repository, repository: repository);
    urls = RecordingGuideUrls();
  });
  tearDown(() {
    session.dispose();
    auth.close();
  });
  Future<void> pumpGuide(
    WidgetTester tester, {
    String location = '/guide',
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearAllTestValues();
    });
    router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Existing Home')),
          routes: [createGuideRoute(session: session, externalUrls: urls)],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: appTheme.copyWith(
            textTheme: appTheme.textTheme.apply(
              fontFamilyFallback: arabicTestFont
                  ? const ['GuideArabicTest']
                  : null,
            ),
          ),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('GUIDE_SCREENSHOTS')) return;
    if (name == 'article-arabic' && !arabicTestFont) return;
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await render.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('Docs/Images/guide-$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('home shows loading then dynamic sections; no article prefetch', (
    tester,
  ) async {
    final wait = Completer<List<GuideSection>>();
    repository.onSections = (_) => wait.future;
    await pumpGuide(tester);
    expect(find.byType(SkeletonGroup), findsOneWidget);
    expect(repository.articleCalls, 0);
    wait.complete([GuideSection.fromJson(guideSectionJson())]);
    await tester.pumpAndSettle();
    expect(find.text('University Guide'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Saved articles'), findsOneWidget);
    await screenshot(tester, 'home');
  });

  testWidgets(
    'section navigation matches UUID, immediate children, breadcrumb and explicit article opening',
    (tester) async {
      await pumpGuide(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();
      expect(repository.sectionCalls.last.$1, guideRootId);
      expect(find.text('Library Services'), findsOneWidget);
      expect(repository.articleCalls, 0);
      await tester.tap(find.text('Library Services'));
      await tester.pumpAndSettle();
      expect(repository.sectionCalls.last.$1, guideChildId);
      expect(find.text('Academic calendar'), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
      await screenshot(tester, 'section');
      await tester.tap(find.text('Academic calendar'));
      await tester.pumpAndSettle();
      expect(repository.articleCalls, 1);
      expect(find.byType(GuideMarkdownBody), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Academic calendar'), findsOneWidget);
    },
  );

  testWidgets('home empty and safe failure states have a working retry', (
    tester,
  ) async {
    repository.onSections = (_) async => throw GuideFailure.network;
    await pumpGuide(tester);
    await tester.pumpAndSettle();
    expect(find.text('Guide unavailable'), findsOneWidget);
    repository.onSections = (_) async => [];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No sections yet'), findsOneWidget);
  });

  testWidgets('sections support children and articles together, or neither', (
    tester,
  ) async {
    repository.onSection = (_, locale, _) async => locale == GuideLocale.en
        ? guideSectionDetail(page: GuidePage(items: [guideSummary()]))
        : GuideSectionDetail(
            section: GuideSection.fromJson(guideSectionJson()),
            breadcrumb: [GuideSection.fromJson(guideSectionJson())],
            subsections: const [],
            articles: const GuidePage(items: []),
          );
    await pumpGuide(tester, location: guideSectionLocation(guideRootId));
    await tester.pumpAndSettle();
    expect(find.text('Library Services'), findsOneWidget);
    expect(find.text('Academic calendar'), findsOneWidget);
    expect(repository.articleCalls, 0);
    session.selectLocale(GuideLocale.ar);
    await tester.pumpAndSettle();
    expect(find.text('No articles yet'), findsOneWidget);
  });

  testWidgets(
    'search debounce, clear and locale picker drive lexical queries',
    (tester) async {
      await pumpGuide(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search the Guide'));
      await tester.pumpAndSettle();
      expect(find.byType(GuideSearchScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'calendar');
      await tester.pump(const Duration(milliseconds: 349));
      expect(repository.searchCalls, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Academic calendar'), findsOneWidget);
      expect(repository.articleCalls, 0);
      await screenshot(tester, 'search');
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('Find university information'), findsOneWidget);
      await tester.tap(find.byType(DropdownButton<GuideLocale>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('العربية').last);
      await tester.pumpAndSettle();
      expect(session.locale, GuideLocale.ar);
    },
  );

  testWidgets('saved list removal updates the same session state', (
    tester,
  ) async {
    var saved = true;
    repository.onBookmarks = (_) async =>
        GuidePage(items: saved ? [guideSummary()] : []);
    repository.onRemove = (_) async {
      saved = false;
    };
    await pumpGuide(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved articles'));
    await tester.pumpAndSettle();
    expect(find.byType(GuideSavedScreen), findsOneWidget);
    expect(find.text('Academic calendar'), findsOneWidget);
    await tester.tap(find.text('Academic calendar'));
    await tester.pumpAndSettle();
    expect(find.byType(GuideMarkdownBody), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(GuideSavedScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Remove saved article'));
    await tester.pumpAndSettle();
    expect(repository.removeCalls, 1);
    expect(find.text('Nothing saved yet'), findsOneWidget);
  });

  testWidgets(
    'Arabic reader is RTL, supports text scaling and reports cited revision mismatch',
    (tester) async {
      repository.onArticle = (_) async => GuideArticle.fromJson({
        ...guideArticleJson(locale: 'ar', title: 'التقويم الأكاديمي'),
        'summary': 'اطّلع على التقويم الرسمي للجامعة.',
        'markdown': '## التخطيط للفصل الدراسي\n\nراجع التقويم الأكاديمي الرسمي لمعرفة المواعيد الجامعية.\n\n- اختر العام الأكاديمي الحالي.\n- تأكّد من المواعيد الخاصة بكليّتك.\n',
      });
      await pumpGuide(
        tester,
        location: guideArticleLocation(guideArticleId, citedVersion: 7),
        scale: 1.5,
      );
      await tester.pumpAndSettle();
      expect(find.text('التقويم الأكاديمي'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(GuideArticleMetadata))),
        TextDirection.rtl,
      );
      expect(
        find.textContaining('updated since the cited revision'),
        findsOneWidget,
      );
      expect(find.text('Verified 2026-11-27'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await screenshot(tester, 'article-arabic');
    },
  );

  testWidgets(
    'unknown article and section show unavailable states with retries',
    (tester) async {
      repository.onArticle = (_) async =>
          throw GuideFailure.fromCode('ARTICLE_NOT_FOUND');
      await pumpGuide(tester, location: guideArticleLocation(guideArticleId));
      await tester.pumpAndSettle();
      expect(find.text('Article unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      repository.onSection = (_, _, _) async =>
          throw GuideFailure.fromCode('SECTION_NOT_FOUND');
      router.go(guideSectionLocation(guideRootId));
      await tester.pumpAndSettle();
      expect(find.text('Section unavailable'), findsOneWidget);
    },
  );

  testWidgets(
    'article reader shows official sources and confirmed bookmark controls',
    (tester) async {
      repository.onArticle = (_) async {
        final data = guideArticleJson();
        data['markdown'] = '## Plan your semester\n\nUse the official calendar for academic dates.\n\n- Check the current year.\n- Confirm faculty-specific dates.\n';
        return GuideArticle.fromJson(data);
      };
      await pumpGuide(tester, location: guideArticleLocation(guideArticleId));
      await tester.pumpAndSettle();
      await screenshot(tester, 'article');
      await tester.drag(find.byType(ListView).first, const Offset(0, -450));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Official calendar'));
      await tester.pumpAndSettle();
      expect(urls.opened.single.scheme, 'https');
    },
  );
}
