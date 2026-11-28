import 'data/repositories/scheduler_repository.dart';
import 'data/repositories/calendar_repository.dart';
import 'data/services/calendar_reminder_service.dart';
import 'ui/calendar/view_models/calendar_reminder_coordinator.dart';
import 'ui/tools/view_models/tool_session.dart';
import 'data/repositories/lost_found_repository.dart';
import 'data/services/tools_api_service.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import 'data/repositories/api_auth_repository.dart';
import 'data/repositories/guide_repository.dart';
import 'data/repositories/api_guide_repository.dart';
import 'data/services/guide_api_service.dart';
import 'ui/guide/guide_routes.dart';
import 'ui/guide/view_models/guide_session.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/community_repository.dart';
import 'data/repositories/messaging_repository.dart';
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
import 'data/repositories/task_repository.dart';
import 'data/repositories/api_task_repository.dart';
import 'data/services/task_api_service.dart';
import 'data/repositories/academic_repository.dart';
import 'data/repositories/api_academic_repository.dart';
import 'data/repositories/notes_repository.dart';
import 'data/repositories/ai_assistant_repository.dart';
import 'data/repositories/api_ai_assistant_repository.dart';
import 'data/services/ai_assistant_api_service.dart';
import 'data/repositories/api_notes_repository.dart';
import 'data/services/notes_api_service.dart';
import 'data/services/note_draft_store.dart';
import 'data/services/note_file_service.dart';
import 'ui/notes/view_models/notes_session.dart';
import 'ui/notes/view_models/notes_exit_guard.dart';
import 'domain/models/auth_session.dart';
import 'ui/profile/view_models/current_identity_view_model.dart';
import 'ui/community/view_models/community_inbox_model.dart';
import 'ui/messaging/view_models/messaging_session.dart';
import 'ui/messaging/view_models/calling_session.dart';
import 'ui/messaging/widgets/voice_call.dart';
import 'ui/messaging/widgets/messaging_scope.dart';
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
import 'ui/ai_assistant/view_models/ai_assistant_view_model.dart';
import 'ui/ai_assistant/widgets/ai_assistant_screen.dart';

class MainApp extends StatefulWidget {
  const MainApp({
    super.key,
    this.authUi,
    this.authRepository,
    this.marketplaceRepository,
    this.profileRepository,
    this.taskRepository,
    this.academicRepository,
    this.notesRepository,
    this.lostFoundRepository,
    this.calendarRepository,
    this.schedulerRepository,
    this.calendarReminders,
    this.noteDrafts,
    this.noteFiles,
    this.communityRepository,
    this.messagingRepository,
    this.externalUrls,
    this.onboardingRepository,
    this.themeMode = ThemeMode.system,
    this.initialLocation = '/welcome/splash',
    this.holdSplash = false,
    this.afterSplash = StartupDestination.campus,
    this.onOnboardingCompleted,
    this.campusMap,
    this.guideRoute,
    this.guideRepository,
    this.aiRoute,
    this.aiRepository,
  });
  final AuthUiController? authUi;
  final AuthRepository? authRepository;
  final MarketplaceRepository? marketplaceRepository;
  final ProfileRepository? profileRepository;
  final TaskRepository? taskRepository;
  final AcademicRepository? academicRepository;
  final NotesRepository? notesRepository;
  final LostFoundRepository? lostFoundRepository;
  final CalendarRepository? calendarRepository;
  final SchedulerRepository? schedulerRepository;
  final CalendarReminderService? calendarReminders;
  final NoteDraftStore? noteDrafts;
  final NoteFileService? noteFiles;
  final CommunityRepository? communityRepository;
  final MessagingRepository? messagingRepository;
  final ExternalUrlService? externalUrls;
  final OnboardingRepository? onboardingRepository;
  final ThemeMode themeMode;
  final String initialLocation;
  final bool holdSplash;
  final StartupDestination afterSplash;
  final VoidCallback? onOnboardingCompleted;
  final CampusMapViewModel? campusMap;
  final GoRoute? guideRoute;
  final GuideRepository? guideRepository;
  final GoRoute? aiRoute;
  final AiAssistantRepository? aiRepository;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  AiAssistantApiService? _aiApi;
  AiAssistantViewModel? _aiModel;
  late final GoRoute _aiRoute =
      widget.aiRoute ??
      aiAssistantRoute(
        model: _aiModel ??= AiAssistantViewModel(
          widget.aiRepository ??
              ApiAiAssistantRepository(
                _aiApi = AiAssistantApiService(
                  http.Client(),
                  Uri.parse(AuthApiService.configuredBaseUrl),
                ),
                _authRepository,
              ),
          _authRepository,
        ),
        externalUrls: widget.externalUrls ?? const PlatformExternalUrlService(),
        guideAvailable:
            widget.guideRoute?.routes.any(
              (route) =>
                  route is GoRoute && route.path == 'articles/:articleId',
            ) ??
            true,
      );
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
  TaskApiService? _taskApi;
  GuideApiService? _guideApi;
  late final GuideRepository _guideRepository =
      widget.guideRepository ??
      ApiGuideRepository(
        api: _guideApi = GuideApiService(
          client: http.Client(),
          baseUrl: Uri.parse(AuthApiService.configuredBaseUrl),
        ),
        withSession: _authRepository.withSession,
      );
  GuideSession? _guideSession;
  ToolsApiService? _schedulerApi;
  late final SchedulerRepository _schedulerRepository =
      widget.schedulerRepository ??
      ApiSchedulerRepository(
        _schedulerApi = ToolsApiService(
          client: http.Client(),
          baseUrl: Uri.parse(AuthApiService.configuredBaseUrl),
          feature: 'scheduler',
        ),
        _authRepository.withSession,
      );
  ToolsApiService? _calendarApi;
  late final CalendarRepository _calendarRepository =
      widget.calendarRepository ??
      ApiCalendarRepository(
        _calendarApi = ToolsApiService(
          client: http.Client(),
          baseUrl: Uri.parse(AuthApiService.configuredBaseUrl),
          feature: 'calendar',
        ),
        _authRepository.withSession,
      );
  late final _calendarSession = ToolSession(
    auth: _authRepository,
    profiles: _profileRepository,
    cancelPending: _calendarRepository.cancelPending,
  );
  late final CalendarReminderService _calendarDevice =
      widget.calendarReminders ?? AndroidCalendarReminders();
  late final _calendarCoordinator = CalendarReminderCoordinator(
    _calendarSession,
    _calendarRepository,
    _calendarDevice,
  );
  Map<String, String>? _calendarLink;
  void _openCalendarLink(Map<String, String> link) {
    _calendarLink = link;
    _consumeCalendarLink();
  }

