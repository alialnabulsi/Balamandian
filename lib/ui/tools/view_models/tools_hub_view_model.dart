import 'package:flutter/foundation.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/services/external_url_service.dart';
import '../../../domain/models/auth_session.dart';
import '../../../domain/models/profile_models.dart';

enum CampusTool {
  gpa('GPA Calculator'),
  todo('To-do Planner'),
  calendar('Calendar'),
  scheduler('Course Scheduler'),
  notes('My Notes'),
  lostAndFound('Lost & Found');

  const CampusTool(this.label);
  final String label;
}

enum ToolAvailability { available, signIn, ineligible, loading, profileError }

/// Public destinations published in the University website's Resources footer.
/// https://www.balamand.edu.lb/home/Pages/default.aspx (checked 2026-11-25).
/// SIS keeps the published application/page, without its transient APEX session.
abstract final class UniversityLinks {
  static final sis = Uri.parse(
    'https://sisweb.balamand.edu.lb/pls/apex/f?p=2023:LOGIN',
  );
  static final moodle = Uri.parse(
    'https://uobmoodle.balamand.edu.lb/moodle/login/index.php',
  );
  static final imail = Uri.parse('https://www.outlook.com/std.balamand.edu.lb');
  static final academicCalendar = Uri.parse(
    'https://www.balamand.edu.lb/CurrentStudents/Pages/AcademicCalendar.aspx',
  );
}

/// Hub availability only; future API endpoints must enforce their own access.
class ToolsHubViewModel extends ChangeNotifier {
  ToolsHubViewModel({
    required AuthRepository auth,
    required this._profiles,
    required this._externalUrls,
  }) : _auth = auth,
       _account = auth.user {
    _auth.addListener(_changed);
    _profiles.addListener(_changed);
  }

  final AuthRepository _auth;
  final ProfileRepository _profiles;
  final ExternalUrlService _externalUrls;
  AuthUser? _account;
  int _generation = 0;
  bool _disposed = false, _launching = false;
  String? _linkError;

  bool get isGuest =>
      _auth.status == SessionStatus.unauthenticated && _auth.user == null;
  UserProfile? get _profile {
    final id = _auth.user?.id;
    final profile = _profiles.currentUser;
    return id != null &&
            _profiles.currentUserId == id &&
            profile?.identity.id == id
        ? profile
        : null;
  }

  bool get rolesLoading => !isGuest && _profile == null && roleError == null;
  String? get roleError =>
      !isGuest && _profile == null ? _profiles.error : null;
  bool get launching => _launching;
  String? get linkError => _linkError;

  ToolAvailability availability(CampusTool tool) {
    if (tool == CampusTool.calendar) return ToolAvailability.available;
    if (isGuest) return ToolAvailability.signIn;
    if (_profile == null) {
      return roleError == null
          ? ToolAvailability.loading
          : ToolAvailability.profileError;
    }
    final roles = _profile!.account?.roles ?? _profile!.identity.roles;
    if (roles.contains('student') ||
        (roles.contains('advisor') && tool != CampusTool.gpa)) {
      return ToolAvailability.available;
    }
    return ToolAvailability.ineligible;
  }

  String? availabilityLabel(CampusTool tool) => switch (availability(tool)) {
    ToolAvailability.available => null,
    ToolAvailability.signIn => 'Sign in required',
    ToolAvailability.ineligible => 'Not available for your account',
    ToolAvailability.loading => 'Checking account eligibility',
    ToolAvailability.profileError => 'Account eligibility unavailable. Retry',
  };

  String eligibilityMessage(CampusTool tool) => tool == CampusTool.gpa
      ? 'GPA Calculator is available to student accounts.'
      : '${tool.label} is available to student and advisor accounts.';

  void _changed() {
    if (!identical(_account, _auth.user)) {
      _account = _auth.user;
      _generation++;
      _linkError = null;
      _launching = false;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> retryProfile() async {
    if (isGuest || _auth.user == null || _profiles.loading) return;
    try {
      await _profiles.loadOwn(refresh: true);
    } catch (_) {
      // The repository owns profile errors and publishes retry feedback.
    }
  }

  Future<void> openLink(Uri uri) async {
    if (_disposed || _launching) return;
    final generation = _generation;
    _launching = true;
    _linkError = null;
    notifyListeners();
    try {
      if (!await _externalUrls.launch(uri)) {
        if (!_disposed && generation == _generation) {
          _linkError = 'This link could not be opened. Please try again.';
        }
      }
    } catch (_) {
      if (!_disposed && generation == _generation) {
        _linkError = 'This link could not be opened. Please try again.';
      }
    } finally {
      if (!_disposed && generation == _generation) {
        _launching = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _auth.removeListener(_changed);
    _profiles.removeListener(_changed);
    super.dispose();
  }
}
