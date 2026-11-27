import 'package:balamandian/ui/calendar/widgets/campus_month_calendar.dart';

import 'dart:async';

import 'package:balamandian/data/repositories/calendar_repository.dart';
import 'package:balamandian/data/services/calendar_reminder_service.dart';
import 'package:balamandian/domain/models/calendar_models.dart';
import 'package:balamandian/ui/tools/view_models/tool_session.dart';
import 'package:balamandian/ui/calendar/view_models/calendar_reminder_coordinator.dart';
import 'package:balamandian/ui/calendar/view_models/event_editor_view_model.dart';
import 'package:balamandian/ui/calendar/widgets/event_editor.dart';
import 'package:balamandian/ui/calendar/widgets/campus_calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../auth_test_support.dart';
import '../../profile_test_support.dart';
import '../../marketplace_test_support.dart';
import '../home/home_shell_test.dart' show loadHomeFonts;
import '../tools/tools_hub_view_model_test.dart' show setRoles;

CampusEvent fixture({String id = 'event', int? lead = 15}) => CampusEvent(
  id: id,
  title: 'Private event',
  category: CalendarCategory.personal,
  allDay: true,
  start: '2027-04-01',
  end: '2027-04-04',
  revision: 1,
  reminderMinutes: lead,
  reminderAt: lead == null ? null : DateTime.utc(2027, 4, 1, 5),
);

class FakeCalendarRepository implements CalendarRepository {
  @override
  Future<DateTime> today() async => DateTime(2026, 11, 26);
  List<CampusEvent> data = [fixture()];
  bool fail = false;
  Future<void>? wait;
  bool? lastMember;
  int saves = 0, cancels = 0;
  @override
  Future<List<CampusEvent>> list(
    DateTime from,
    DateTime to, {
    required bool member,
  }) async {
    lastMember = member;
    await wait;
    if (fail) throw StateError('offline');
    return member ? data : [];
  }

  @override
  Future<CampusEvent> read(String id, {required bool member}) async =>
      data.firstWhere((e) => e.id == id);
  @override
  Future<CampusEvent> save(Map<String, Object?> body, {String? id}) async {
    saves++;
    if (fail) throw StateError('offline');
    return data.first;
  }

  @override
  Future<void> delete(CampusEvent e) async {
    data.remove(e);
  }

  @override
  Future<CampusEvent> reminder(String id, int? minutes) async =>
      fixture(id: id, lead: minutes);
  @override
  Future<List<CampusEvent>> reminders() async {
    await wait;
    return data;
  }

  @override
  void cancelPending() {
    cancels++;
  }
}

class FakeCalendarDevice implements CalendarReminderService {
  bool enabled = true;
  String? owner;
  List<CampusEvent> pending = [];
  int replacements = 0;
  void Function(Map<String, String>)? callback;
  @override
  Future<bool> permission({bool request = false}) async => enabled;
  @override
  Future<void> replace(String? owner, List<CampusEvent> events) async {
    this.owner = owner;
    pending = List.of(events);
    replacements++;
  }

  @override
  Future<Map<String, String>?> initialLink() async => null;
  @override
  void onLink(void Function(Map<String, String>)? c) {
    callback = c;
  }
}

void main() {
  setUpAll(loadHomeFonts);
  test('date-only multi-day agenda excludes exclusive end', () {
    final e = fixture();
    expect(e.onDay(DateTime(2027, 4, 1)), true);
    expect(e.onDay(DateTime(2027, 4, 3)), true);
    expect(e.onDay(DateTime(2027, 4, 4)), false);
    expect(e.onDay(DateTime(2027, 3, 31)), false);
  });
  testWidgets(
    'reminders reconcile once per ID, edits, deletion, permission and account change',
    (tester) async {
      final auth = AuthTestHarness(
        (q) async => q.url.path.endsWith('/logout')
            ? http.Response('', 204)
            : success(sessionData(), 200),
      );
      addTearDown(auth.close);
      await auth.repository.login('FIRST', 'test');
      final profiles = FakeProfileRepository();
      addTearDown(profiles.dispose);
      setRoles(profiles, ['advisor', 'staff']);
      await profiles.loadOwn();
      final repo = FakeCalendarRepository(), device = FakeCalendarDevice();
      final session = ToolSession(
        auth: auth.repository,
        profiles: profiles,
        cancelPending: repo.cancelPending,
      );
      final sync = CalendarReminderCoordinator(session, repo, device);
      addTearDown(sync.dispose);
      addTearDown(session.dispose);
      await sync.refresh();
      expect(device.pending.single.id, 'event');
      await sync.refresh();
      expect(device.pending.length, 1);
      repo.data = [fixture(lead: 60)];
      await sync.refresh();
      expect(device.pending.single.reminderMinutes, 60);
      repo.data = [];
      await sync.refresh();
      expect(device.pending, isEmpty);
      repo.data = [fixture()];
      device.enabled = false;
      await sync.refresh(requestPermission: true);
      expect(device.pending, isEmpty);
      expect(sync.message, contains('disabled'));
      device.enabled = true;
      final late = Completer<void>();
      repo.wait = late.future;
      final pending = sync.refresh();
      await auth.repository.logout();
      late.complete();
      await pending;
      await tester.pump();
      expect(device.owner, isNull);
      expect(device.pending, isEmpty);
    },
  );
  testWidgets(
    'public Calendar is readable, filters, month navigation and large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final auth = AuthTestHarness(
        (_) async => throw StateError('No authentication expected'),
      );
      addTearDown(auth.close);
      await auth.repository.restoreSession();
      final profiles = FakeProfileRepository();
      addTearDown(profiles.dispose);
      final repo = FakeCalendarRepository(), device = FakeCalendarDevice();
      final session = ToolSession(
        auth: auth.repository,
        profiles: profiles,
        cancelPending: repo.cancelPending,
      );
      final sync = CalendarReminderCoordinator(session, repo, device);
      addTearDown(sync.dispose);
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampusCalendarScreen(
              repository: repo,
              session: session,
              reminders: sync,
              externalUrls: FakeExternalUrlService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.lastMember, false);
      expect(find.byType(CampusMonthCalendar), findsOneWidget);
      expect(find.text('Personal event'), findsNothing);
      await tester.tap(find.text('Academic'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('keyboard-safe event editor retains content on save failure', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.reset);
    final auth = AuthTestHarness((_) async => success(sessionData(), 200));
    addTearDown(auth.close);
    await auth.repository.login('FIRST', 'test');
    final profiles = FakeProfileRepository();
    addTearDown(profiles.dispose);
    setRoles(profiles, ['student']);
    await profiles.loadOwn();
    final repo = FakeCalendarRepository()..fail = true,
        device = FakeCalendarDevice();
    final session = ToolSession(
      auth: auth.repository,
      profiles: profiles,
      cancelPending: repo.cancelPending,
    );
    final sync = CalendarReminderCoordinator(session, repo, device);
    addTearDown(sync.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventEditor(
            day: DateTime(2027, 4, 1),
            model: EventEditorViewModel(repo, session, sync, null),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, 'Preserved');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Preserved'), findsOneWidget);
    expect(repo.saves, 1);
    expect(
      find.text('Unable to save. Your typed content is retained.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
