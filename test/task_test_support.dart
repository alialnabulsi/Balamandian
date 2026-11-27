import 'package:balamandian/data/repositories/task_repository.dart';
import 'package:balamandian/domain/models/task_models.dart';

Map<String, Object?> taskJson({
  int number = 1,
  String title = 'Read chapter',
  String? details,
  TaskStatus status = TaskStatus.todo,
}) => {
  'id': '00000000-0000-4000-8000-${number.toString().padLeft(12, '0')}',
  'title': title,
  'details': details,
  'status': status.value,
  'createdAt': '2026-11-25T10:00:00.000Z',
  'updatedAt': '2026-11-25T10:01:00.000Z',
};
PlannerTask taskFixture({
  int number = 1,
  String title = 'Read chapter',
  String? details,
  TaskStatus status = TaskStatus.todo,
}) => PlannerTask.fromJson(
  taskJson(number: number, title: title, details: details, status: status),
);
Map<String, Object?> taskPageJson(
  List<Map<String, Object?>> items, {
  int page = 1,
  int? total,
  int? completed,
  bool hasNext = false,
}) => {
  'items': items,
  'pagination': {
    'page': page,
    'limit': 50,
    'totalItems': total ?? items.length,
    'hasNextPage': hasNext,
  },
  'progress': {
    'totalTasks': total ?? items.length,
    'completedTasks':
        completed ?? items.where((task) => task['status'] == 'done').length,
    'percentage': (total ?? items.length) == 0 ? 0 : 50,
  },
};

class FakeTaskRepository implements TaskRepository {
  List<PlannerTask> items = [];
  Object? failure;
  int loads = 0, creates = 0, updates = 0, moves = 0, deletes = 0;
  Future<List<PlannerTask>> Function()? loadRequest;
  Future<void>? mutationWait;
  PlannerTask _saved(PlannerTask old, TaskDraft draft) => PlannerTask(
    id: old.id,
    title: draft.title.trim(),
    details: draft.details.trim().isEmpty ? null : draft.details.trim(),
    status: draft.status,
    createdAt: old.createdAt,
    updatedAt: old.updatedAt,
  );
  Future<void> _mutate() async {
    await mutationWait;
    if (failure != null) throw failure!;
  }

  @override
  Future<List<PlannerTask>> loadAll() async {
    loads++;
    if (loadRequest != null) return loadRequest!();
    if (failure != null) throw failure!;
    return List.of(items);
  }

  @override
  Future<PlannerTask> create(TaskDraft draft) async {
    creates++;
    await _mutate();
    final value = _saved(taskFixture(number: items.length + 100), draft);
    items.add(value);
    return value;
  }

  @override
  Future<PlannerTask> update(String id, TaskDraft draft) async {
    updates++;
    await _mutate();
    final index = items.indexWhere((task) => task.id == id);
    return items[index] = _saved(items[index], draft);
  }

  @override
  Future<PlannerTask> changeStatus(String id, TaskStatus status) async {
    moves++;
    await _mutate();
    final index = items.indexWhere((task) => task.id == id);
    final old = items[index];
    return items[index] = _saved(
      old,
      TaskDraft(title: old.title, details: old.details ?? '', status: status),
    );
  }

  @override
  Future<void> delete(String id) async {
    deletes++;
    await _mutate();
    items.removeWhere((task) => task.id == id);
  }
}