  void _consumeCalendarLink() {
    final link = _calendarLink;
    if (link == null || !_entry.startupCompleted) return;
    _calendarLink = null;
    final owner = _authRepository.user?.id;
    _router.go(
      owner == link['owner']
          ? '/tools/calendar?event=${link['event']}'
          : '/tools/calendar',
    );
  }

  ToolsApiService? _lostFoundApi;
  late final LostFoundRepository _lostFoundRepository =
      widget.lostFoundRepository ??
      ApiLostFoundRepository(
        _lostFoundApi = ToolsApiService(
          client: http.Client(),
          baseUrl: Uri.parse(AuthApiService.configuredBaseUrl),
          feature: 'lost-found',
        ),
        _authRepository.withSession,
      );
  NotesApiService? _notesApi;
  late final NotesRepository _notesRepository =
      widget.notesRepository ??
      ApiNotesRepository(
        api: _notesApi = NotesApiService(
          client: http.Client(),
          baseUrl: Uri.parse(AuthApiService.configuredBaseUrl),
        ),
        withSession: _authRepository.withSession,
      );
  late final NoteDraftStore _noteDrafts =
      widget.noteDrafts ?? FileNoteDraftStore();
  late final NoteFileService _noteFiles =
      widget.noteFiles ?? PlatformNoteFileService();
  late final _notesSession = NotesSession(
    auth: _authRepository,
    profiles: _profileRepository,
    repository: _notesRepository,
  );
  final _notesGuard = NotesExitGuard();
  late final _profileTransport = _profileApi = ProfileApiService(
    client: http.Client(),
    baseUrl: Uri.parse(AuthApiService.configuredBaseUrl),
  );
  late final AcademicRepository _academicRepository =
      widget.academicRepository ??
      ApiAcademicRepository(
        api: _profileTransport,
        withSession: _authRepository.withSession,
      );
  late final TaskRepository _taskRepository =
      widget.taskRepository ??
      ApiTaskRepository(
        api: _taskApi = TaskApiService(
          client: http.Client(),
          baseUrl: Uri.parse(AuthApiService.configuredBaseUrl),
        ),
        withSession: _authRepository.withSession,
      );
  late final ProfileRepository _profileRepository =
      widget.profileRepository ??
      ApiProfileRepository(
        api: _profileTransport,
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
  late final _messagingRepository =
      widget.messagingRepository ??
      (widget.authRepository == null && _community != null
          ? MessagingRepository(
              CommunityApiService(
                http.Client(),
                Uri.parse(AuthApiService.configuredBaseUrl),
                area: 'messaging',
              ),
              _authRepository,
              _community,
            )
          : null);
  late final _messaging = _messagingRepository == null
      ? null
      : MessagingSession(_messagingRepository);
  late final _calling =
      _messagingRepository == null || widget.authRepository != null
      ? null
      : CallingSession(_messagingRepository);
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
    taskRepository: _taskRepository,
    academicRepository: _academicRepository,
    notesRepository: _notesRepository,
    lostFoundRepository: _lostFoundRepository,
    calendarRepository: _calendarRepository,
    schedulerRepository: _schedulerRepository,
    guideRoute:
        widget.guideRoute ??
        createGuideRoute(
          session: _guideSession ??= GuideSession(
            auth: _authRepository,
            repository: _guideRepository,
          ),
          externalUrls:
              widget.externalUrls ?? const PlatformExternalUrlService(),
          aiAvailable: _aiRoute.routes.any(
            (route) =>
                route is GoRoute &&
                route.path == 'conversations/:conversationId',
          ),
        ),
    aiRoute: _aiRoute,
    calendarSession: _calendarSession,
    calendarCoordinator: _calendarCoordinator,
    notesSession: _notesSession,
    noteDrafts: _noteDrafts,
    noteFiles: _noteFiles,
    notesGuard: _notesGuard,
    community: _community,
    inbox: _inbox,
    messaging: _messaging != null,
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
  late final AuthUiController _defaultAuthUi = AuthUiController(
    onGuest: () => _router.go('/tools'),
  );
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
    if (_community != null || _messaging != null) {
      _communityLifecycle = AppLifecycleListener(
        onStateChange: (state) {
          final visible = state == AppLifecycleState.resumed;
          if (_communityVisible == visible) return;
          _communityVisible = visible;
          _inbox?.active(visible && _communityUserId != null);
          _messaging?.activate(_authRepository.user?.id, visible);
          _calling?.activate(_authRepository.user?.id, visible);
          if (visible && _communityUserId != null) _community?.invalidate();
        },
      );
    }
    _syncProfile();
    _calendarCoordinator;
    _calendarDevice.onLink(_openCalendarLink);
    _entry.addListener(_consumeCalendarLink);
    _calendarDevice
        .initialLink()
        .then((link) {
          if (mounted && link != null) _openCalendarLink(link);
        })
        .catchError((Object _) {});
    unawaited(_entry.initialize());
  }

