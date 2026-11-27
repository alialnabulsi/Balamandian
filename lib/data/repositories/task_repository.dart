import '../../domain/models/task_models.dart';

abstract class TaskRepository {
  Future<List<PlannerTask>> loadAll();
  Future<PlannerTask> create(TaskDraft draft);
  Future<PlannerTask> update(String id, TaskDraft draft);
  Future<PlannerTask> changeStatus(String id, TaskStatus status);
  Future<void> delete(String id);
}
