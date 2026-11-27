enum TaskStatus {
  todo('todo', 'To do'),
  inProgress('in_progress', 'In progress'),
  done('done', 'Done');

  const TaskStatus(this.value, this.label);
  final String value, label;
  static TaskStatus parse(Object? value) => values.firstWhere(
    (status) => status.value == value,
    orElse: () => throw const FormatException('Invalid task status.'),
  );
}

class PlannerTask {
  const PlannerTask({
    required this.id,
    required this.title,
    required this.details,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id, title;
  final String? details;
  final TaskStatus status;
  final DateTime createdAt, updatedAt;
  factory PlannerTask.fromJson(Object? value) {
    if (value case {
      'id': String id,
      'title': String title,
      'details': final details,
      'status': final status,
      'createdAt': String created,
      'updatedAt': String updated,
    }) {
      if (!RegExp(
            r'^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$',
            caseSensitive: false,
          ).hasMatch(id) ||
          title.trim().isEmpty ||
          (details != null && details is! String)) {
        throw const FormatException('Invalid task.');
      }
      final createdAt = DateTime.parse(created).toUtc();
      final updatedAt = DateTime.parse(updated).toUtc();
      if (updatedAt.isBefore(createdAt)) {
        throw const FormatException('Invalid task dates.');
      }
      return PlannerTask(
        id: id,
        title: title,
        details: details as String?,
        status: TaskStatus.parse(status),
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    }
    throw const FormatException('Invalid task.');
  }
}

class TaskPage {
  TaskPage({
    required List<PlannerTask> items,
    required this.page,
    required this.total,
    required this.completed,
    required this.hasNext,
  }) : items = List.unmodifiable(items);
  final List<PlannerTask> items;
  final int page, total, completed;
  final bool hasNext;
  factory TaskPage.fromJson(Object? value) {
    if (value case {
      'items': List items,
      'pagination': {
        'page': int page,
        'totalItems': int total,
        'hasNextPage': bool hasNext,
      },
      'progress': {
        'totalTasks': int tasks,
        'completedTasks': int completed,
        'percentage': num percent,
      },
    }) {
      if (page < 1 ||
          total < 0 ||
          total != tasks ||
          completed < 0 ||
          completed > total ||
          !percent.isFinite ||
          percent < 0 ||
          percent > 100) {
        throw const FormatException('Invalid task page.');
      }
      return TaskPage(
        items: items.map(PlannerTask.fromJson).toList(),
        page: page,
        total: total,
        completed: completed,
        hasNext: hasNext,
      );
    }
    throw const FormatException('Invalid task page.');
  }
}

class TaskDraft {
  const TaskDraft({
    required this.title,
    required this.details,
    required this.status,
  });
  final String title, details;
  final TaskStatus status;
  Map<String, Object?> toJson() => {
    'title': title.trim(),
    'details': details.trim().isEmpty ? null : details.trim(),
    'status': status.value,
  };
}

class TaskFailure implements Exception {
  const TaskFailure(this.code, this.message);
  final String code, message;
  static const network = TaskFailure(
    'NETWORK_ERROR',
    'Cannot reach your planner. Check your connection. Refresh to check for saved changes before retrying.',
  );
  static const invalidResponse = TaskFailure(
    'INVALID_RESPONSE',
    'The planner returned an unexpected response. Please refresh.',
  );
  factory TaskFailure.fromCode(String? code) => TaskFailure(
    const {
          'TASKS_FORBIDDEN',
          'PROFILE_UNAVAILABLE',
          'TASK_NOT_FOUND',
          'VALIDATION_ERROR',
          'RATE_LIMITED',
        }.contains(code)
        ? code!
        : 'SERVICE_ERROR',
    switch (code) {
      'TASKS_FORBIDDEN' =>
        'To-do Planner is available to student and advisor accounts.',
      'PROFILE_UNAVAILABLE' =>
        'Your university profile could not be loaded. Please retry.',
      'TASK_NOT_FOUND' =>
        'This task is no longer available. Refresh your planner.',
      'VALIDATION_ERROR' =>
        'Check the title, details and status, then try again.',
      'RATE_LIMITED' =>
        'Too many task changes. Please wait before trying again.',
      _ => 'Your planner is unavailable. Please try again.',
    },
  );
  @override
  String toString() => 'TaskFailure($code)';
}