  void _syncProfile() {
    final user = _authRepository.status == SessionStatus.authenticated
        ? _authRepository.user
        : null;
    if (_campusSessionId != null && _campusSessionId != user?.id) {
      _campusMap.resetSession();
      _lostFoundRepository.cancelPending();
      _schedulerRepository.cancelPending();
      unawaited(_noteFiles.clear());
    }
    _campusSessionId = user?.id;
    _profileRepository.bindSession(user?.id, user);
    _messaging?.activate(user?.id, _communityVisible);
    _calling?.activate(user?.id, _communityVisible);
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
    _entry.removeListener(_consumeCalendarLink);
    _calendarDevice.onLink(null);
    _calendarCoordinator.dispose();
    _calendarSession.dispose();
    _calendarApi?.close();
    _schedulerApi?.close();
    _router.dispose();
    _guideSession?.dispose();
    _guideApi?.close();
    _aiModel?.dispose();
    _aiApi?.close();
    _notesSession.dispose();
    _notesApi?.close();
    _lostFoundApi?.close();
    unawaited(_noteFiles.clear());
    if (widget.campusMap == null) _campusMap.dispose();
    _entry.dispose();
    _session.dispose();
    _authRepository.removeListener(_syncProfile);
    _communityLifecycle?.dispose();
    _inbox?.dispose();
    _messaging?.dispose();
    _calling?.dispose();
    if (widget.messagingRepository == null) _messagingRepository?.dispose();
    _community?.removeListener(_refreshCommunityIdentity);
    if (widget.communityRepository == null) _community?.dispose();
    _identity.dispose();
    if (widget.profileRepository == null) _profileRepository.dispose();
    _profileApi?.close();
    _taskApi?.close();
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
          child: AppBrandedBackground(
            child: _messaging == null
                ? child!
                : MessagingScope(
                    session: _messaging,
                    profiles: _profileRepository,
                    child: _calling == null
                        ? child!
                        : CallingHost(calls: _calling, child: child!),
                  ),
          ),
        ),
      ),
    );
  }
}
