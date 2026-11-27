import 'package:flutter/foundation.dart';

import '../../../data/repositories/scheduler_repository.dart';
import '../../../domain/models/schedule_models.dart';
import '../../../domain/models/tool_failure.dart';
import '../../tools/view_models/tool_session.dart';

class SchedulerViewModel extends ChangeNotifier {
  SchedulerViewModel(this.session, this.repository, {this.syncReminders}) {
    session.addListener(_sync);
    _sync();
  }
  final Future<void> Function()? syncReminders;
  final ToolSession session;
  final SchedulerRepository repository;
  bool creating = false;
  List<AcademicSemester> semesters = [];
  ScheduleData? data;
  ScheduleGeneration? generated;
  Set<String> selected = {};
  String search = '';
  double target = 15;
  String targetInput = '15';
  bool targetValid = true;
  bool loading = false, busy = false;
  String? error, message;
  int _epoch = -1, _request = 0;
  bool _disposed = false;
  List<CandidateCourse> get candidates => (data?.candidates ?? [])
      .where(
        (c) =>
            '${c.id} ${c.title}'.toLowerCase().contains(search.toLowerCase()),
      )
      .toList();
  void _sync() {
    if (_epoch == session.epoch) return;
    _epoch = session.epoch;
    _request++;
    creating = false;
    semesters = [];
    data = null;
    generated = null;
    selected = {};
    error = null;
    message = null;
    busy = false;
    loading = false;
    if (session.owner != null) load();
    notifyListeners();
  }

  Future<void> load() async {
    if (session.owner == null) return;
    final req = ++_request;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final s = await repository.semesters();
      if (_disposed || req != _request) return;
      semesters = s;
      if (s.isNotEmpty) {
        final id = s.any((x) => x.id == data?.semester.id)
            ? data!.semester.id
            : s.first.id;
        final updated = await repository.read(id);
        if (!_disposed && req == _request) {
          data = updated;
          generated = null;
          selected = {};
        }
      } else {
        data = null;
      }
    } catch (e) {
      if (!_disposed && req == _request) error = _message(e);
    } finally {
      if (!_disposed && req == _request) {
        loading = false;
        notifyListeners();
      }
    }
  }

  String _message(Object e) =>
      e is ToolFailure ? e.message : 'Schedule unavailable. Please retry.';
  Future<void> choose(String semester) async {
    if (busy || session.owner == null) return;
    final req = ++_request;
    loading = true;
    error = null;
    generated = null;
    selected = {};
    creating = false;
    data = null;
    notifyListeners();
    try {
      final d = await repository.read(semester);
      if (!_disposed && req == _request) data = d;
    } catch (e) {
      if (!_disposed && req == _request) error = _message(e);
    } finally {
      if (!_disposed && req == _request) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void startPlanning() {
    if (data?.canPlan == true && !busy) {
      creating = true;
      notifyListeners();
    }
  }

  Future<void> syncSemesters() async {
    if (busy || session.owner == null) return;
    final req = ++_request;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await repository.syncSemesters();
      if (!current(req)) return;
      busy = false;
      await load();
    } catch (e) {
      if (current(req)) error = _message(e);
    } finally {
      if (current(req)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> deleteProposal() => _mutation((d, req) async {
    await repository.deleteDraft(d);
    if (!current(req)) return;
    final updated = await repository.read(d.semester.id);
    if (current(req)) {
      data = updated;
      creating = false;
      generated = null;
      selected = {};
      await syncReminders?.call();
    }
  });
  void filter(String value) {
    search = value;
    notifyListeners();
  }

  void select(String id, bool on) {
    if (busy) return;
    on ? selected.add(id) : selected.remove(id);
    generated = null;
    notifyListeners();
  }

  void credits(String value) {
    if (busy) return;
    targetInput = value;
    final n = double.tryParse(value);
    targetValid =
        n != null &&
        n.isFinite &&
        n > 0 &&
        n <= 36 &&
        (n * 100 - (n * 100).round()).abs() < 0.000001;
    if (targetValid) target = n!;
    generated = null;
    notifyListeners();
  }

  Future<void> _mutation(
    Future<void> Function(ScheduleData, int) action,
  ) async {
    final d = data;
    if (d == null || busy || session.owner == null) return;
    final req = ++_request;
    busy = true;
    error = null;
    message = null;
    notifyListeners();
    try {
      await action(d, req);
    } catch (e) {
      if (current(req)) {
        error = _message(e);
        if (e is ToolFailure && e.code == 'CONFLICT') {
          try {
            final updated = await repository.read(d.semester.id);
            if (current(req)) {
              data = updated;
              generated = null;
              selected = {};
              creating = false;
            }
          } catch (_) {
            /* Preserve the original conflict and last confirmed view. */
          }
        }
      }
    } finally {
      if (!_disposed && req == _request) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> reminder(int minutes) => _mutation((d, req) async {
    await repository.registrationReminder(d.semester.id, minutes);
    if (!current(req)) return;
    await syncReminders?.call();
    if (current(req)) message = 'Registration reminder saved to your calendar. Device alerts require notification permission and a successful sync. This draft has not enrolled you.';
  });
  bool current(int req) => !_disposed && req == _request;
  Future<void> refresh() => _mutation((d, req) async {
    final updated = await repository.refresh(d.semester.id);
    if (current(req)) {
      data = updated;
      generated = null;
      selected = {};
    }
  });
  Future<void> generate() => _mutation((d, req) async {
    if (!d.canPlan || !targetValid) return;
    final r = await repository.generate(d, selected.toList()..sort(), target);
    if (current(req)) generated = r;
  });
  Future<void> save(ScheduleOption option) => _mutation((d, req) async {
    if (!d.canPlan) return;
    await repository.save(d, option);
    if (!current(req)) return;
    final updated = await repository.read(d.semester.id);
    if (current(req)) {
      data = updated;
      creating = false;
      generated = null;
      selected = {};
      message = 'Draft saved. Register these courses in SIS; you have not been enrolled.';
    }
  });
  @override
  void dispose() {
    _disposed = true;
    _request++;
    session.removeListener(_sync);
    super.dispose();
  }
}
