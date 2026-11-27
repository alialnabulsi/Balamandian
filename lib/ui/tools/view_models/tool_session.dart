import 'package:flutter/foundation.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../domain/models/auth_session.dart';

enum ToolAccess { guest, loading, profileError, ineligible, eligible }

class ToolSession extends ChangeNotifier {
  ToolSession({
    required this.auth,
    required this.profiles,
    required this.cancelPending,
  }) {
    auth.addListener(_sync);
    profiles.addListener(_sync);
    _sync();
  }
  final AuthRepository auth;
  final ProfileRepository profiles;
  final VoidCallback cancelPending;
  ToolAccess access = ToolAccess.loading;
  int epoch = 0;
  Object? _identity;
  String? get owner => access == ToolAccess.eligible ? auth.user?.id : null;
  ToolAccess _resolve() {
    if (auth.status == SessionStatus.unauthenticated && auth.user == null) {
      return ToolAccess.guest;
    }
    if (auth.status != SessionStatus.authenticated) return ToolAccess.loading;
    final p = profiles.currentUser;
    if (p == null ||
        p.identity.id != auth.user?.id ||
        profiles.currentUserId != auth.user?.id) {
      return profiles.error != null && !profiles.loading
          ? ToolAccess.profileError
          : ToolAccess.loading;
    }
    return (p.account?.roles ?? p.identity.roles).any(
          (r) => r == 'student' || r == 'advisor',
        )
        ? ToolAccess.eligible
        : ToolAccess.ineligible;
  }

  void _sync() {
    final next = _resolve();
    if (!identical(_identity, auth.user) || next != access) {
      _identity = auth.user;
      access = next;
      epoch++;
      cancelPending();
    }
    notifyListeners();
  }

  Future<void> retry() async {
    try {
      await profiles.loadOwn(refresh: true);
    } catch (_) {
      /* Profile repository publishes errors. */
    }
  }

  @override
  void dispose() {
    auth.removeListener(_sync);
    profiles.removeListener(_sync);
    super.dispose();
  }
}
