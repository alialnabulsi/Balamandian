import 'dart:io';
import 'dart:ui' as ui;

import 'package:balamandian/app.dart';
import 'package:balamandian/domain/models/profile_models.dart';
import 'package:balamandian/ui/core/themes/app_theme.dart';
import 'package:balamandian/ui/core/ui/navigation/app_bottom_bar.dart';
import 'package:balamandian/ui/profile/widgets/profile_screen.dart';
import 'package:balamandian/ui/profile/widgets/account_information_sheet.dart';
import 'package:balamandian/ui/profile/widgets/member_list_screen.dart';
import 'package:balamandian/ui/profile/widgets/edit_profile_screen.dart';
import 'package:balamandian/ui/auth/widgets/account_setup_screen.dart';
import 'package:balamandian/ui/home/widgets/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../auth_test_support.dart';
import '../../profile_test_support.dart';
import '../../marketplace_test_support.dart';
import '../startup_test_support.dart';

void main() {
  setUpAll(() async {
    await loadStartupFonts();
    final font = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await font.load();
  });
  testWidgets(
    'profile reuses shell, edits real shared state and navigates public members with back',
    (tester) async {
      mockNativeSplash(tester);
      final h = AuthTestHarness((_) async => success(sessionData(), 200));
      addTearDown(h.close);
      await h.repository.login('F', 'test');
      final repo = FakeProfileRepository();
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        MainApp(
          profileRepository: repo,
          authRepository: h.repository,
          marketplaceRepository: FakeMarketplaceRepository(),
          onboardingRepository: testOnboardingRepository(),
          initialLocation: '/profile',
        ),
      );
      await prepareAppSplash(tester);
      await tester.pumpAndSettle();
      expect(find.byType(AppBottomBar), findsOneWidget);
      expect(find.text('Ali Al Nabulsi'), findsOneWidget);
      final rootProfile = tester.element(find.byType(ProfileScreen));
      await tester.tap(find.text('Followers'));
      await tester.pumpAndSettle();
      expect(find.byType(MemberListScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(ProfileScreen)), same(rootProfile));
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Saved campus biography');
      await tester.ensureVisible(find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Saved campus biography'), findsOneWidget);
      await tester.tap(find.text('Discover members'));
      await tester.pumpAndSettle();
      expect(find.byType(MemberListScreen), findsOneWidget);
      await tester.tap(find.text('Maya Haddad'));
      await tester.pumpAndSettle();
      expect(find.text('Maya Haddad'), findsOneWidget);
      expect(find.text('Edit profile'), findsNothing);
      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();
      expect(repo.otherData['isFollowing'], true);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(MemberListScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AppBottomBar), findsOneWidget);
      await tester.tap(find.byTooltip('Open account menu'));
      await tester.pumpAndSettle();
      expect(find.text('@ali.alnabulsi'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'signup personalization can be skipped; login does not reopen setup',
    (tester) async {
      mockNativeSplash(tester);
      final h = AuthTestHarness((_) async => success(sessionData(), 201));
      addTearDown(h.close);
      await h.repository.verify(registrationId, '123456');
      expect(h.repository.needsProfilePersonalization, true);
      final repo = FakeProfileRepository();
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        MainApp(
          profileRepository: repo,
          authRepository: h.repository,
          marketplaceRepository: FakeMarketplaceRepository(),
          onboardingRepository: testOnboardingRepository(),
          initialLocation: '/',
        ),
      );
      await prepareAppSplash(tester);
      await tester.pumpAndSettle();
      expect(find.byType(AccountSetupScreen), findsOneWidget);
      await tester.ensureVisible(find.text('Skip for now'));
      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(h.repository.needsProfilePersonalization, false);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'public account sheet omits private data while owner sheet includes actual account timestamp',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: AccountInformationSheet(
              profile: UserProfile.fromJson(
                profileJson(id: otherId, own: false),
              ),
            ),
          ),
        ),
      );
      expect(find.text('FICTION001'), findsNothing);
      expect(find.text('member@example.edu'), findsNothing);
      expect(find.text('Computer Science'), findsNothing);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: AccountInformationSheet(
              profile: UserProfile.fromJson(profileJson()),
            ),
          ),
        ),
      );
      expect(find.text('FICTION001'), findsOneWidget);
      expect(find.text('member@example.edu'), findsOneWidget);
      expect(find.text('Nov 2, 2026'), findsOneWidget);
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      '${dark ? 'Dark' : 'Light'} profile fits narrow and enlarged-text layouts with avatar fallback',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 740);
        tester.platformDispatcher.textScaleFactorTestValue = 1.4;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearAllTestValues();
        });
        final repo = FakeProfileRepository()
          ..ownData = profileJson(
            avatarPath:
                '/api/v1/users/$ownId/avatar?v=33333333-3333-4333-8333-333333333333',
          );
        addTearDown(repo.dispose);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme,
            darkTheme: appDarkTheme,
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            home: RepaintBoundary(
              key: boundary,
              child: ProfileScreen(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('AN'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          final file = File(
            'build/profile-verification/${dark ? 'dark' : 'light'}-profile.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(png!.buffer.asUint8List());
        });
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
