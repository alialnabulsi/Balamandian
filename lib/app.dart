import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import 'data/repositories/api_auth_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/community_repository.dart';
import 'data/services/community_api_service.dart';
import 'data/repositories/onboarding_repository.dart';
import 'data/services/onboarding_store.dart';
import 'data/services/auth_api_service.dart';
import 'data/services/session_credential_store.dart';
import 'data/repositories/marketplace_repository.dart';
import 'data/repositories/api_marketplace_repository.dart';
import 'data/services/marketplace_api_service.dart';
import 'data/services/external_url_service.dart';
import 'data/repositories/profile_repository.dart';
import 'data/repositories/api_profile_repository.dart';
import 'data/services/profile_api_service.dart';
import 'domain/models/auth_session.dart';
import 'ui/profile/view_models/current_identity_view_model.dart';
import 'ui/community/view_models/community_inbox_model.dart';
import 'routing/app_router.dart';
import 'routing/community_post_link.dart';
import 'routing/startup_destination.dart';
import 'ui/core/themes/app_theme.dart';
import 'ui/core/ui/backgrounds/app_branded_background.dart';
import 'ui/auth/view_models/auth_ui_controller.dart';
import 'ui/auth/view_models/session_view_model.dart';
import 'ui/onboarding/view_models/app_entry_view_model.dart';
import 'ui/onboarding/widgets/app_entry_overlay.dart';
import 'data/repositories/campus_repository.dart';
import 'data/repositories/campus_location_repository.dart';
import 'data/services/campus_location_service.dart';
import 'ui/map/view_models/campus_map_view_model.dart';

class MainApp extends StatefulWidget {
  const MainApp({
    super.key,
    this.authUi,
    this.authRepository,
    this.marketplaceRepository,
    this.profileRepository,
    this.communityRepository,
    this.externalUrls,
    this.onboardingRepository,
    this.themeMode = ThemeMode.system,
    this.initialLocation = '/welcome/splash',
    this.holdSplash = false,
    this.afterSplash = StartupDestination.campus,
    this.onOnboardingCompleted,
    this.campusMap,
  });
  final AuthUiController? authUi;
  final AuthRepository? authRepository;
  final MarketplaceRepository? marketplaceRepository;
  final ProfileRepository? profileRepository;
  final CommunityRepository? communityRepository;
  final ExternalUrlService? externalUrls;
  final OnboardingRepository? onboardingRepository;
  final ThemeMode themeMode;
  final String initialLocation;
  final bool holdSplash;
  final StartupDestination afterSplash;
  final VoidCallback? onOnboardingCompleted;
  final CampusMapViewModel? campusMap;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  String? _campusSessionId;
  late final _campusMap =
      widget.campusMap ??
      CampusMapViewModel(
        repository: AssetCampusRepository(
          read: rootBundle.loadString,
          fixture:
              kDebugMode && const bool.fromEnvironment('CAMPUS_MAP_FIXTURES'),
        ),
        location: CampusLocationRepository(ForegroundCampusLocationService()),
        debugGraph:
            kDebugMode && const bool.fromEnvironment('CAMPUS_MAP_DEBUG_GRAPH'),
      );
  AuthApiService? _api;
  MarketplaceApiService? _marketplaceApi;
  ProfileApiService? _profileApi;
  late final ProfileRepository _profileRepository =
      widget.profileRepository ??
      ApiProfileRepository(
        api: _profileApi = ProfileApiService(
          client: http.Client(),
          baseUrl: Uri.parse(AuthApiService.configuredBaseUrl),
        ),
        withSession: _authRepository.withSession,
      );
  late final _identity = CurrentIdentityViewModel(
    repository: _profileRepository,
  );
  late final MarketplaceRepository _marketplaceRepository =
      widget.marketplaceRepository ??
      ApiMarketplaceRepository(
        api: _marketplaceApi = MarketplaceApiService(
          client: http.Client(),
          baseUrl: Uri.parse(AuthApiService.configuredBaseUrl),
        ),
        withSession: _authRepository.withSession,
      );
  late final AuthRepository _authRepository =
      widget.authRepository ??
      ApiAuthRepository(
        api: _api = AuthApiService(
          client: http.Client(),
          baseUrl: Uri.parse(AuthApiService.configuredBaseUrl),
        ),
        credentials: const SecureSessionCredentialStore(),
      );
  late final CommunityRepository? _community =
      widget.communityRepository ??
      (widget.authRepository == null
          ? CommunityRepository(
              CommunityApiService(
                http.Client(),
                Uri.parse(AuthApiService.configuredBaseUrl),
              ),
              _authRepository,
            )
          : null);
  late final _inbox = _community == null
      ? null
      : CommunityInboxModel(_community);
  AppLifecycleListener? _communityLifecycle;
  String? _communityUserId;
  bool _communityVisible = true;
  String get _initialLocation {
    if (widget.initialLocation != '/welcome/splash') {
      return widget.initialLocation;
    }
    final route = Uri.tryParse(
      WidgetsBinding.instance.platformDispatcher.defaultRouteName,
    );
    return communityPostPath(route?.path) ?? widget.initialLocation;
  }

