import '../../marketplace_test_support.dart';

import 'dart:ui' as ui;

import 'package:balamandian/app.dart';
import 'package:balamandian/ui/core/ui/navigation/app_account_drawer.dart';
import 'package:balamandian/ui/core/ui/navigation/app_bottom_bar.dart';
import 'package:balamandian/ui/core/ui/navigation/app_navigation_item.dart';
import 'package:balamandian/ui/core/ui/quick_actions/app_quick_action.dart';
import 'package:balamandian/ui/core/ui/quick_actions/expandable_quick_actions.dart';
import 'package:balamandian/ui/home/widgets/app_shell.dart';
import 'package:balamandian/ui/home/widgets/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../auth_test_support.dart';
import '../startup_test_support.dart';

Future<void> loadHomeFonts() async {
  await loadStartupFonts();
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

Future<void> pumpHome(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  bool dark = false,
  bool reduced = true,
  double textScale = 1,
  String location = '/',
  FakeViewPadding padding = FakeViewPadding.zero,
}) async {
  mockNativeSplash(tester);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = padding;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reduced);
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
  final harness = AuthTestHarness((request) async {
    if (request.url.path.endsWith('/login')) return success(sessionData(), 200);
    fail('The Home Shell must not request ${request.url.path}');
  });
  addTearDown(harness.close);
  await harness.repository.login('FICTION001', 'test');
  await tester.pumpWidget(
    MainApp(
      marketplaceRepository: FakeMarketplaceRepository(),
      externalUrls: FakeExternalUrlService(),
      initialLocation: location,
      authRepository: harness.repository,
      onboardingRepository: testOnboardingRepository(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    ),
  );
  await prepareAppSplash(tester);
  await tester.pumpAndSettle();
}

Finder tab(String label) => find.byWidgetPredicate(
  (widget) => widget is AppNavigationItem && widget.label == label,
);

Finder quick(String label) => find.byWidgetPredicate(
  (widget) => widget is AppQuickAction && widget.tooltip == label,
);

GoRouter shellRouter(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(AppShell)));

