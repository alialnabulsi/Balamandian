import 'dart:async';

import 'package:balamandian/domain/models/task_models.dart';
import 'package:balamandian/ui/tasks/view_models/task_planner_view_model.dart';
import 'package:balamandian/ui/tasks/view_models/task_editor_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../auth_test_support.dart';
import '../../profile_test_support.dart';
import '../../task_test_support.dart';
import '../tools/tools_hub_view_model_test.dart' show setRoles;

void main() {
  Future<
    (
      AuthTestHarness,
      FakeProfileRepository,
      FakeTaskRepository,
      TaskPlannerViewModel,
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
    final repo = FakeTaskRepository();
    final model = TaskPlannerViewModel(
      auth: auth.repository,
      profiles: profiles,
      repository: repo,
    );
    addTearDown(model.dispose);
    await Future<void>.delayed(Duration.zero);
    return (auth, profiles, repo, model);
  }

  test('CRUD and both views share all tasks and progress; failures do not apply optimistic status', () async {
    final (_, _, repo, model) = await setup();
    expect(model.progress, 0);
    const draft = TaskDraft(
      title: 'Read',
      details: 'Notes',
      status: TaskStatus.todo,
    );
    expect(await model.save(draft), isTrue);
    expect(model.tasks.single.details, 'Notes');
    model.selectView(PlannerView.kanban);
    expect(model.tasks.length, 1);
    expect(
      await model.changeStatus(model.tasks.single, TaskStatus.done),
      isTrue,
    );
    expect(model.progress, 1);
    model.selectView(PlannerView.list);
    expect(model.completed, 1);
    repo.failure = TaskFailure.network;
    expect(
      await model.changeStatus(model.tasks.single, TaskStatus.todo),
      isFalse,
    );
    expect(model.tasks.single.status, TaskStatus.done);
    expect(model.progress, 1);
    repo.failure = null;
    expect(
      await model.save(
        const TaskDraft(
          title: 'Updated',
          details: '',
          status: TaskStatus.inProgress,
        ),
        original: model.tasks.single,
      ),
      isTrue,
    );
    expect(model.tasks.single.details, isNull);
    expect(model.progress, 0);
    expect(await model.delete(model.tasks.single), isTrue);
    expect(model.tasks, isEmpty);
  });
  test(
    'Pending mutation prevents duplicates/conflicting refresh and status moves',
    () async {
      final (_, _, repo, model) = await setup();
      await model.save(
        const TaskDraft(title: 'Read', details: '', status: TaskStatus.todo),
      );
      final reply = Completer<void>();
      repo.mutationWait = reply.future;
      final pending = model.changeStatus(model.tasks.single, TaskStatus.done);
      expect(model.busy, isTrue);
      expect(await model.delete(model.tasks.single), isFalse);
      expect(
        await model.changeStatus(model.tasks.single, TaskStatus.inProgress),
        isFalse,
      );
      final loads = repo.loads;
      await model.refresh();
      expect(repo.loads, loads);
      expect(model.tasks.single.status, TaskStatus.todo);
      reply.complete();
      expect(await pending, isTrue);
      expect(repo.moves, 1);
    },
  );
  test('Logout clears private state and discards late load/save results from prior session', () async {
    final (auth, _, repo, model) = await setup();
    final response = Completer<List<PlannerTask>>();
    repo.loadRequest = () => response.future;
    final pending = model.refresh();
    await auth.repository.logout(localOnly: true);
    expect(model.tasks, isEmpty);
    expect(model.access, PlannerAccess.guest);
    response.complete([taskFixture(title: 'Private')]);
    await pending;
    expect(model.tasks, isEmpty);
    repo.loadRequest = null;
    await auth.repository.login('FICTION001', 'test');
    await Future<void>.delayed(Duration.zero);
    final mutation = Completer<void>();
    repo.mutationWait = mutation.future;
    final saving = model.save(
      const TaskDraft(
        title: 'Old private',
        details: '',
        status: TaskStatus.todo,
      ),
    );
    await auth.repository.logout(localOnly: true);
    mutation.complete();
    expect(await saving, isFalse);
    expect(model.tasks, isEmpty);
  });
  for (final roles in [
    ['student'],
    ['advisor'],
    ['staff', 'student'],
    ['advisor', 'instructor'],
    ['staff'],
    ['instructor'],
  ]) {
    test('Role $roles protects data requests', () async {
      final (_, _, repo, model) = await setup(roles: roles);
      final eligible = roles.contains('student') || roles.contains('advisor');
      expect(
        model.access,
        eligible ? PlannerAccess.eligible : PlannerAccess.ineligible,
      );
      expect(repo.loads, eligible ? 1 : 0);
    });
  }
  test(
    'Profile error stays distinct from guest and retry restores eligibility',
    () async {
      final auth = AuthTestHarness((_) async => success(sessionData(), 200));
      addTearDown(auth.close);
      await auth.repository.login('FICTION001', 'test');
      final profiles = FakeProfileRepository()..failure = 'Unavailable';
      addTearDown(profiles.dispose);
      final repo = FakeTaskRepository();
      final model = TaskPlannerViewModel(
        auth: auth.repository,
        profiles: profiles,
        repository: repo,
      );
      addTearDown(model.dispose);
      expect(model.access, PlannerAccess.profileError);
      expect(repo.loads, 0);
      profiles.failure = null;
      await model.retryProfile();
      await Future<void>.delayed(Duration.zero);
      expect(model.access, PlannerAccess.eligible);
      expect(repo.loads, 1);
    },
  );
  test(
    'Initial errors retry and failed deletion retains data and progress',
    () async {
      final (_, _, repo, model) = await setup();
      repo.failure = TaskFailure.network;
      await model.refresh();
      expect(model.error, isNotNull);
      repo.failure = null;
      repo.items = [taskFixture(status: TaskStatus.done)];
      await model.refresh();
      expect(model.error, isNull);
      expect(model.progress, 1);
      repo.failure = TaskFailure.network;
      expect(await model.delete(model.tasks.single), isFalse);
      expect(model.tasks.length, 1);
      expect(model.progress, 1);
    },
  );
  test('A different account invalidates late requests and never inherits old tasks', () async {
    var second = false;
    final auth = AuthTestHarness((_) async {
      final data = sessionData();
      if (second) data['user'] = {...data['user']! as Map, 'id': otherId};
      return success(data, 200);
    });
    addTearDown(auth.close);
    await auth.repository.login('FICTION001', 'test');
    final profiles = FakeProfileRepository();
    addTearDown(profiles.dispose);
    await profiles.loadOwn();
    final repo = FakeTaskRepository()
      ..items = [taskFixture(title: 'Private first account')];
    final model = TaskPlannerViewModel(
      auth: auth.repository,
      profiles: profiles,
      repository: repo,
    );
    addTearDown(model.dispose);
    await Future<void>.delayed(Duration.zero);
    final reply = Completer<List<PlannerTask>>();
    repo.loadRequest = () => reply.future;
    final refreshing = model.refresh();
    second = true;
    await auth.repository.login('FICTION002', 'test');
    expect(model.tasks, isEmpty);
    expect(model.access, PlannerAccess.loading);
    reply.complete([taskFixture(title: 'Late private task')]);
    await refreshing;
    expect(model.tasks, isEmpty);
    repo.loadRequest = null;
    repo.items = [];
    profiles.bindSession(otherId, auth.repository.user);
    profiles.ownData = profileJson(id: otherId);
    await profiles.loadOwn();
    await Future<void>.delayed(Duration.zero);
    expect(model.access, PlannerAccess.eligible);
    expect(model.tasks, isEmpty);
  });
  test('Editor matches validation, retains typed text on failure and blocks duplicate saves', () async {
    final (_, _, repo, model) = await setup();
    final editor = TaskEditorViewModel(planner: model);
    addTearDown(editor.dispose);
    expect(await editor.save(), isFalse);
    expect(editor.titleError, isNotNull);
    editor.title = '😀' * 160;
    editor.details = '😀' * 2000;
    expect(editor.titleError, isNull);
    expect(editor.detailsError, isNull);
    editor.title += 'x';
    expect(editor.titleError, isNotNull);
    editor.title = 'Keep this';
    editor.details = 'Keep details';
    repo.failure = TaskFailure.network;
    expect(await editor.save(), isFalse);
    expect(editor.title, 'Keep this');
    expect(editor.error, isNotNull);
    repo.failure = null;
    final reply = Completer<void>();
    repo.mutationWait = reply.future;
    final pending = editor.save();
    expect(await editor.save(), isFalse);
    reply.complete();
    expect(await pending, isTrue);
    expect(repo.creates, 2);
  });
}