  late final GoRouter _router = createAppRouter(
    campusMap: _campusMap,
    authRepository: _authRepository,
    marketplaceRepository: _marketplaceRepository,
    profileRepository: _profileRepository,
    community: _community,
    inbox: _inbox,
    identity: _identity,
    externalUrls: widget.externalUrls ?? const PlatformExternalUrlService(),
    session: _session,
    entry: _entry,
    holdSplash: widget.holdSplash,
    onOnboardingCompleted: () async {
      final completed = await _entry.completeOnboarding();
      if (completed) widget.onOnboardingCompleted?.call();
      return completed;
    },
  );
  late final AuthUiController _defaultAuthUi = AuthUiController();
  late final SessionViewModel _session = SessionViewModel(
    repository: _authRepository,
  );
  late final AppEntryViewModel _entry = AppEntryViewModel(
    auth: _authRepository,
    onboarding:
        widget.onboardingRepository ??
        OnboardingRepository(store: const SecureOnboardingStore()),
    initialLocation: _initialLocation,
    firstDestination: widget.afterSplash,
  );

  @override
  void initState() {
    super.initState();
    _authRepository.addListener(_syncProfile);
    _community?.addListener(_refreshCommunityIdentity);
    if (_community != null) {
      _communityLifecycle = AppLifecycleListener(
        onStateChange: (state) {
          final visible = state == AppLifecycleState.resumed;
          if (_communityVisible == visible) return;
          _communityVisible = visible;
          _inbox?.active(visible && _communityUserId != null);
          if (visible && _communityUserId != null) _community.invalidate();
        },
      );
    }
    _syncProfile();
    unawaited(_entry.initialize());
  }

  void _syncProfile() {
    final user = _authRepository.status == SessionStatus.authenticated
        ? _authRepository.user
        : null;
    if (_campusSessionId != null && _campusSessionId != user?.id) {
      _campusMap.resetSession();
    }
    _campusSessionId = user?.id;
    _profileRepository.bindSession(user?.id, user);
    if (_community != null && _communityUserId != user?.id) {
      _communityUserId = user?.id;
      _inbox?.active(false, clear: true);
      _community.invalidate();
      _inbox?.active(_communityVisible && user != null);
    }
    if (user != null &&
        _profileRepository.currentUser == null &&
        !_profileRepository.loading) {
      unawaited(_loadProfile());
    }
  }

  void _refreshCommunityIdentity() {
    _profileRepository.invalidatePublic();
    if (_communityUserId != null) unawaited(_loadProfile(refresh: true));
  }

  Future<void> _loadProfile({bool refresh = false}) async {
    try {
      await _profileRepository.loadOwn(refresh: refresh);
    } on Object {
      /* A profile error never invalidates a valid session. */
    }
  }

  @override
  void dispose() {
    _router.dispose();
    if (widget.campusMap == null) _campusMap.dispose();
    _entry.dispose();
    _session.dispose();
    _authRepository.removeListener(_syncProfile);
    _communityLifecycle?.dispose();
    _inbox?.dispose();
    _community?.removeListener(_refreshCommunityIdentity);
    if (widget.communityRepository == null) _community?.dispose();
    _identity.dispose();
    if (widget.profileRepository == null) _profileRepository.dispose();
    _profileApi?.close();
    if (widget.authRepository == null) _authRepository.dispose();
    _api?.close();
    _marketplaceApi?.close();
    _defaultAuthUi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthUiScope(
      controller: widget.authUi ?? _defaultAuthUi,
      child: MaterialApp.router(
        title: 'Balamandian',
        debugShowCheckedModeBanner: false,
        theme: appTheme,
        darkTheme: appDarkTheme,
        themeMode: widget.themeMode,
        routerConfig: _router,
        builder: (context, child) => AppEntryOverlay(
          model: _entry,
          child: AppBrandedBackground(child: child!),
        ),
      ),
    );
  }
}
