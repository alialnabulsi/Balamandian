import 'package:flutter/foundation.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/guide_repository.dart';
import '../../../domain/models/auth_session.dart';
import '../../../domain/models/guide_models.dart';
import 'guide_bookmarks.dart';

class GuideSession extends ChangeNotifier {
  GuideSession({required this.auth, required this.repository})
    : bookmarks = GuideBookmarks(repository) {
    auth.addListener(_sync);
    _sync();
  }
  final AuthRepository auth;
  final GuideRepository repository;
  final GuideBookmarks bookmarks;
  GuideLocale locale = GuideLocale.en;
  String? owner;
  Object? _identity;
  int epoch = 0;
  bool get active => owner != null;
  void _sync() {
    final user = auth.status == SessionStatus.authenticated ? auth.user : null;
    if (!identical(user, _identity) || owner != user?.id) {
      _identity = user;
      owner = user?.id;
      epoch++;
      repository.cancelPending();
      bookmarks.reset();
      locale = GuideLocale.en;
      notifyListeners();
    }
  }

  void selectLocale(GuideLocale value) {
    if (value != locale) {
      locale = value;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    auth.removeListener(_sync);
    repository.cancelPending();
    bookmarks.dispose();
    super.dispose();
  }
}
