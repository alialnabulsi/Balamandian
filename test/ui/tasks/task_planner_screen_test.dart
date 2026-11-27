import 'package:balamandian/app.dart';
import 'package:balamandian/data/repositories/api_task_repository.dart';
import 'package:balamandian/data/services/task_api_service.dart';
import 'package:http/testing.dart';
import 'package:balamandian/domain/models/task_models.dart';
import 'package:balamandian/ui/auth/widgets/sign_in_prompt.dart';
import 'package:balamandian/ui/auth/widgets/credentials_screen.dart';
import 'package:balamandian/ui/home/widgets/app_shell.dart';
import 'package:balamandian/ui/tasks/widgets/task_planner_screen.dart';
import 'package:balamandian/ui/tasks/widgets/task_editor_sheet.dart';
import 'package:balamandian/ui/tasks/widgets/task_kanban_board.dart';
import 'package:balamandian/ui/tools/widgets/tools_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../auth_test_support.dart';
import '../../marketplace_test_support.dart';
import '../../profile_test_support.dart';
import '../../task_test_support.dart';
import '../home/home_shell_test.dart' show loadHomeFonts;
import '../startup_test_support.dart';
import '../tools/tools_hub_view_model_test.dart' show setRoles;
import '../tools/tools_screen_test.dart' show captureTools;

