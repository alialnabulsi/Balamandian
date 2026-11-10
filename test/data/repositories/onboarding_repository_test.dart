import 'package:balamandian/data/repositories/onboarding_repository.dart';
import 'package:balamandian/data/services/onboarding_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../auth_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Completion persists across repositories and repeated commands are deduplicated', () async {
    final store = MemoryOnboardingStore();
    final first = OnboardingRepository(store: store);
    await Future.wait([first.load(), first.load()]);
    expect(first.completed, isFalse);
    expect(store.reads, 1);
    await Future.wait([first.markCompleted(), first.markCompleted()]);
    await first.markCompleted();
    expect(store.writes, 1);
    final restarted = OnboardingRepository(store: store);
    await restarted.load();
    expect(restarted.completed, isTrue);
  });

  test(
    'Storage failures do not falsely report completion and allow retry',
    () async {
      final store = MemoryOnboardingStore()..fail = true;
      final repository = OnboardingRepository(store: store);
      await expectLater(repository.load(), throwsStateError);
      await expectLater(repository.markCompleted(), throwsStateError);
      expect(repository.completed, isFalse);
      store.fail = false;
      await repository.load();
      await repository.markCompleted();
      expect(repository.completed, isTrue);
    },
  );

  test(
    'The platform adapter stores only the onboarding flag at its own key',
    () async {
      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      String? value;
      final methods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final arguments = call.arguments as Map;
            expect(arguments['key'], SecureOnboardingStore.storageKey);
            methods.add(call.method);
            if (call.method == 'write') value = arguments['value'] as String;
            return call.method == 'read' ? value : null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      const store = SecureOnboardingStore();
      expect(await store.readCompleted(), isFalse);
      await store.markCompleted();
      expect(value, '1');
      expect(await store.readCompleted(), isTrue);
      value = 'invalid';
      await expectLater(store.readCompleted(), throwsFormatException);
      expect(methods, ['read', 'write', 'read', 'read']);
    },
  );
}
