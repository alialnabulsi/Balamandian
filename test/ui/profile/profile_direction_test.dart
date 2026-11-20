import 'package:balamandian/app.dart';
import 'package:balamandian/ui/core/themes/app_theme.dart';
import 'package:balamandian/ui/core/themes/shell_tokens.dart';
import 'package:balamandian/ui/core/ui/app_surface.dart';
import 'package:balamandian/ui/core/ui/avatars/profile_avatar.dart';
import 'package:balamandian/ui/core/ui/illustrations/campus_line_art.dart';
import 'package:balamandian/ui/core/ui/navigation/app_bottom_bar.dart';
import 'package:balamandian/ui/core/ui/quick_actions/expandable_quick_actions.dart';
import 'package:balamandian/ui/core/ui/quick_actions/app_quick_action.dart';
import 'package:balamandian/ui/profile/widgets/profile_header.dart';
import 'package:balamandian/ui/profile/widgets/profile_screen.dart';
import 'package:balamandian/ui/profile/widgets/profile_skeleton.dart';
import 'package:balamandian/ui/profile/widgets/profile_statistics.dart';
import 'package:balamandian/ui/profile/widgets/profile_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../auth_test_support.dart';
import '../../marketplace_test_support.dart';
import '../../profile_test_support.dart';
import '../startup_test_support.dart';

void main() {
  setUpAll(loadStartupFonts);
  testWidgets(
    'approved profile is flat with avatar beside stats and equal tinted actions',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(384, 832);
      addTearDown(tester.view.reset);
      final repo = FakeProfileRepository();
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ProfileScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppSurface), findsNothing);
      expect(find.text('UNIVERSITY OF BALAMAND'), findsNothing);
      final avatar = tester.getRect(find.byType(ProfileAvatar));
      final stats = tester.getRect(find.byType(ProfileStatistics));
      expect(avatar.right, lessThan(stats.left));
      expect(stats.center.dy, closeTo(avatar.center.dy, 4));
      final edit = find.widgetWithText(FilledButton, 'Edit profile');
      final share = find.widgetWithText(FilledButton, 'Share profile');
      expect(tester.getSize(edit), tester.getSize(share));
      final editStyle = tester.widget<FilledButton>(edit).style!;
      final shareStyle = tester.widget<FilledButton>(share).style!;
      expect(
        editStyle.backgroundColor!.resolve({}),
        shareStyle.backgroundColor!.resolve({}),
      );
      expect(find.text('Student · University of Balamand'), findsOneWidget);
      expect(find.byTooltip('Discover members'), findsOneWidget);
      expect(find.byType(CampusLineArt), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Student · University of Balamand'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'do not grant Balamandian administrative privileges',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'profile floating quick action preserves Home anchor and expandable actions',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(384, 832);
      addTearDown(tester.view.reset);
      mockNativeSplash(tester);
      final auth = AuthTestHarness((_) async => success(sessionData(), 200));
      addTearDown(auth.close);
      await auth.repository.login('F', 'test');
      final repo = FakeProfileRepository();
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        MainApp(
          authRepository: auth.repository,
          profileRepository: repo,
          marketplaceRepository: FakeMarketplaceRepository(),
          onboardingRepository: testOnboardingRepository(),
          initialLocation: '/profile',
        ),
      );
      await prepareAppSplash(tester);
      await tester.pumpAndSettle();
      final fab = tester.getRect(find.byType(ExpandableQuickActions));
      final bottomBar = tester.getRect(find.byType(AppBottomBar));
      expect(fab.width, ShellTokens.actionSize);
      expect(fab.bottom, lessThan(bottomBar.top));
      expect(fab.right, closeTo(384 - 16, 1));
      expect(
        find.descendant(
          of: find.byType(ProfileHeader),
          matching: find.byType(ExpandableQuickActions),
        ),
        findsNothing,
      );
      await tester.tap(find.bySemanticsLabel('Open quick actions'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Guide'), findsOneWidget);
      expect(find.bySemanticsLabel('AI'), findsOneWidget);
      expect(find.bySemanticsLabel('Tools'), findsOneWidget);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is AppQuickAction &&
              widget.tooltip == 'Close quick actions',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AppBottomBar),
          matching: find.text('Home'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(ExpandableQuickActions)), fab);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('new skeleton keeps the unboxed avatar and social row geometry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(20),
              child: ProfileSkeleton(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppSurface), findsNothing);
    expect(find.byType(ProfileStatisticSkeleton), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'architectural background stays stationary while profile scrolls',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(384, 600);
      addTearDown(tester.view.reset);
      final repo = FakeProfileRepository()
        ..ownData = profileJson(biography: 'Campus stories. ' * 15);
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ProfileScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      final before = tester.getRect(find.byType(CampusLineArt).first);
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(CampusLineArt).first), before);
      final list = tester.widget<ListView>(find.byType(ListView));
      final clearance = tester.widget<Padding>(
        find.byKey(const ValueKey('profile-scroll-clearance')),
      );
      expect(
        (list.padding! as EdgeInsets).bottom +
            (clearance.padding as EdgeInsets).bottom,
        greaterThanOrEqualTo(100),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final variant in [
    (const Size(320, 740), 1.0),
    (const Size(384, 832), 1.15),
    (const Size(430, 932), 1.0),
    (const Size(320, 740), 2.0),
    (const Size(832, 384), 2.0),
  ]) {
    testWidgets(
      'empty-state text stays clear of fixed quick action at ${variant.$1} x${variant.$2}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = variant.$1;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
        tester.platformDispatcher.textScaleFactorTestValue = variant.$2;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearAllTestValues();
        });
        mockNativeSplash(tester);
        final auth = AuthTestHarness((_) async => success(sessionData(), 200));
        addTearDown(auth.close);
        await auth.repository.login('F', 'test');
        final repo = FakeProfileRepository();
        addTearDown(repo.dispose);
        await tester.pumpWidget(
          MainApp(
            authRepository: auth.repository,
            profileRepository: repo,
            marketplaceRepository: FakeMarketplaceRepository(),
            onboardingRepository: testOnboardingRepository(),
            initialLocation: '/profile',
          ),
        );
        await prepareAppSplash(tester);
        await tester.pumpAndSettle();
        final action = tester.getRect(find.byType(ExpandableQuickActions));
        final bar = tester.getRect(find.byType(AppBottomBar));
        expect(action.width, ShellTokens.actionSize);
        expect(action.bottom, closeTo(bar.top - 16, 1));
        final scrollable = find
            .descendant(
              of: find.byType(ProfileScreen),
              matching: find.byType(Scrollable),
            )
            .first;
        final viewport = tester.getRect(scrollable);
        expect(viewport.bottom, lessThanOrEqualTo(action.top - 8));
        final description = find.text('Campus posts are coming soon.');
        await tester.scrollUntilVisible(
          description,
          200,
          scrollable: scrollable,
        );
        await tester.ensureVisible(description);
        await tester.pumpAndSettle();
        final text = tester.getRect(description);
        expect(text.bottom, lessThanOrEqualTo(viewport.bottom + .1));
        expect(text.overlaps(action.inflate(8)), false);
        expect(ProfileTokens.nameFontSize, lessThan(24));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
