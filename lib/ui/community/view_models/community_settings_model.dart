import 'package:flutter/foundation.dart';

import '../../../data/repositories/community_repository.dart';
import '../../../domain/models/community.dart';

class CommunitySettingsModel extends ChangeNotifier {
  CommunitySettingsModel(this.repository);
  final CommunityRepository repository;
  CommunityJson? data;
  Object? error;
  bool busy = false, _disposed = false;

  Future<void> load() async {
    if (busy) return;
    busy = true;
    error = null;
    _publish();
    try {
      data = await repository.object('settings');
    } catch (e) {
      error = e;
    } finally {
      busy = false;
      _publish();
    }
  }

  Future<void> change(String key, Object value) async {
    if (busy || data == null) return;
    final before = data!;
    data = {...before, key: value};
    busy = true;
    error = null;
    _publish();
    try {
      await repository.mutate('settings', method: 'PATCH', data: {key: value});
      repository.invalidate();
    } catch (e) {
      data = before;
      error = e;
    } finally {
      busy = false;
      _publish();
    }
  }

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
