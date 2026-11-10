class AuthUser {
  const AuthUser({
    required this.id,
    required this.sisUserId,
    required this.institutionalEmail,
    required this.emailVerifiedAt,
  });

  final String id, sisUserId, institutionalEmail;
  final DateTime emailVerifiedAt;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    if (json case {
      'id': String id,
      'sisUserId': String sisUserId,
      'institutionalEmail': String email,
      'emailVerifiedAt': String verified,
    }) {
      if (id.isNotEmpty && sisUserId.isNotEmpty && email.isNotEmpty) {
        return AuthUser(
          id: id,
          sisUserId: sisUserId,
          institutionalEmail: email,
          emailVerifiedAt: DateTime.parse(verified).toUtc(),
        );
      }
    }
    throw const FormatException('Invalid authenticated user.');
  }
}

class IssuedSession {
  const IssuedSession({required this.token, required this.expiresAt});

  final String token;
  final DateTime expiresAt;

  factory IssuedSession.fromJson(Map<String, dynamic> json) {
    if (json case {
      'token': String token,
      'tokenType': 'Bearer',
      'expiresAt': String expires,
    }) {
      if (RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token)) {
        return IssuedSession(
          token: token,
          expiresAt: DateTime.parse(expires).toUtc(),
        );
      }
    }
    throw const FormatException('Invalid issued session.');
  }
}

class AuthSession {
  const AuthSession({required this.user, required this.session});

  final AuthUser user;
  final IssuedSession session;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    if (json case {
      'user': Map<String, dynamic> user,
      'session': Map<String, dynamic> session,
    }) {
      return AuthSession(
        user: AuthUser.fromJson(user),
        session: IssuedSession.fromJson(session),
      );
    }
    throw const FormatException('Invalid authentication response.');
  }
}

/// The validation response deliberately contains no new bearer token.
class ValidatedSession {
  const ValidatedSession({required this.user, required this.expiresAt});

  final AuthUser user;
  final DateTime expiresAt;

  factory ValidatedSession.fromJson(Map<String, dynamic> json) {
    if (json case {
      'user': Map<String, dynamic> user,
      'session': {'expiresAt': String expires},
    }) {
      return ValidatedSession(
        user: AuthUser.fromJson(user),
        expiresAt: DateTime.parse(expires).toUtc(),
      );
    }
    throw const FormatException('Invalid session validation response.');
  }
}

enum SessionStatus {
  initializing,
  authenticated,
  unauthenticated,
  validationError,
  signingOut,
}
