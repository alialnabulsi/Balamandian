import 'package:balamandian/app.dart';
import 'package:balamandian/ui/gpa/widgets/gpa_calculator_screen.dart';
import 'package:balamandian/ui/gpa/widgets/gpa_input.dart';
import 'package:balamandian/ui/home/widgets/app_shell.dart';
import 'package:balamandian/ui/auth/widgets/sign_in_prompt.dart';
import 'package:balamandian/ui/tools/widgets/tools_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../academic_test_support.dart';
import '../../auth_test_support.dart';
import '../../marketplace_test_support.dart';
import '../../profile_test_support.dart';
import '../../task_test_support.dart';
import '../startup_test_support.dart';
import '../home/home_shell_test.dart' show loadHomeFonts;
import '../tools/tools_hub_view_model_test.dart' show setRoles;
import '../tools/tools_screen_test.dart' show captureTools;

Future<FakeAcademicRepository> pumpCalculator(
  WidgetTester tester, {
  String location = '/tools/gpa',
  bool guest = false,
  List<String> roles = const ['student'],
  Size size = const Size(412, 915),
  double textScale = 1,
  bool dark = false,
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
  if (!guest) await auth.repository.login('FIRST', 'test');
  final profiles = FakeProfileRepository();
  setRoles(profiles, roles);
  addTearDown(profiles.dispose);
  final repo = FakeAcademicRepository();
  await tester.pumpWidget(
    RepaintBoundary(
      child: MainApp(
        authRepository: auth.repository,
        profileRepository: profiles,
        academicRepository: repo,
        taskRepository: FakeTaskRepository(),
        marketplaceRepository: FakeMarketplaceRepository(),
        externalUrls: FakeExternalUrlService(),
        onboardingRepository: testOnboardingRepository(completed: true),
        initialLocation: location,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      ),
    ),
  );
  await prepareAppSplash(tester);
  await tester.pumpAndSettle();
  return repo;
}

Finder field(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is GpaInput && widget.label == label,
  ),
  matching: find.byType(TextFormField),
);
Future<void> type(WidgetTester tester, String label, String text) async {
  await reveal(tester, field(label));
  await tester.enterText(field(label), text);
  await tester.pumpAndSettle();
}

Future<void> addCourse(WidgetTester tester) async {
  await reveal(tester, find.text('Add course'));
  await tester.tap(find.text('Add course'));
  await tester.pumpAndSettle();
  await type(tester, 'Course', 'COMP 101');
  await type(tester, 'Credits', '3');
  await type(tester, 'Grade /100', '90');
}

Future<void> reveal(WidgetTester tester, Finder target) async {
  await Scrollable.ensureVisible(tester.element(target), alignment: .35);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadHomeFonts);
  testWidgets(
    'Tools opens calculator in shared shell, predicts live and Back returns to Tools',
    (tester) async {
      final repo = await pumpCalculator(tester, location: '/tools');
      await tester.tap(find.text('GPA Calculator'));
      await tester.pumpAndSettle();
      expect(find.byType(GpaCalculatorScreen), findsOneWidget);
      expect(find.byType(AppShell), findsOneWidget);
      await addCourse(tester);
      expect(find.text('3.90'), findsOneWidget);
      expect(find.text('/ 4.00'), findsOneWidget);
      expect(repo.reads, 0);
      await reveal(tester, find.text('ESTIMATED SEMESTER GPA'));
      await captureTools(tester, 'gpa-results-phone', const Size(412, 915));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ToolsScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'manual baseline and unavailable import preserve typed work; reset clears fields',
    (tester) async {
      final repo = await pumpCalculator(tester);
      await type(tester, 'Current cumulative average /100', '75.5');
      await type(tester, 'Completed GPA-counted credits', '30');
      await addCourse(tester);
      expect(find.text('Projected cumulative GPA'), findsOneWidget);
      await reveal(tester, find.text('Import GPA & CGPA from SIS'));
      await tester.tap(find.text('Import GPA & CGPA from SIS'));
      await tester.pumpAndSettle();
      expect(repo.reads, 1);
      expect(find.textContaining('No academic results'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(field('Current cumulative average /100'))
            .initialValue,
        '75.5',
      );
      expect(find.text('Projected cumulative GPA'), findsOneWidget);
      await reveal(tester, find.byTooltip('Reset calculator'));
      await tester.tap(find.byTooltip('Reset calculator'));
      await tester.pumpAndSettle();
      expect(field('Course'), findsNothing);
      expect(find.text('3.90'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'rotation retains input; leaving via retained shell branch clears scenario on return',
    (tester) async {
      await pumpCalculator(tester);
      await addCourse(tester);
      tester.view.physicalSize = const Size(915, 412);
      await tester.pumpAndSettle();
      expect(find.text('3.90'), findsOneWidget);
      final context = tester.element(find.byType(GpaCalculatorScreen));
      final router = GoRouter.of(context);
      router.go('/profile');
      await tester.pumpAndSettle();
      router.go('/tools/gpa');
      await tester.pumpAndSettle();
      expect(field('Course'), findsNothing);
      expect(find.text('3.90'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final (guest, roles) in [
    (true, <String>[]),
    (false, ['advisor']),
    (false, ['staff']),
    (false, ['advisor', 'student']),
  ]) {
    testWidgets('direct navigation checks access guest=$guest roles=$roles', (
      tester,
    ) async {
      final repo = await pumpCalculator(tester, guest: guest, roles: roles);
      final eligible = roles.contains('student');
      expect(find.text('Add course'), eligible ? findsOneWidget : findsNothing);
      expect(repo.reads, 0);
      if (guest) {
        await tester.tap(find.text('Sign in').first);
        await tester.pumpAndSettle();
        expect(find.byType(SignInPrompt), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final size in [const Size(280, 640), const Size(915, 412)]) {
    testWidgets(
      'dark enlarged layout and decimal editing remain keyboard safe at $size',
      (tester) async {
        await pumpCalculator(tester, size: size, textScale: 2, dark: true);
        await addCourse(tester);
        tester.view.viewInsets = const FakeViewPadding(bottom: 210);
        await type(tester, 'Grade /100', '81.99');
        expect(find.text('3.00'), findsOneWidget);
        expect(find.text('/ 4.00'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'method explains policy and source; phone screenshot has shell clearance',
    (tester) async {
      await pumpCalculator(tester);
      await captureTools(tester, 'gpa-calculator-phone', const Size(412, 915));
      expect(find.text('Method & sources'), findsNothing);
      expect(find.text('Calculation mode'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('calculator controls have labeled touch targets', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpCalculator(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'owner profile presents read-only unavailable results and public profiles never read academics',
    (tester) async {
      final repo = await pumpCalculator(tester, location: '/profile');
      await tester.tap(find.text('ali.alnabulsi'));
      await tester.pumpAndSettle();
      expect(repo.reads, 1);
      expect(find.text('Academic results · private'), findsOneWidget);
      expect(
        find.textContaining('No academic results have been imported'),
        findsOneWidget,
      );
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.byTooltip('Close account information'));
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(AppShell)));
      router.go('/members/$otherId');
      await tester.pumpAndSettle();
      await tester.tap(find.text('maya.haddad'));
      await tester.pumpAndSettle();
      expect(find.text('Academic results · private'), findsNothing);
      expect(repo.reads, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
