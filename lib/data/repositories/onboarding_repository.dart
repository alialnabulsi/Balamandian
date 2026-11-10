import '../services/onboarding_store.dart';

class OnboardingRepository {
  OnboardingRepository({
    required this._store,
    this.timeout = const Duration(seconds: 10),
  });
  final OnboardingStore _store;
  final Duration timeout;
  bool? _completed;
  Future<void>? _loading, _saving;
  bool get completed => _completed == true;

  Future<void> load() {
    if (_completed != null) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    final saved = await _store.readCompleted().timeout(timeout);
    _completed = saved || completed;
  }

  Future<void> markCompleted() {
    if (completed) return Future.value();
    return _saving ??= _save().whenComplete(() => _saving = null);
  }

  Future<void> _save() async {
    await _store.markCompleted().timeout(timeout);
    _completed = true;
  }
}
