import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../data/repositories/calendar_repository.dart';
import '../../../data/services/calendar_reminder_service.dart';
import '../../tools/view_models/tool_session.dart';

class CalendarReminderCoordinator extends ChangeNotifier
    with WidgetsBindingObserver {
  CalendarReminderCoordinator(this.session, this.repository, this.device) {
    session.addListener(_sync);
    WidgetsBinding.instance.addObserver(this);
    _sync();
  }
  final ToolSession session;
  final CalendarRepository repository;
  final CalendarReminderService device;
  int _epoch = -1, _generation = 0;
  bool _disposed = false;
  String? message;
  Future<void> _queue = Future.value();
  void _sync() {
    if (_epoch == session.epoch) return;
    _epoch = session.epoch;
    refresh();
  }

  Future<void> refresh({bool requestPermission = false}) async {
    final gen = ++_generation, owner = session.owner;
    message = null;
    // Clear persisted alarms immediately when eligibility/session changes; serialize all device writes.
    if (owner == null) {
      _queue = _queue
          .catchError((Object _) {})
          .then((_) => device.replace(null, []));
      await _queue;
      return;
    }
    try {
      final enabled = await device.permission(request: requestPermission);
      if (!enabled) {
        if (_disposed || gen != _generation) return;
        _queue = _queue.catchError((Object _) {}).then((_) async {
          if (!_disposed && gen == _generation) await device.replace(owner, []);
        });
        await _queue;
        if (!_disposed && gen == _generation) {
          message = 'Notifications are disabled. Calendar is usable; enable notifications for reminders.';
          notifyListeners();
        }
        return;
      }
      final events = await repository.reminders();
      if (_disposed || gen != _generation) return;
      _queue = _queue.catchError((Object _) {}).then((_) async {
        if (!_disposed && gen == _generation) {
          await device.replace(owner, enabled ? events : []);
        }
      });
      await _queue;
      if (gen == _generation && !_disposed) {
        message = enabled
            ? 'Device reminders are scheduled. Android may delay alerts to save battery.'
            : 'Notifications are disabled. Calendar is usable; enable notifications to receive reminders.';
      }
    } catch (_) {
      if (gen == _generation && !_disposed) message = 'Reminders could not be synchronized. Last synchronized device reminders are retained. Retry with a connection.';
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    session.removeListener(_sync);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