Future<FakeTaskRepository> pumpPlanner(
  WidgetTester tester, {
  bool guest = false,
  List<String> roles = const ['student'],
  FakeTaskRepository? repository,
  Size size = const Size(412, 915),
  double textScale = 1,
  bool dark = false,
  String location = '/tools/todo',
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
  final profiles = FakeProfileRepository();
  setRoles(profiles, roles);
  addTearDown(profiles.dispose);
  final repo = repository ?? FakeTaskRepository();
  await tester.pumpWidget(
    RepaintBoundary(
      child: MainApp(
        authRepository: auth.repository,
        taskRepository: repo,
        profileRepository: profiles,
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

void main() {
  setUpAll(loadHomeFonts);
  testWidgets('Hub opens planner in shell; Back returns to Tools', (
    tester,
  ) async {
    await pumpPlanner(tester, location: '/tools');
    await tester.tap(find.text('To-do Planner'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskPlannerScreen), findsOneWidget);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.text('0 of 0 completed · 0%'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ToolsScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'CRUD editor preserves failed typed content, clears details and confirms deletion',
    (tester) async {
      final repo = await pumpPlanner(tester);
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(TaskEditorSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.first, 'Plan project');
      await tester.enterText(fields.last, 'Draft notes');
      repo.failure = TaskFailure.network;
      await tester.ensureVisible(find.text('Save task'));
      await tester.tap(find.text('Save task'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditorSheet), findsOneWidget);
      expect(
        tester.widget<TextField>(fields.first).controller!.text,
        'Plan project',
      );
      repo.failure = null;
      await tester.tap(find.text('Save task'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditorSheet), findsNothing);
      expect(find.text('Plan project'), findsOneWidget);
      await tester.tap(find.byTooltip('Edit Plan project'));
      await tester.pumpAndSettle();
      await tester.enterText(fields.last, '');
      await tester.ensureVisible(find.text('Save task'));
      await tester.tap(find.text('Save task'));
      await tester.pumpAndSettle();
      expect(repo.items.single.details, isNull);
      await tester.tap(find.byTooltip('Delete Plan project'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.items.length, 1);
      await tester.tap(find.byTooltip('Delete Plan project'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete task'));
      await tester.pumpAndSettle();
      expect(repo.items, isEmpty);
      expect(find.text('0 of 0 completed · 0%'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Status menu and both views share confirmed status and progress',
    (tester) async {
      final repo = FakeTaskRepository()
        ..items = [taskFixture(details: 'Study notes')];
      await pumpPlanner(tester, repository: repo);
      await tester.tap(find.byTooltip('Change task status. To do'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done').last);
      await tester.pumpAndSettle();
      expect(find.text('1 of 1 completed · 100%'), findsOneWidget);
      await Scrollable.ensureVisible(
        tester.element(find.text('Kanban')),
        alignment: .2,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kanban'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskKanbanBoard), findsOneWidget);
      expect(find.text('Done  1'), findsOneWidget);
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();
      expect(find.text('Read chapter'), findsOneWidget);
      expect(repo.items.single.status, TaskStatus.done);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Unauthenticated planner redirects before reading tasks', (
    tester,
  ) async {
    final repo = await pumpPlanner(tester, guest: true);
    expect(repo.loads, 0);
    expect(find.byType(CredentialsScreen), findsOneWidget);
    expect(find.byType(TaskPlannerScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'Other roles are blocked on direct navigation and cannot query personal tasks',
    (tester) async {
      final repo = await pumpPlanner(tester, roles: ['staff']);
      expect(repo.loads, 0);
      expect(find.text('Student and advisor accounts'), findsOneWidget);
      expect(find.byType(SignInPrompt), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Logout removes private modal text and returns to sign-in', (
    tester,
  ) async {
    final repo = FakeTaskRepository()
      ..items = [taskFixture(title: 'Private title')];
    await pumpPlanner(tester, repository: repo);
    final auth = tester
        .widget<TaskPlannerScreen>(find.byType(TaskPlannerScreen))
        .auth;
    await tester.tap(find.byTooltip('Delete Private title'));
    await tester.pumpAndSettle();
    await auth.logout(localOnly: true);
    await tester.pumpAndSettle();
    expect(find.textContaining('Private title'), findsNothing);
    expect(find.byType(CredentialsScreen), findsOneWidget);
    final router = GoRouter.of(tester.element(find.byType(CredentialsScreen)));
    expect(repo.deletes, 0);
    await auth.login('FICTION001', 'test');
    await tester.pumpAndSettle();
    router.go('/tools/todo');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(TaskEditorSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.first, 'Unsaved private title');
    await tester.pumpAndSettle();
    await auth.logout(localOnly: true);
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditorSheet), findsNothing);
    expect(find.textContaining('Unsaved private title'), findsNothing);
    expect(find.byType(CredentialsScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'Protected task 401 uses the existing expired-session sign-in flow',
    (tester) async {
      mockNativeSplash(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final auth = AuthTestHarness((_) async => success(sessionData(), 200));
      addTearDown(auth.close);
      await auth.repository.login('FICTION001', 'test');
      final api = TaskApiService(
        client: MockClient(
          (_) async => failure('UNAUTHENTICATED', status: 401),
        ),
        baseUrl: Uri.parse('https://example.test'),
      );
      addTearDown(api.close);
      final profiles = FakeProfileRepository();
      addTearDown(profiles.dispose);
      await tester.pumpWidget(
        MainApp(
          authRepository: auth.repository,
          profileRepository: profiles,
          taskRepository: ApiTaskRepository(
            api: api,
            withSession: auth.repository.withSession,
          ),
          marketplaceRepository: FakeMarketplaceRepository(),
          externalUrls: FakeExternalUrlService(),
          onboardingRepository: testOnboardingRepository(completed: true),
          initialLocation: '/tools/todo',
        ),
      );
      await prepareAppSplash(tester);
      await tester.pumpAndSettle();
      expect(find.byType(CredentialsScreen), findsOneWidget);
      expect(auth.repository.user, isNull);
      expect(auth.repository.sessionNotice, isNotNull);
      expect(find.byType(TaskPlannerScreen), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final variant in [
    // Phone, large-text narrow phone, and dark landscape.
    (const Size(412, 915), 1.0, false),
    (const Size(320, 640), 2.0, false),
    (const Size(844, 390), 2.0, true),
  ]) {
    testWidgets('Planner layout, keyboard and accessible controls $variant', (
      tester,
    ) async {
      final repo = FakeTaskRepository()
        ..items = [
          taskFixture(
            title: 'A useful task',
            details: 'A longer description to preview',
          ),
        ];
      await pumpPlanner(
        tester,
        repository: repo,
        size: variant.$1,
        textScale: variant.$2,
        dark: variant.$3,
      );
      expect(tester.takeException(), isNull);
      await captureTools(
        tester,
        'planner-${variant.$1.width}-${variant.$2}-${variant.$3}',
        variant.$1,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Kanban')),
        alignment: .2,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kanban'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final firstColumn = tester.getRect(
        find.byKey(const ValueKey('column-todo')),
      );
      expect(firstColumn.left, greaterThanOrEqualTo(20));
      expect(firstColumn.right, lessThanOrEqualTo(variant.$1.width - 20));
      await captureTools(
        tester,
        'planner-board-${variant.$1.width}-${variant.$2}-${variant.$3}',
        variant.$1,
      );
      await tester.ensureVisible(find.text('Add task'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = FakeViewPadding(bottom: variant.$1.height * .4);
      await tester.pumpAndSettle();
      final title = find
          .descendant(
            of: find.byType(TaskEditorSheet),
            matching: find.byType(TextField),
          )
          .first;
      await tester.enterText(title, 'Keyboard safe');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save task'));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.text('Save task'));
      expect(rect.bottom, lessThanOrEqualTo(variant.$1.height * .6));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Save task'));
      await tester.pumpAndSettle();
      expect(repo.items.any((task) => task.title == 'Keyboard safe'), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'Long press produces one haptic, lifts, highlights and drops; cancellation/current column do nothing',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1100, 600);
      addTearDown(tester.view.reset);
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final moves = <TaskStatus>[];
      final task = taskFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskKanbanBoard(
              tasks: [task],
              enabled: true,
              onEdit: (_) {},
              onDelete: (_) {},
              onStatus: (_, status) => moves.add(status),
            ),
          ),
        ),
      );
      final card = find.byKey(ValueKey('drag-${task.id}'));
      Future<TestGesture> start() async {
        final gesture = await tester.startGesture(
          tester.getTopLeft(card) + const Offset(40, 25),
        );
        await tester.pump(const Duration(milliseconds: 600));
        return gesture;
      }

      final gesture = await start();
      expect(
        calls.where((call) => call.method == 'HapticFeedback.vibrate').length,
        1,
      );
      await gesture.moveTo(
        tester.getTopLeft(find.byKey(const ValueKey('column-done'))) +
            const Offset(80, 90),
      );
      await tester.pump(const Duration(milliseconds: 16));
      final target = tester.widget<Container>(
        find.byKey(const ValueKey('column-done')),
      );
      expect(
        (target.decoration as BoxDecoration).color,
        Theme.of(tester.element(find.byKey(const ValueKey('column-done'))))
            .colorScheme
            .primaryContainer,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(moves, [TaskStatus.done]);
      moves.clear();
      final same = await start();
      await same.moveBy(const Offset(15, 15));
      await same.up();
      await tester.pumpAndSettle();
      expect(moves, isEmpty);
      final outside = await start();
      await outside.moveTo(const Offset(500, 650));
      await outside.up();
      await tester.pumpAndSettle();
      expect(moves, isEmpty);
      final canceled = await start();
      await canceled.moveTo(
        tester.getTopLeft(find.byKey(const ValueKey('column-done'))) +
            const Offset(80, 90),
      );
      await tester.pump(const Duration(milliseconds: 16));
      await canceled.cancel();
      await tester.pumpAndSettle();
      expect(moves, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Phone edge scrolling reaches the last Kanban column during a drag',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 600);
      addTearDown(tester.view.reset);
      final task = taskFixture();
      final moves = <TaskStatus>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskKanbanBoard(
              tasks: [task],
              enabled: true,
              onEdit: (_) {},
              onDelete: (_) {},
              onStatus: (_, status) => moves.add(status),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getTopLeft(find.byKey(ValueKey('drag-${task.id}'))) +
            const Offset(30, 30),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(const Offset(338, 100));
      for (var i = 0; i < 150; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(moves, [TaskStatus.done]);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
