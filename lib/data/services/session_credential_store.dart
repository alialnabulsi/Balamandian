import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/models/auth_session.dart';

abstract class SessionCredentialStore {
  Future<void> save(IssuedSession session);
}

class SecureSessionCredentialStore implements SessionCredentialStore {
  const SecureSessionCredentialStore({
    this._storage = const FlutterSecureStorage(),
  });

  final FlutterSecureStorage _storage;
  static const storageKey = 'balamandian.application_session';

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
