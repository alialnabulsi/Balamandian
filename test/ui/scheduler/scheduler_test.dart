import 'dart:async';
import 'dart:convert';

import 'package:balamandian/domain/models/tool_failure.dart';

import 'package:balamandian/data/repositories/scheduler_repository.dart';
import 'package:balamandian/data/services/tools_api_service.dart';
import 'package:balamandian/domain/models/schedule_models.dart';
import 'package:balamandian/ui/tools/view_models/tool_session.dart';
import 'package:balamandian/ui/scheduler/view_models/scheduler_view_model.dart';
import 'package:balamandian/ui/scheduler/widgets/scheduler_screen.dart';
import 'package:balamandian/ui/scheduler/widgets/schedule_timetable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../auth_test_support.dart';
import '../../profile_test_support.dart';
import '../../marketplace_test_support.dart';
import '../home/home_shell_test.dart' show loadHomeFonts;
import '../tools/tools_hub_view_model_test.dart' show setRoles;

Map<String, Object?> fixture() => {
  'semester': {
    'id': 'spring',
    'label': 'Spring',
    'phase': 'upcoming',
    'version': 's1',
  },
  'planning': {'enabled': true, 'reason': 'Verified open registration'},
  'sourceStale': false,
  'draftStale': false,
  'offerings': {
    'source': 'Explicit test fixture',
    'version': 'o1',
    'syncedAt': '2026-11-26T00:00:00Z',
    'data': {
      'courses': [
        {'id': 'A', 'title': 'Fixture course', 'credits': 3},
      ],
    },
  },
  'member': {
    'version': 'm1',
    'syncedAt': '2026-11-26T00:00:00Z',
    'data': {
      'eligibility': {
        'A': {'status': 'eligible', 'reason': null},
      },
      'progress': {'earnedCredits': 30, 'requiredCredits': 120},
    },
  },
  'actual': [],
  'draft': null,
};
Map<String, Object?> option() => {
  'key': 'A:A1',
  'credits': 3,
  'courses': [
    {
      'courseId': 'A',
      'title': 'Fixture course',
      'credits': 3,
      'bundle': {
        'id': 'A1',
        'components': [
          {
            'id': 'lec',
            'kind': 'lecture',
            'label': 'Lecture A1',
            'meetings': [
              {
                'days': [1, 3],
                'startMinute': 540,
                'endMinute': 600,
                'startDate': '2027-01-04',
                'endDate': '2027-05-31',
                'weekInterval': 1,
                'weekAnchor': '2027-01-04',
                'location': 'Test location',
              },
            ],
          },
        ],
      },
    },
  ],
};

class FakeSchedulerRepository implements SchedulerRepository {
  bool fail = false;
  Future<void>? wait;
  int reads = 0;
  bool empty = false;
  bool saved = false;
  bool conflict = false, registered = false;
  @override
  Future<List<AcademicSemester>> semesters() async => empty
      ? []
      : [const AcademicSemester('spring', 'Spring', 'upcoming', 's1')];
  @override
  Future<ScheduleData> read(String semester) async {
    reads++;
    await wait;
    return ScheduleData.fromJson({
      ...fixture(),
      if (registered)
        'planning': {'enabled': false, 'reason': 'Already registered'},
      if (registered)
        'member': {
          'data': {'registration': 'registered'},
        },
      'draft': saved ? {'revision': 1, 'option': option()} : null,
    });
  }

  @override
  Future<ScheduleData> refresh(String semester) async {
    throw StateError('SIS unavailable');
  }

  @override
  Future<ScheduleGeneration> generate(
    ScheduleData data,
    List<String> pool,
    double credits,
  ) async {
    if (fail) throw StateError('failed');
    return ScheduleGeneration.fromJson({
      'outcome': 'complete',
      'message': 'One verified combination',
      'options': [option()],
      'reasons': [],
    });
  }

  @override
  Future<void> save(ScheduleData data, ScheduleOption option) async {
    if (fail) throw StateError('failed');
    if (conflict) throw ToolFailure.fromCode('CONFLICT');
    saved = true;
  }

  @override
  Future<void> registrationReminder(String semester, int minutes) async {}
  @override
  Future<void> deleteDraft(ScheduleData data) async {
    saved = false;
  }

  @override
  Future<void> syncSemesters() async {}
  @override
  void cancelPending() {}
}

