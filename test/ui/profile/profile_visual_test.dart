import 'dart:io';
import 'dart:ui' as ui;

import 'package:balamandian/app.dart';
import 'package:balamandian/ui/core/themes/app_theme.dart';
import 'package:balamandian/ui/core/ui/backgrounds/app_branded_background.dart';
import 'package:balamandian/ui/core/ui/illustrations/campus_line_art.dart';
import 'package:balamandian/ui/profile/widgets/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../auth_test_support.dart';
import '../../marketplace_test_support.dart';
import '../../profile_test_support.dart';
import '../startup_test_support.dart';

Future<void> captureProfile(
  WidgetTester tester,
  GlobalKey boundary,
  String name,
) async {
  await tester.runAsync(() async {
    final image =
        await (boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('build/profile-verification/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    await loadStartupFonts();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final name in [
    'own',
    'public',
    'editor',
    'followers',
    'following',
    'discover',
    'share',
    'account',
    'dark',
  ]) {
    testWidgets('branded $name screenshot using fictional fixture', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(384, 832);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
      tester.platformDispatcher.textScaleFactorTestValue = 1.15;
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
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MainApp(
            authRepository: auth.repository,
            profileRepository: repo,
            marketplaceRepository: FakeMarketplaceRepository(),
            onboardingRepository: testOnboardingRepository(),
            initialLocation: '/profile',
            themeMode: name == 'dark' ? ThemeMode.dark : ThemeMode.light,
          ),
        ),
      );
      await prepareAppSplash(tester);
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          const AssetImage(AppBrandedBackground.asset),
          tester.element(find.byType(ProfileScreen)),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        final context = tester.element(find.byType(ProfileScreen));
        await Future.wait([
          precacheImage(const AssetImage(CampusLineArt.asset), context),
          precacheImage(
            const AssetImage(
              'assets/onboarding/illustrations/olive-branch.png',
            ),
            context,
          ),
        ]);
      });
      await tester.pump();
      switch (name) {
        case 'editor':
          await tester.ensureVisible(find.text('Edit profile'));
          await tester.tap(find.text('Edit profile'));
        case 'followers':
          await tester.tap(find.text('Followers'));
        case 'following':
          await tester.tap(find.text('Following'));
        case 'discover' || 'public':
          await tester.ensureVisible(find.byTooltip('Discover members'));
          await tester.tap(find.byTooltip('Discover members'));
          await tester.pumpAndSettle();
          if (name == 'public') {
            await tester.tap(find.text('Maya Haddad'));
          }
        case 'share':
          await tester.tap(find.text('Share profile'));
        case 'account':
          await tester.tap(find.text('ali.alnabulsi'));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (name == 'share') {
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/onboarding/images/uob-logo.png'),
            tester.element(find.byType(Scaffold).first),
          ),
        );
        await tester.pump();
      }
      await captureProfile(tester, boundary, name);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final variant in [
    (const Size(320, 740), 2.0),
    (const Size(430, 932), 1.0),
    (const Size(832, 384), 1.15),
  ]) {
    testWidgets('long identity at ${variant.$1} x${variant.$2}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = variant.$1;
      tester.platformDispatcher.textScaleFactorTestValue = variant.$2;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearAllTestValues();
      });
      final repo = FakeProfileRepository()
        ..ownData = {
          ...profileJson(biography: 'Campus life and learning. ' * 10),
          'displayName': 'A Very Long Official University Member Display Name',
          'username': 'averylonguniversityusername2026',
          'roles': ['student', 'instructor', 'advisor', 'staff'],
          'followersCount': 10000000,
          'followingCount': 99999999,
        };
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ProfileScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip('Discover members'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
