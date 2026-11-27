import 'package:balamandian/ui/calendar/widgets/campus_month_calendar.dart';

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:balamandian/app.dart';
import 'package:balamandian/domain/models/profile_models.dart';
import 'package:balamandian/ui/auth/widgets/credentials_screen.dart';
import 'package:balamandian/ui/auth/widgets/sign_in_prompt.dart';
import 'package:balamandian/ui/core/ui/navigation/app_account_drawer.dart';
import 'package:balamandian/ui/core/ui/quick_actions/app_quick_action.dart';
import 'package:balamandian/ui/home/widgets/app_shell.dart';
import 'package:balamandian/ui/gpa/widgets/gpa_calculator_screen.dart';
import 'package:balamandian/ui/notes/widgets/notes_browser_screen.dart';
import 'package:balamandian/ui/tools/view_models/tools_hub_view_model.dart';
import 'package:balamandian/ui/tools/widgets/campus_contact_item.dart';
import 'package:balamandian/ui/tools/widgets/tool_shortcut.dart';
import 'package:balamandian/ui/tools/widgets/tools_screen.dart';
import 'package:balamandian/ui/tools/widgets/tools_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../auth_test_support.dart';
import '../../marketplace_test_support.dart';
import '../../profile_test_support.dart';
import '../../notes_test_support.dart';
import '../startup_test_support.dart';
import '../home/home_shell_test.dart' show loadHomeFonts;
import 'tools_hub_view_model_test.dart' show setRoles;

Future<(AuthTestHarness, FakeExternalUrlService)> pumpTools(
  WidgetTester tester, {
  bool guest = false,
  List<String> roles = const ['student'],
  String location = '/tools',
  Size size = const Size(412, 915),
  double textScale = 1,
  bool dark = false,
  FakeProfileRepository? profiles,
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
  final auth = AuthTestHarness((_) async => success(sessionData(), 200));
  addTearDown(auth.close);
  if (!guest) await auth.repository.login('FICTION001', 'test');
  final profileRepository = profiles ?? FakeProfileRepository();
  addTearDown(profileRepository.dispose);
  setRoles(profileRepository, roles);
  final urls = FakeExternalUrlService();
  await tester.pumpWidget(
    RepaintBoundary(
      child: MainApp(
        authRepository: auth.repository,
        profileRepository: profileRepository,
        notesRepository: FakeNotesRepository(),
        noteDrafts: MemoryNoteDrafts(),
        noteFiles: FakeNoteFiles(),
        marketplaceRepository: FakeMarketplaceRepository(),
        externalUrls: urls,
        onboardingRepository: testOnboardingRepository(completed: true),
        initialLocation: location,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      ),
    ),
  );
  await prepareAppSplash(tester);
  await tester.pumpAndSettle();
  return (auth, urls);
}

Finder shortcut(String label) => find.byWidgetPredicate(
  (widget) => widget is ToolShortcut && widget.label == label,
);
Finder quick(String label) => find.byWidgetPredicate(
  (widget) => widget is AppQuickAction && widget.tooltip == label,
);
GoRouter toolsRouter(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(AppShell)));

Future<void> captureTools(WidgetTester tester, String name, Size size) async {
  if (const bool.fromEnvironment('CAPTURE_UI')) {
    await tester.runAsync(() async {
      RenderRepaintBoundary? boundary;
      void visit(RenderObject object) {
        if (boundary != null) return;
        if (object is RenderRepaintBoundary && object.size == size) {
          boundary = object;
        } else {
          object.visitChildren(visit);
        }
      }

      visit(tester.binding.renderViews.single);
      final image = await boundary!.toImage();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/ui-verification/tools/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
    });
  }
}

