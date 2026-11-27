import 'package:flutter/foundation.dart';

import '../../../data/repositories/calendar_repository.dart';
import '../../../domain/models/calendar_models.dart';
import '../../../domain/models/tool_failure.dart';
import '../../tools/view_models/tool_session.dart';
import 'calendar_reminder_coordinator.dart';

class CalendarViewModel extends ChangeNotifier {
  CalendarViewModel(this.session, this.repository, this.reminders) {
    session.addListener(_sync);
    _sync();
  }
  final ToolSession session;
  final CalendarRepository repository;
  final CalendarReminderCoordinator reminders;
  DateTime selected = DateTime.now();
  DateTime? campusDay;
  List<CampusEvent> events = [];
  final filters = CalendarCategory.values.toSet();
  bool loading = false, busy = false;
  String? error;
  int _epoch = -1, _generation = 0, _selection = 0;
  bool _disposed = false;
  List<CampusEvent> get agenda => events
      .where((e) => filters.contains(e.category) && e.onDay(selected))
      .toList();
  bool get member => session.access == ToolAccess.eligible;
  void _sync() {
    if (_epoch == session.epoch) return;
    _epoch = session.epoch;
    _generation++;
    events = [];
    error = null;
    busy = false;
    load();
    today();
  }

  void select(DateTime day) {
    _selection++;
    final changed = day.month != selected.month || day.year != selected.year;
    selected = day;
    if (changed) load();
    notifyListeners();
  }

  void filter(CalendarCategory c, bool on) {
    on ? filters.add(c) : filters.remove(c);
    notifyListeners();
  }

  Future<void> today() async {
    final epoch = session.epoch, selection = _selection;
    try {
      final day = await repository.today();
      if (!_disposed && epoch == session.epoch) {
        campusDay = day;
        if (selection == _selection) {
          select(day);
        } else {
          notifyListeners();
        }
      }
    } catch (_) {
      if (!_disposed && epoch == session.epoch) {
        error = 'Campus date unavailable. Retry with a connection.';
        notifyListeners();
      }
    }
  }

  Future<void> load() async {
    final gen = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final r = await repository.list(
        DateTime(selected.year, selected.month),
        DateTime(selected.year, selected.month + 1),
        member: member,
      );
      if (!_disposed && gen == _generation) events = r;
    } catch (e) {
      if (!_disposed && gen == _generation) {
        error = e is ToolFailure
            ? e.message
            : 'Calendar unavailable. Please retry.';
      }
    } finally {
      if (!_disposed && gen == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> mutate(Future<Object?> Function() run) async {
    if (busy || !member) return false;
    final epoch = session.epoch;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await run();
      if (_disposed || epoch != session.epoch) return false;
      await reminders.refresh();
      if (_disposed || epoch != session.epoch) return false;
      busy = false;
      await load();
      return true;
    } catch (e) {
      if (!_disposed && epoch == session.epoch) {
        error = e is ToolFailure
            ? e.message
            : 'Your changes were not saved. Retry.';
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
    _generation++;
    session.removeListener(_sync);
    super.dispose();
  }
}
