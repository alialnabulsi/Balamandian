import 'dart:convert';

import 'package:balamandian/data/services/session_credential_store.dart';
import 'package:balamandian/domain/models/auth_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../auth_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  test('Reads the existing secure record, rejects corruption and deletes only its key', () async {
    String? record;
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(
            (call.arguments as Map)['key'],
            SecureSessionCredentialStore.storageKey,
          );
          methods.add(call.method);
          switch (call.method) {
            case 'read':
              return record;
            case 'write':
              record = (call.arguments as Map)['value'] as String;
            case 'delete':
              record = null;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    const store = SecureSessionCredentialStore();
    expect(await store.read(), isNull);
    final session = AuthSession.fromJson(sessionData()).session;
    await store.save(session);
    expect((await store.read())!.token == session.token, isTrue);
    record = '{broken';
    await expectLater(store.read(), throwsFormatException);
    await store.delete();
    expect(await store.read(), isNull);
    expect(methods, ['read', 'write', 'read', 'read', 'delete', 'read']);
  });

  test(
    'Writes and replaces one session record through the secure platform plugin',
    () async {
      final methods = <String>[];
      final records = <String, String>{};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methods.add(call.method);
            final arguments = call.arguments as Map;
            records[arguments['key'] as String] = arguments['value'] as String;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      const store = SecureSessionCredentialStore();
      final first = AuthSession.fromJson(sessionData()).session;
      await store.save(first);
      await store.save(
        IssuedSession(
          token: List.filled(43, 'B').join(),
          expiresAt: first.expiresAt,
        ),
      );
      expect(methods, ['write', 'write']);
      expect(records.keys, [SecureSessionCredentialStore.storageKey]);
      final record = jsonDecode(records.values.single) as Map<String, dynamic>;
      expect(record.keys, unorderedEquals(['token', 'tokenType', 'expiresAt']));
      expect(record['token'] == List.filled(43, 'B').join(), isTrue);
      expect(record['tokenType'], 'Bearer');
      expect(DateTime.parse(record['expiresAt'] as String), first.expiresAt);
    },
  );
}
