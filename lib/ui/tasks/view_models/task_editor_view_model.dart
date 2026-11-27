import 'package:flutter/foundation.dart';

import '../../../domain/models/task_models.dart';
import 'task_planner_view_model.dart';

class TaskEditorViewModel extends ChangeNotifier {
  TaskEditorViewModel({required this.planner, this.original})
    : epoch = planner.epoch,
      title = original?.title ?? '',
      details = original?.details ?? '',
      status = original?.status ?? TaskStatus.todo;
  final TaskPlannerViewModel planner;
  final PlannerTask? original;
  final int epoch;
  String title, details;
  TaskStatus status;
  bool submitted = false, saving = false;
  bool _disposed = false;
  String? error;
  bool get current =>
      planner.epoch == epoch && planner.access == PlannerAccess.eligible;
  static bool _malformed(String text) =>
      text.runes.any((rune) => rune >= 0xd800 && rune <= 0xdfff);
  String? get titleError => title.trim().isEmpty
      ? 'Enter a task title.'
      : title.runes.length > 160
      ? 'Use at most 160 characters.'
      : _malformed(title) ||
            RegExp(r'[\x00-\x1f\x7f-\x9f\u2028\u2029]').hasMatch(title)
      ? 'Use a single line without control characters.'
      : null;
  String? get detailsError => details.runes.length > 2000
      ? 'Use at most 2,000 characters.'
      : _malformed(details) ||
            RegExp(r'[\x00-\x09\x0b-\x1f\x7f-\x9f]').hasMatch(details)
      ? 'Use plain text and new lines; remove tabs or control characters.'
      : null;
  Future<bool> save() async {
    if (saving || !current) return false;
    submitted = true;
    error = null;
    if (titleError != null || detailsError != null) {
      notifyListeners();
      return false;
    }
    saving = true;
    notifyListeners();
    final result = await planner.save(
      TaskDraft(title: title, details: details, status: status),
      original: original,
    );
    saving = false;
    error = result
        ? null
        : planner.error ?? 'Your account or planner changed. Please try again.';
    if (!_disposed) notifyListeners();
    return result && current;
  }

  @override
  void dispose() {
    _disposed = true;
    title = details = '';
    super.dispose();
  }
}
