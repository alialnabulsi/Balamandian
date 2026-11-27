import 'dart:async';

import 'package:balamandian/domain/models/academic_profile.dart';
import 'package:balamandian/domain/models/gpa_calculation.dart';
import 'package:balamandian/domain/models/profile_models.dart';
import 'package:balamandian/ui/gpa/view_models/academic_profile_view_model.dart';
import 'package:balamandian/ui/gpa/view_models/gpa_calculator_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../academic_test_support.dart';
import '../../auth_test_support.dart';
import '../../profile_test_support.dart';
import '../tools/tools_hub_view_model_test.dart' show setRoles;

void main() {
  Future<
    (
      AuthTestHarness,
      FakeProfileRepository,
      FakeAcademicRepository,
      GpaCalculatorViewModel,
    )
  >
  setup({List<String> roles = const ['student']}) async {
    final auth = AuthTestHarness((_) async => success(sessionData(), 200));
    addTearDown(auth.close);
    await auth.repository.login('FICTION001', 'test');
    final profiles = FakeProfileRepository();
    addTearDown(profiles.dispose);
    setRoles(profiles, roles);
    await profiles.loadOwn();
    final repo = FakeAcademicRepository();
    final model = GpaCalculatorViewModel(
      auth: auth.repository,
      profiles: profiles,
      repository: repo,
    );
    addTearDown(model.dispose);
    return (auth, profiles, repo, model);
  }

  void enterCourse(GpaCalculatorViewModel model) {
    model.addCourse();
    model.updateCourse(
      model.courses.last.copyWith(name: 'COMP', credits: '3', grade: '90'),
    );
  }

  test('real SIS import uses exact cumulative totals; failed refresh preserves subsequent manual edits', () async {
    final (_, _, repo, model) = await setup();
    repo.value = const AcademicProfile(
      gpa: AcademicMetric(90, 3.9, 3, 270),
      cgpa: AcademicMetric(80.12345, 3, 30, 2403.7035),
      semesterLabel: 'Fall',
      syncedAt: null,
      earnedCredits: 27,
    );
    enterCourse(model);
    await model.importSis();
    expect(
      model.calculation.cumulative!.average,
      closeTo((2403.7035 + 270) / 33, 1e-10),
    );
    expect(model.academic.snapshot!.gpa!.equivalent, 3.9);
    model.setBaseline(average: '75', credits: '30');
    repo.failure = ProfileFailure.fromCode('NETWORK_ERROR');
    await model.importSis();
    expect(model.priorAverage, '75');
    expect(model.calculation.cumulative!.average, closeTo(2520 / 33, 1e-10));
  });
  test('courses and baseline update predictions locally, missing baseline stays missing', () async {
    final (_, _, repo, model) = await setup();
    enterCourse(model);
    expect(model.calculation.semester!.average, 90);
    expect(model.calculation.cumulative, isNull);
    model.selectMode(BaselineMode.manual);
    model.setBaseline(average: '75', credits: '30');
    expect(model.calculation.cumulative!.average, closeTo(2520 / 33, 1e-12));
    model.setBaseline(average: '4');
    expect(model.calculation.cumulative, isNull);
    expect(model.calculation.semester, isNotNull);
    model.selectMode(BaselineMode.firstSemester);
    expect(model.calculation.cumulative!.average, 90);
    model.removeCourse(model.courses.single.id);
    expect(model.calculation.semester, isNull);
    expect(repo.reads, 0);
  });
  test('unavailable or failed import preserves manual work, retry and duplicate protection', () async {
    final (_, _, repo, model) = await setup();
    model.selectMode(BaselineMode.manual);
    model.setBaseline(average: '81.123', credits: '45');
    enterCourse(model);
    repo.failure = ProfileFailure.fromCode('NETWORK_ERROR');
    await model.academic.load();
    expect(model.academic.error, isNotNull);
    expect(model.priorAverage, '81.123');
    expect(model.courses.single.name, 'COMP');
    repo.failure = null;
    final reply = Completer<AcademicProfile>();
    repo.pending = reply.future;
    final loading = model.academic.load();
    await model.academic.load();
    expect(repo.reads, 2);
    reply.complete(const AcademicProfile.unavailable());
    await loading;
    expect(model.academic.snapshot, isNotNull);
    expect(model.priorCredits, '45');
    expect(model.mode, BaselineMode.manual);
  });
  for (final roles in [
    ['student'],
    ['student', 'advisor'],
    ['student', 'system_admin'],
    ['advisor'],
    ['staff'],
  ]) {
    test('student-containing eligibility: $roles', () async {
      final (_, _, repo, model) = await setup(roles: roles);
      model.addCourse();
      await model.academic.load();
      expect(model.eligible, roles.contains('student'));
      expect(model.courses.length, roles.contains('student') ? 1 : 0);
      expect(repo.reads, roles.contains('student') ? 1 : 0);
    });
  }
  test(
    'reset invalidates in-flight import and removes all temporary state',
    () async {
      final (_, _, repo, model) = await setup();
      enterCourse(model);
      final reply = Completer<AcademicProfile>();
      repo.pending = reply.future;
      final loading = model.academic.load();
      model.reset();
      reply.complete(const AcademicProfile.unavailable());
      await loading;
      expect(model.courses, isEmpty);
      expect(model.priorAverage, isEmpty);
      expect(model.academic.snapshot, isNull);
      expect(model.academic.loading, isFalse);
    },
  );
  test(
    'account change discards scenario and ignores stale success and failure',
    () async {
      for (final fail in [false, true]) {
        var second = false;
        final auth = AuthTestHarness((_) async {
          final data = sessionData();
          if (second) data['user'] = {...data['user']! as Map, 'id': otherId};
          return success(data, 200);
        });
        addTearDown(auth.close);
        await auth.repository.login('FIRST', 'test');
        final profiles = FakeProfileRepository();
        addTearDown(profiles.dispose);
        await profiles.loadOwn();
        final repo = FakeAcademicRepository();
        final model = GpaCalculatorViewModel(
          auth: auth.repository,
          profiles: profiles,
          repository: repo,
        );
        addTearDown(model.dispose);
        enterCourse(model);
        final reply = Completer<AcademicProfile>();
        repo.pending = reply.future;
        final loading = model.academic.load();
        second = true;
        await auth.repository.login('SECOND', 'test');
        expect(model.courses, isEmpty);
        expect(model.academic.access, StudentAccess.loading);
        if (fail) {
          reply.completeError(ProfileFailure.fromCode('NETWORK_ERROR'));
        } else {
          reply.complete(const AcademicProfile.unavailable());
        }
        await loading;
        expect(model.academic.snapshot, isNull);
        expect(model.academic.error, isNull);
        profiles.bindSession(otherId, auth.repository.user);
        profiles.ownData = profileJson(id: otherId);
        await profiles.loadOwn();
        expect(model.eligible, isTrue);
        expect(model.courses, isEmpty);
      }
    },
  );
  test(
    'profile loading and retryable failure differ from guest identity',
    () async {
      final auth = AuthTestHarness((_) async => success(sessionData(), 200));
      addTearDown(auth.close);
      final profiles = FakeProfileRepository();
      addTearDown(profiles.dispose);
      await auth.repository.restoreSession();
      final model = GpaCalculatorViewModel(
        auth: auth.repository,
        profiles: profiles,
        repository: FakeAcademicRepository(),
      );
      addTearDown(model.dispose);
      expect(model.academic.access, StudentAccess.guest);
      await auth.repository.login('FIRST', 'test');
      expect(model.academic.access, StudentAccess.loading);
      profiles.failure = 'Offline';
      profiles.notifyListeners();
      expect(model.academic.access, StudentAccess.profileError);
      profiles.failure = null;
      await model.academic.retryProfile();
      enterCourse(model);
      await auth.repository.logout(localOnly: true);
      expect(model.courses, isEmpty);
      expect(model.academic.access, StudentAccess.guest);
    },
  );
}