void main() {
  setUpAll(loadHomeFonts);
  test('API mapping uses versioned source, subset pool and section IDs; no client academic records', () async {
    final requests = <http.Request>[];
    final api = ToolsApiService(
      client: MockClient((q) async {
        requests.add(q);
        if (q.url.path.endsWith('/generate')) {
          return http.Response(
            jsonEncode({
              'data': {
                'outcome': 'complete',
                'message': 'OK',
                'options': [option()],
                'reasons': [],
              },
            }),
            200,
          );
        }
        if (q.url.path.endsWith('/draft')) {
          return http.Response(
            jsonEncode({
              'data': {'message': 'draft only'},
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'data': fixture()}), 200);
      }),
      baseUrl: Uri.parse('https://example.test'),
      feature: 'scheduler',
    );
    addTearDown(api.close);
    final repo = ApiSchedulerRepository(api, <T>(run) => run('opaque'));
    final data = await repo.read('spring');
    expect(data.actual, isEmpty);
    expect(data.draft, isNull);
    expect(data.candidates.single.id, 'A');
    final generated = await repo.generate(data, ['A', 'B', 'C'], 3);
    expect(generated.options.single.credits, 3);
    expect((jsonDecode(requests[1].body) as Map)['candidateIds'], [
      'A',
      'B',
      'C',
    ]);
    await repo.save(data, generated.options.single);
    final body = jsonDecode(requests.last.body) as Map;
    expect(body['courseBundles'], [
      {'courseId': 'A', 'bundleId': 'A1'},
    ]);
    expect(body.containsKey('completed'), false);
  });
  test('meeting weekday/date ranges use date-only semantics', () {
    final m = ScheduleOption.fromJson(option())
        .courses
        .single
        .components
        .single
        .meetings!
        .single;
    expect(m.occurs(DateTime(2027, 1, 4)), true);
    expect(m.occurs(DateTime(2027, 1, 5)), false);
    expect(m.occurs(DateTime(2027, 6, 7)), false);
  });
  test('failed mutations preserve cached actual schedule; account change ignores late data', () async {
    final auth = AuthTestHarness(
      (q) async => q.url.path.endsWith('/logout')
          ? http.Response('', 204)
          : success(sessionData(), 200),
    );
    addTearDown(auth.close);
    await auth.repository.login('FIRST', 'test');
    final profiles = FakeProfileRepository();
    addTearDown(profiles.dispose);
    setRoles(profiles, ['student']);
    await profiles.loadOwn();
    final repo = FakeSchedulerRepository();
    final session = ToolSession(
      auth: auth.repository,
      profiles: profiles,
      cancelPending: repo.cancelPending,
    );
    addTearDown(session.dispose);
    final model = SchedulerViewModel(session, repo);
    addTearDown(model.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(model.data, isNotNull);
    final old = model.data;
    await model.refresh();
    expect(model.data, same(old));
    expect(model.error, isNotNull);
    model.select('A', true);
    await model.generate();
    expect(model.generated!.options.length, 1);
    repo.fail = true;
    await model.save(model.generated!.options.single);
    expect(model.data, same(old));
    expect(model.error, isNotNull);
    repo.fail = false;
    repo.conflict = true;
    repo.registered = true;
    await model.save(model.generated!.options.single);
    expect(model.data!.registration, 'registered');
    expect(model.data!.canPlan, false);
    expect(model.generated, isNull);
    expect(model.creating, false);
    final late = Completer<void>();
    repo.wait = late.future;
    final pending = model.choose('spring');
    await auth.repository.logout();
    late.complete();
    await pending;
    expect(model.data, isNull);
    expect(model.selected, isEmpty);
    expect(model.generated, isNull);
  });
  for (final roles in [
    ['student'],
    ['advisor', 'staff'],
    ['staff'],
  ]) {
    testWidgets(
      'direct Schedule access $roles and responsive unavailable state',
      (tester) async {
        tester.view.physicalSize = const Size(360, 700);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final auth = AuthTestHarness((_) async => success(sessionData(), 200));
        addTearDown(auth.close);
        await auth.repository.login('FIRST', 'test');
        final profiles = FakeProfileRepository();
        addTearDown(profiles.dispose);
        setRoles(profiles, roles);
        await profiles.loadOwn();
        final repo = FakeSchedulerRepository()..empty = true;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SchedulerScreen(
                auth: auth.repository,
                profiles: profiles,
                repository: repo,
                externalUrls: FakeExternalUrlService(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('No semester data yet'),
          roles.contains('student') || roles.contains('advisor')
              ? findsOneWidget
              : findsNothing,
        );
        expect(repo.reads, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'actual and proposed views stay distinct; pool generation and timetable detail',
    (tester) async {
      final auth = AuthTestHarness((_) async => success(sessionData(), 200));
      addTearDown(auth.close);
      await auth.repository.login('FIRST', 'test');
      final profiles = FakeProfileRepository();
      addTearDown(profiles.dispose);
      setRoles(profiles, ['student']);
      await profiles.loadOwn();
      final repo = FakeSchedulerRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SchedulerScreen(
              auth: auth.repository,
              profiles: profiles,
              repository: repo,
              externalUrls: FakeExternalUrlService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Create a schedule'), findsOneWidget);
      await tester.tap(find.text('Create a schedule'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Study-plan credits'), findsOneWidget);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Generate schedules'));
      await tester.tap(find.text('Generate schedules'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('View timetable'));
      await tester.tap(find.text('View timetable'));
      await tester.pumpAndSettle();
      expect(find.byType(ScheduleTimetable), findsOneWidget);
      expect(find.text('Proposed timetable - NOT registered'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Choose schedule'));
      await tester.tap(find.text('Choose schedule'));
      await tester.pumpAndSettle();
      expect(find.text('Generate schedules'), findsNothing);
      expect(find.byType(ScheduleTimetable), findsOneWidget);
      await tester.ensureVisible(find.text('Delete proposed schedule'));
      await tester.tap(find.text('Delete proposed schedule'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Create a schedule'), findsOneWidget);

      expect(tester.takeException(), isNull);
    },
  );
}
