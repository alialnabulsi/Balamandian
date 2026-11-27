import 'package:flutter/foundation.dart';

import '../../../data/repositories/lost_found_repository.dart';
import '../../../domain/models/lost_found_models.dart';
import '../../../domain/models/tool_failure.dart';
import '../../tools/view_models/tool_session.dart';

class LostFoundViewModel extends ChangeNotifier {
  LostFoundViewModel(this.session, this.repository) {
    session.addListener(_sync);
    _sync();
  }
  final ToolSession session;
  final LostFoundRepository repository;
  List<LostFoundReport> reports = [];
  bool loading = false, busy = false;
  String? error;
  int _epoch = -1, _request = 0;
  bool _disposed = false;
  void _sync() {
    if (_epoch == session.epoch) return;
    _epoch = session.epoch;
    _request++;
    reports = [];
    error = null;
    busy = false;
    loading = false;
    if (session.owner != null) load();
    notifyListeners();
  }

  Future<void> load() async {
    if (session.owner == null || busy) return;
    final request = ++_request;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final r = await repository.list();
      if (request == _request && !_disposed) reports = r;
    } catch (e) {
      if (!_disposed && request == _request) {
        error = e is ToolFailure
            ? e.message
            : 'Unable to load reports. Please retry.';
      }
    } finally {
      if (!_disposed && request == _request) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<LostFoundReport?> read(String id) async {
    final e = _epoch;
    final r = await repository.read(id);
    return !_disposed && session.epoch == e ? r : null;
  }

  Future<bool> withdraw(String id) async {
    if (busy || session.owner == null) return false;
    final e = _epoch;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await repository.withdraw(id);
      if (e != session.epoch || _disposed) return false;
      busy = false;
      await load();
      return true;
    } catch (x) {
      if (e == session.epoch && !_disposed) {
        error = x is ToolFailure
            ? x.message
            : 'Unable to withdraw. Please retry.';
      }
      return false;
    } finally {
      if (e == session.epoch && !_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    session.removeListener(_sync);
    super.dispose();
  }
}
