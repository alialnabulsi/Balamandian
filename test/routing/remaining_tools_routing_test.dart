import 'package:balamandian/ui/calendar/widgets/campus_month_calendar.dart';
import 'package:balamandian/app.dart';
import 'package:balamandian/data/repositories/lost_found_repository.dart';
import 'package:balamandian/data/services/tools_api_service.dart';
import 'package:balamandian/ui/calendar/widgets/campus_calendar_screen.dart';
import 'package:balamandian/ui/calendar/widgets/calendar_event_details.dart';
import 'package:balamandian/ui/lost_found/widgets/lost_found_screen.dart';
import 'package:balamandian/ui/scheduler/widgets/scheduler_screen.dart';
import 'package:balamandian/ui/tools/view_models/tool_session.dart';
import 'package:balamandian/ui/tools/widgets/tool_scoped_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';

import '../auth_test_support.dart';
import '../profile_test_support.dart';
import '../marketplace_test_support.dart';
import '../task_test_support.dart';
import '../academic_test_support.dart';
import '../notes_test_support.dart';
import '../ui/calendar/calendar_test.dart'
    show FakeCalendarRepository, FakeCalendarDevice;
import '../ui/scheduler/scheduler_test.dart' show FakeSchedulerRepository;
import '../ui/home/home_shell_test.dart' show loadHomeFonts;
import '../ui/tools/tools_hub_view_model_test.dart' show setRoles;
import '../ui/startup_test_support.dart';

class InitialCalendarDevice extends FakeCalendarDevice {
  Map<String, String>? link;
  @override
  Future<Map<String, String>?> initialLink() async => link;
}

Future<(AuthTestHarness, FakeCalendarDevice)> pumpTools(
  WidgetTester tester,
  String location, {
  bool guest = false,
  Map<String, String>? cold,
}) async {
  mockNativeSplash(tester);
  final auth = AuthTestHarness((_) async => success(sessionData(), 200));
  addTearDown(auth.close);
  if (!guest) await auth.repository.login('FIRST', 'test');
  final profiles = FakeProfileRepository();
  addTearDown(profiles.dispose);
  setRoles(profiles, ['student']);
  final device = InitialCalendarDevice()..link = cold;
  final api = ToolsApiService(
    client: MockClient(
      (_) async => throw StateError('No private L&F API expected'),
    ),
    baseUrl: Uri.parse('https://example.test'),
    feature: 'lost-found',
  );
  addTearDown(api.close);
  await tester.pumpWidget(
    MainApp(
      authRepository: auth.repository,
      profileRepository: profiles,
      lostFoundRepository: ApiLostFoundRepository(
        api,
        auth.repository.withSession,
      ),
      calendarRepository: FakeCalendarRepository(),
      calendarReminders: device,
      schedulerRepository: FakeSchedulerRepository()..empty = true,
      notesRepository: FakeNotesRepository(),
      noteDrafts: MemoryNoteDrafts(),
      noteFiles: FakeNoteFiles(),
      taskRepository: FakeTaskRepository(),
      academicRepository: FakeAcademicRepository(),
      marketplaceRepository: FakeMarketplaceRepository(),
      externalUrls: FakeExternalUrlService(),
      onboardingRepository: testOnboardingRepository(completed: true),
      initialLocation: location,
    ),
  );
  await prepareAppSplash(tester);
  await tester.pumpAndSettle();
  return (auth, device);
}

void main() {
  setUpAll(loadHomeFonts);
  for (final path in ['/tools/lost-found', '/tools/scheduler']) {
    testWidgets('guest direct $path is a sign-in gate', (tester) async {
      await pumpTools(tester, path, guest: true);
      expect(
        find.byType(
          path.endsWith('scheduler') ? SchedulerScreen : LostFoundScreen,
        ),
        findsOneWidget,
      );
      expect(find.text('Sign in'), findsWidgets);
      expect(find.textContaining('Checking account'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('guest calendar is public and Back preserves the Tools shell', (
    tester,
  ) async {
    await pumpTools(tester, '/tools/calendar', guest: true);
    expect(find.byType(CampusCalendarScreen), findsOneWidget);
    expect(find.byType(CampusMonthCalendar), findsOneWidget);
    await tester.tap(find.byTooltip('Back to Tools'));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('GPA Calculator'));
    expect(
      GoRouter.of(context).routeInformationProvider.value.uri.path,
      '/tools',
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'cold and warm notification deep links open only the active owner event',
    (tester) async {
      final (auth, device) = await pumpTools(
        tester,
        '/tools',
        cold: {'owner': ownId, 'event': 'event'},
      );
      expect(find.byType(CalendarEventDetails), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      device.callback!({'owner': otherId, 'event': 'event'});
      await tester.pumpAndSettle();
      expect(find.byType(CalendarEventDetails), findsNothing);
      device.callback!({'owner': ownId, 'event': 'event'});
      await tester.pumpAndSettle();
      expect(find.byType(CalendarEventDetails), findsOneWidget);
      await auth.repository.logout(localOnly: true);
      await tester.pumpAndSettle();
      expect(find.byType(CalendarEventDetails), findsNothing);
      expect(device.pending, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('account transition hides private nested dialogs', (
    tester,
  ) async {
    final auth = AuthTestHarness((_) async => success(sessionData(), 200));
    addTearDown(auth.close);
    await auth.repository.login('FIRST', 'test');
    final profiles = FakeProfileRepository();
    addTearDown(profiles.dispose);
    setRoles(profiles, ['student']);
    await profiles.loadOwn();
    final session = ToolSession(
      auth: auth.repository,
      profiles: profiles,
      cancelPending: () {},
    );
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ToolScopedDialog(
                  session: session,
                  child: const AlertDialog(
                    content: Text('Private owner content'),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Private owner content'), findsOneWidget);
    await auth.repository.logout(localOnly: true);
    await tester.pumpAndSettle();
    expect(find.text('Private owner content'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test('profile loading/error is distinct from a guest; mixed roles become eligible', () async {
    final auth = AuthTestHarness((_) async => success(sessionData(), 200));
    addTearDown(auth.close);
    await auth.repository.login('FIRST', 'test');
    final profiles = FakeProfileRepository();
    addTearDown(profiles.dispose);
    final session = ToolSession(
      auth: auth.repository,
      profiles: profiles,
      cancelPending: () {},
    );
    addTearDown(session.dispose);
    expect(session.access, ToolAccess.loading);
    profiles.failure = 'Profile unavailable';
    profiles.notifyListeners();
    expect(session.access, ToolAccess.profileError);
    profiles.failure = null;
    setRoles(profiles, ['staff', 'advisor']);
    await profiles.loadOwn();
    expect(session.access, ToolAccess.eligible);
  });
}
