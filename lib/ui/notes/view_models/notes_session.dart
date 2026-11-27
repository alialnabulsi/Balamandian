import 'package:flutter/foundation.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/notes_repository.dart';
import '../../../domain/models/auth_session.dart';

enum NotesAccess { guest, loading, profileError, ineligible, eligible }

class NotesSession extends ChangeNotifier {
  NotesSession({
    required this.auth,
    required this.profiles,
    required this.repository,
  }) {
    auth.addListener(_sync);
    profiles.addListener(_sync);
    _sync();
  }
  final AuthRepository auth;
  final ProfileRepository profiles;
  final NotesRepository repository;
  NotesAccess access = NotesAccess.loading;
  int epoch = 0;
  Object? _identity;
  String? get owner => access == NotesAccess.eligible ? auth.user?.id : null;
  NotesAccess _resolve() {
    if (auth.status == SessionStatus.unauthenticated && auth.user == null) {
      return NotesAccess.guest;
    }
    if (auth.status != SessionStatus.authenticated) return NotesAccess.loading;
    final p = profiles.currentUser;
    if (p == null ||
        p.identity.id != auth.user?.id ||
        profiles.currentUserId != auth.user?.id) {
      return profiles.error != null && !profiles.loading
          ? NotesAccess.profileError
          : NotesAccess.loading;
    }
    return (p.account?.roles ?? p.identity.roles).any(
          (r) => r == 'student' || r == 'advisor',
        )
        ? NotesAccess.eligible
        : NotesAccess.ineligible;
  }

  void _sync() {
    final next = _resolve();
    if (!identical(_identity, auth.user) || next != access) {
      _identity = auth.user;
      access = next;
      epoch++;
      repository.cancelPending();
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
