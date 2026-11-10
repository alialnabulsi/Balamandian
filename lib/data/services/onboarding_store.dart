import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class OnboardingStore {
  Future<bool> readCompleted();
  Future<void> markCompleted();
}

/// Non-sensitive entry metadata, separate from the session credential record.
/// Reuses the installed platform store without adding another storage package.
class SecureOnboardingStore implements OnboardingStore {
  const SecureOnboardingStore({this._storage = const FlutterSecureStorage()});
  final FlutterSecureStorage _storage;
  static const storageKey = 'balamandian.onboarding_completed';

  @override
  Future<bool> readCompleted() async =>
      switch (await _storage.read(key: storageKey)) {
        null => false,
        '1' => true,
        _ => throw const FormatException('Invalid onboarding preference.'),
      };

  @override
  Future<void> markCompleted() => _storage.write(key: storageKey, value: '1');
}
