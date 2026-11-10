import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/models/auth_session.dart';

abstract class SessionCredentialStore {
  Future<void> save(IssuedSession session);
  Future<IssuedSession?> read();
  Future<void> delete();
}

class SecureSessionCredentialStore implements SessionCredentialStore {
  const SecureSessionCredentialStore({
    this._storage = const FlutterSecureStorage(),
  });

  final FlutterSecureStorage _storage;
  static const storageKey = 'balamandian.application_session';

  @override
  Future<IssuedSession?> read() async {
    final value = await _storage.read(key: storageKey);
    if (value == null) return null;
    try {
      final json = jsonDecode(value);
      if (json is Map<String, dynamic>) return IssuedSession.fromJson(json);
    } on FormatException {
      // Do not retain the sensitive input as FormatException.source.
    }
    throw const FormatException('Invalid saved session.');
  }

  @override
  Future<void> delete() => _storage.delete(key: storageKey);

  @override
  Future<void> save(IssuedSession session) => _storage.write(
    key: storageKey,
    value: jsonEncode({
      'token': session.token,
      'tokenType': 'Bearer',
      'expiresAt': session.expiresAt.toUtc().toIso8601String(),
    }),
  );
}