void main() {
  setUpAll(loadHomeFonts);

  testWidgets('Drawer and floating actions reach the same Tools screen', (
    tester,
  ) async {
    await pumpTools(tester, guest: false, location: '/guide');
    await tester.tap(find.byTooltip('Open account menu'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AppAccountDrawer),
        matching: find.text('Tools'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ToolsScreen), findsOneWidget);
    final router = toolsRouter(tester);
    expect(router.routeInformationProvider.value.uri.path, '/tools');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
    router.go('/guide');
    await tester.pumpAndSettle();
    await tester.tap(quick('Open quick actions'));
    await tester.pumpAndSettle();
    await tester.tap(quick('Tools'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/tools');
    expect(find.byType(ToolsScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final path in [
    '/tools',
    '/tools/tasks',
    '/tools/gpa',
    '/tools/notes',
    '/tools/calendar',
    '/tools/lost-found',
    '/tools/scheduler',
  ]) {
    testWidgets('Unauthenticated $path redirects to sign in', (tester) async {
      await pumpTools(tester, guest: true, location: path);
      expect(find.byType(CredentialsScreen), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      expect(find.byType(ToolsScreen), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final roles in [
    ['student'],
    ['advisor'],
    ['student', 'advisor'],
    ['staff'],
  ]) {
    testWidgets('$roles keeps six shortcuts with eligible feedback', (
      tester,
    ) async {
      await pumpTools(tester, guest: false, roles: roles);
      expect(find.byType(ToolShortcut), findsNWidgets(9));
      await tester.tap(shortcut('GPA Calculator'));
      await tester.pumpAndSettle();
      expect(find.byType(SignInPrompt), findsNothing);
      if (roles.contains('student')) {
        expect(find.byType(GpaCalculatorScreen), findsOneWidget);
        toolsRouter(tester).go('/tools');
      } else {
        expect(find.text('Account eligibility'), findsOneWidget);
        await tester.tap(find.text('Close'));
      }
      await tester.pumpAndSettle();
      await tester.tap(shortcut('My Notes'));
      await tester.pumpAndSettle();
      if (roles.contains('student') || roles.contains('advisor')) {
        expect(find.byType(NotesBrowserScreen), findsOneWidget);
      } else {
        expect(find.text('Account eligibility'), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'Profile loading/error stays signed in, retry restores eligibility',
    (tester) async {
      final pending = Completer<UserProfile>();
      final profiles = FakeProfileRepository()
        ..ownRequest = () => pending.future;
      await pumpTools(tester, guest: false, profiles: profiles);
      expect(find.text('Checking account eligibility…'), findsOneWidget);
      expect(
        tester.widget<ToolShortcut>(shortcut('GPA Calculator')).onPressed,
        isNull,
      );
      profiles.failure = 'Your profile could not be loaded. Please retry.';
      pending.completeError(
        const ProfileFailure('PROFILE_UNAVAILABLE', 'Unavailable'),
      );
      await tester.pumpAndSettle();
      // The production repository publishes failed requests; this simple fake
      // only publishes successful loads.
      profiles.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('Account eligibility unavailable'), findsOneWidget);
      expect(find.byType(SignInPrompt), findsNothing);
      profiles.failure = null;
      profiles.ownRequest = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await tester.tap(shortcut('GPA Calculator'));
      await tester.pumpAndSettle();
      expect(find.byType(GpaCalculatorScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Calendar, official services, failures and inert contacts', (
    tester,
  ) async {
    final (_, urls) = await pumpTools(tester);
    await tester.tap(shortcut('Calendar'));
    await tester.pumpAndSettle();
    expect(find.byType(CampusMonthCalendar), findsOneWidget);
    await tester.tap(find.byTooltip('Back to Tools'));
    await tester.pumpAndSettle();
    for (final service in [
      ('SIS', UniversityLinks.sis),
      ('Moodle', UniversityLinks.moodle),
      ('iMail', UniversityLinks.imail),
    ]) {
      await tester.ensureVisible(shortcut(service.$1));
      await tester.tap(shortcut(service.$1));
      await tester.pumpAndSettle();
      expect(urls.launched.last, service.$2);
    }
    urls.result = false;
    await tester.tap(shortcut('SIS'));
    await tester.pumpAndSettle();
    expect(
      find.text('This link could not be opened. Please try again.'),
      findsOneWidget,
    );
    final launches = urls.launched.length;
    for (final label in [
      'Campus Security',
      'Campus Medical Support',
      'Student Affairs',
      'IT Helpdesk',
    ]) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    expect(find.byType(CampusContactItem), findsNWidgets(4));
    expect(urls.launched.length, launches);
    expect(urls.launched.any((uri) => uri.scheme == 'tel'), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Logout and next login refresh shortcut availability in the retained hub',
    (tester) async {
      final profiles = FakeProfileRepository();
      final (auth, _) = await pumpTools(
        tester,
        guest: false,
        profiles: profiles,
      );
      expect(
        tester
            .widget<ToolShortcut>(shortcut('GPA Calculator'))
            .availabilityLabel,
        isNull,
      );
      await auth.repository.logout(localOnly: true);
      await tester.pumpAndSettle();
      expect(find.byType(ToolsScreen), findsNothing);
      expect(find.byType(CredentialsScreen), findsOneWidget);
      setRoles(profiles, ['advisor']);
      await auth.repository.login('FICTION001', 'test');
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.byType(AppShell))).go('/tools');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ToolShortcut>(shortcut('GPA Calculator'))
            .availabilityLabel,
        'Not available for your account',
      );
      expect(
        tester.widget<ToolShortcut>(shortcut('My Notes')).availabilityLabel,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final layout in [
    (const Size(412, 915), 1.0, false),
    (const Size(412, 915), 1.0, true),
    (const Size(320, 640), 2.0, false),
    (const Size(844, 390), 2.0, true),
  ]) {
    testWidgets(
      'Scrollable layout ${layout.$1}, scale ${layout.$2}, dark ${layout.$3}',
      (tester) async {
        await pumpTools(
          tester,
          size: layout.$1,
          textScale: layout.$2,
          dark: layout.$3,
        );
        expect(
          tester
              .widgetList<ToolsSection>(find.byType(ToolsSection))
              .map((s) => s.title),
          ['Tools', 'University Services', 'Emergency & Campus Contacts'],
        );
        final gpa = tester.getRect(shortcut('GPA Calculator'));
        final todo = tester.getRect(shortcut('To-do Planner'));
        final calendar = tester.getRect(shortcut('Calendar'));
        if (layout.$2 == 1) {
          expect(gpa.top, todo.top);
          expect(gpa.top, calendar.top);
        } else if (layout.$1.width == 320) {
          expect(todo.top, greaterThan(gpa.top));
        }
        final semantics = tester.ensureSemantics();
        expect(find.bySemanticsLabel('GPA Calculator'), findsOneWidget);
        expect(
          tester.getSemantics(shortcut('GPA Calculator')),
          matchesSemantics(
            label: 'GPA Calculator',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
            textDirection: TextDirection.ltr,
          ),
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
        await captureTools(
          tester,
          '${layout.$1.width}-${layout.$2}-${layout.$3}',
          layout.$1,
        );
        await tester.ensureVisible(find.text('IT Helpdesk'));
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.text('IT Helpdesk')).bottom,
          lessThan(layout.$1.height - 80),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
