import 'package:flutter/foundation.dart';

import '../../../data/repositories/calendar_repository.dart';
import '../../../domain/models/calendar_models.dart';
import '../../../domain/models/note_models.dart' show noteLocalId;
import '../../../domain/models/tool_failure.dart';
import '../../tools/view_models/tool_session.dart';
import 'calendar_reminder_coordinator.dart';

class EventEditorViewModel extends ChangeNotifier {
  EventEditorViewModel(
    this.repository,
    this.session,
    this.reminders,
    this.existing,
  );
  final CalendarRepository repository;
  final ToolSession session;
  final CalendarReminderCoordinator reminders;
  final CampusEvent? existing;
  final String requestKey = noteLocalId();
  bool busy = false;
  String? error;
  bool _disposed = false;
  Future<bool> save({
    required String title,
    required String details,
    required String location,
    required bool allDay,
    required String start,
    required String end,
    int? lead,
  }) async {
    if (busy || session.owner == null) return false;
    final epoch = session.epoch;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await repository.save({
        'title': title,
        'details': details,
        'location': location,
        'allDay': allDay,
        'start': start,
        'end': end,
        'reminderMinutes': lead,
        if (existing != null) 'revision': existing!.revision,
        if (existing == null) 'requestKey': requestKey,
      }, id: existing?.id);
      if (_disposed || epoch != session.epoch) return false;
      await reminders.refresh(requestPermission: lead != null);
      return !_disposed && epoch == session.epoch;
    } catch (e) {
      if (!_disposed && epoch == session.epoch) {
        error = e is ToolFailure
            ? e.message
            : 'Unable to save. Your typed content is retained.';
      }
      return false;
    } finally {
      if (!_disposed && epoch == session.epoch) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
