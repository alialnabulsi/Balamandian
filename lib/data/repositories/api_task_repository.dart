import '../../domain/models/task_models.dart';
import '../services/task_api_service.dart';
import 'task_repository.dart';

typedef AuthenticatedTaskRequest = Future<T> Function<T>(
  Future<T> Function(String token) request,
);

class ApiTaskRepository implements TaskRepository {
  ApiTaskRepository({required this._api, required this._withSession});
  final TaskApiService _api;
  final AuthenticatedTaskRequest _withSession;
  @override
  Future<List<PlannerTask>> loadAll() => _withSession((token) async {
    final first = await _api.page(token, 1);
    final tasks = <PlannerTask>[...first.items];
    var current = first;
    while (current.hasNext) {
      if (current.items.isEmpty || current.page >= 1000000) {
        throw TaskFailure.invalidResponse;
      }
      final next = await _api.page(token, current.page + 1);
      if (next.page != current.page + 1 ||
          next.total != first.total ||
          next.completed != first.completed) {
        throw const TaskFailure(
          'COLLECTION_CHANGED',
          'Your planner changed while loading. Please refresh.',
        );
      }
      tasks.addAll(next.items);
      current = next;
    }
    if (first.page != 1 ||
        tasks.length != first.total ||
        tasks.map((task) => task.id).toSet().length != tasks.length ||
        tasks.where((task) => task.status == TaskStatus.done).length !=
            first.completed) {
      throw const TaskFailure(
        'COLLECTION_CHANGED',
        'Your planner changed while loading. Please refresh.',
      );
    }
    return List.unmodifiable(tasks);
  });
  @override
  Future<PlannerTask> create(TaskDraft draft) =>
      _withSession((token) => _api.create(token, draft));
  @override
  Future<PlannerTask> update(String id, TaskDraft draft) =>
      _withSession((token) => _api.update(token, id, draft.toJson()));
  @override
  Future<PlannerTask> changeStatus(String id, TaskStatus status) =>
      _withSession((token) => _api.update(token, id, {'status': status.value}));
  @override
  Future<void> delete(String id) =>
      _withSession((token) => _api.delete(token, id));
}