void main() {
  setUpAll(loadHomeFonts);

  testWidgets('Tabs retain Home; Create acts without selecting a tab', (
    tester,
  ) async {
    await pumpHome(tester);
    final homeElement = tester.element(find.byType(HomeScreen));
    final shellElement = tester.element(find.byType(AppShell));
    final router = shellRouter(tester);
    for (final label in ['Map', 'Market', 'Profile']) {
      await tester.tap(tab(label));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/${label.toLowerCase()}',
      );
      expect(
        find.text(label == 'Market' ? 'Marketplace' : '$label coming soon'),
        findsOneWidget,
      );
      expect(tester.widget<AppNavigationItem>(tab(label)).selected, isTrue);
      expect(tester.element(find.byType(AppShell)), same(shellElement));
    }
    await tester.tap(find.byTooltip('Create'));
    await tester.pump();
    expect(find.text('Create is coming soon.'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/profile');
    expect(tester.widget<AppNavigationItem>(tab('Profile')).selected, isTrue);
    await tester.tap(tab('Home'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(tester.element(find.byType(HomeScreen)), same(homeElement));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Avatar drawer uses native dismissal and navigates to Settings', (
    tester,
  ) async {
    await pumpHome(tester);
    expect(find.byTooltip('Open navigation menu'), findsNothing);
    await tester.tap(find.byTooltip('Open account menu'));
    await tester.pumpAndSettle();
    expect(find.text('Your account'), findsOneWidget);
    expect(find.text('SIS ID: FICTION001'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Your account'), findsNothing);
    await tester.tap(find.byTooltip('Open account menu'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(380, 300));
    await tester.pumpAndSettle();
    expect(find.text('Your account'), findsNothing);
    await tester.tap(find.byTooltip('Open account menu'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AppAccountDrawer),
        matching: find.text('Settings'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Settings coming soon'), findsOneWidget);
    expect(find.text('Your account'), findsNothing);
    expect(find.byType(AppBottomBar), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(shellRouter(tester).routeInformationProvider.value.uri.path, '/');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Top actions show explicit coming-soon feedback', (tester) async {
    await pumpHome(tester);
    for (final label in ['Search', 'Notifications', 'Messages']) {
      await tester.tap(find.byTooltip(label));
      await tester.pumpAndSettle();
      expect(find.text('$label is coming soon.'), findsOneWidget);
    }
    expect(shellRouter(tester).routeInformationProvider.value.uri.path, '/');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Quick actions form the fan and dismiss with outside, close or back',
    (tester) async {
      await pumpHome(tester, reduced: false);
      await tester.tap(quick('Open quick actions'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      // Expansion is in progress, rather than jumping directly to its endpoint.
      final guideOpacity = tester
          .widget<Opacity>(
            find
                .ancestor(of: quick('Guide'), matching: find.byType(Opacity))
                .first,
          )
          .opacity;
      expect(guideOpacity, allOf(greaterThan(0), lessThan(1)));
      await tester.pumpAndSettle();
      final guide = tester.getCenter(quick('Guide'));
      final ai = tester.getCenter(quick('AI'));
      final tools = tester.getCenter(quick('Tools'));
      final close = tester.getCenter(quick('Close quick actions'));
      expect(guide.dx, lessThan(ai.dx));
      expect(guide.dy, closeTo(ai.dy, .1));
      expect(tools.dx, closeTo(guide.dx, .1));
      expect(tools.dy, greaterThan(guide.dy));
      expect(close.dx, closeTo(ai.dx, .1));
      expect(close.dy, closeTo(tools.dy, .1));
      await tester.tapAt(const Offset(30, 200));
      await tester.pumpAndSettle();
      expect(quick('Guide'), findsNothing);
      await tester.tap(quick('Open quick actions'));
      await tester.pumpAndSettle();
      await tester.tap(quick('Close quick actions'));
      await tester.pumpAndSettle();
      expect(quick('Guide'), findsNothing);
      await tester.tap(quick('Open quick actions'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(quick('Guide'), findsNothing);
      expect(shellRouter(tester).routeInformationProvider.value.uri.path, '/');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Each quick action navigates; back dismisses before leaving a nested route',
    (tester) async {
      await pumpHome(tester);
      for (final label in ['Guide', 'AI', 'Tools']) {
        await tester.tap(quick('Open quick actions'));
        await tester.pumpAndSettle();
        await tester.tap(quick(label));
        await tester.pumpAndSettle();
        expect(
          find.text(label == 'Market' ? 'Marketplace' : '$label coming soon'),
          findsOneWidget,
        );
        expect(quick(label), findsNothing);
        expect(
          shellRouter(tester).routeInformationProvider.value.uri.path,
          '/${label.toLowerCase()}',
        );
        await tester.tap(quick('Open quick actions'));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(quick(label), findsNothing);
        expect(
          find.text(label == 'Market' ? 'Marketplace' : '$label coming soon'),
          findsOneWidget,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          shellRouter(tester).routeInformationProvider.value.uri.path,
          '/',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Reduced motion opens immediately and external navigation dismisses',
    (tester) async {
      await pumpHome(tester);
      final router = shellRouter(tester);
      await tester.tap(quick('Open quick actions'));
      await tester.pump();
      expect(
        tester.getCenter(quick('Guide')).dy,
        lessThan(tester.getCenter(quick('Tools')).dy),
      );
      final guideOpacity = tester
          .widget<Opacity>(
            find
                .ancestor(of: quick('Guide'), matching: find.byType(Opacity))
                .first,
          )
          .opacity;
      expect(guideOpacity, 1);
      router.go('/map');
      await tester.pumpAndSettle();
      expect(quick('Guide'), findsNothing);
      expect(find.text('Map coming soon'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      '${dark ? 'Dark' : 'Light'} theme, safe areas, narrow layout and touch targets',
      (tester) async {
        await pumpHome(
          tester,
          dark: dark,
          size: const Size(320, 640),
          textScale: 2,
          padding: const FakeViewPadding(top: 24, bottom: 24),
        );
        final bottom = find.byType(BottomAppBar);
        final shape = tester.widget<PhysicalShape>(
          find
              .descendant(of: bottom, matching: find.byType(PhysicalShape))
              .first,
        );
        expect(
          shape.color.computeLuminance(),
          dark ? lessThan(.1) : greaterThan(.9),
        );
        expect(tester.getRect(tab('Home')).bottom, lessThanOrEqualTo(616));
        expect(tester.takeException(), isNull);
        final semantics = tester.ensureSemantics();
        expect(
          tester.getSemantics(tab('Home')).flagsCollection.isSelected,
          ui.Tristate.isTrue,
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await tester.tap(quick('Open quick actions'));
        await tester.pumpAndSettle();
        for (final label in ['Guide', 'AI', 'Tools', 'Close quick actions']) {
          final rect = tester.getRect(quick(label));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(320));
          expect(rect.top, greaterThanOrEqualTo(24));
          expect(rect.bottom, lessThanOrEqualTo(616));
        }
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await tester.tap(quick('Close quick actions'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Open account menu'));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('Landscape fan and scrollable empty state fit a short screen', (
    tester,
  ) async {
    await pumpHome(
      tester,
      size: const Size(640, 320),
      textScale: 1.5,
      padding: const FakeViewPadding(left: 24, bottom: 16),
    );
    await tester.tap(quick('Open quick actions'));
    await tester.pumpAndSettle();
    for (final label in ['Guide', 'AI', 'Tools', 'Close quick actions']) {
      final rect = tester.getRect(quick(label));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(304));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('Authentication stays outside the shell', (tester) async {
    await pumpStartup(tester, screen: 'sign-in');
    expect(find.byType(AppShell), findsNothing);
    expect(find.byType(ExpandableQuickActions), findsNothing);
    expect(find.byType(AppBottomBar), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
