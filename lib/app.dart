import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import 'data/repositories/api_auth_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/services/auth_api_service.dart';
import 'data/services/session_credential_store.dart';
import 'routing/app_router.dart';
import 'routing/startup_destination.dart';
import 'ui/core/themes/app_theme.dart';
import 'ui/auth/view_models/auth_ui_controller.dart';
import 'ui/auth/view_models/session_view_model.dart';

class MainApp extends StatefulWidget {
  const MainApp({
    super.key,
    this.authUi,
    this.authRepository,
    this.themeMode = ThemeMode.system,
    this.initialLocation = '/welcome/splash',
    this.holdSplash = false,
    this.afterSplash = StartupDestination.campus,
    this.onOnboardingCompleted,
  });
  final AuthUiController? authUi;
  final AuthRepository? authRepository;
  final ThemeMode themeMode;
  final String initialLocation;
  final bool holdSplash;
  final StartupDestination afterSplash;
  final VoidCallback? onOnboardingCompleted;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  AuthApiService? _api;
  late final AuthRepository _authRepository =
      widget.authRepository ??
      ApiAuthRepository(
        api: _api = AuthApiService(
          client: http.Client(),
          baseUrl: Uri.parse(AuthApiService.configuredBaseUrl),
        ),
        credentials: const SecureSessionCredentialStore(),
      );
  late final GoRouter _router = createAppRouter(
    authRepository: _authRepository,
    session: _session,
    initialLocation: widget.initialLocation,
    holdSplash: widget.holdSplash,
    afterSplash: widget.afterSplash,
    onOnboardingCompleted: widget.onOnboardingCompleted,
  );
  late final AuthUiController _defaultAuthUi = AuthUiController();
  late final SessionViewModel _session = SessionViewModel(
    repository: _authRepository,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_authRepository.restoreSession());
  }

  @override
  void dispose() {
    _router.dispose();
    _session.dispose();
    if (widget.authRepository == null) _authRepository.dispose();
    _api?.close();
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
      ),
    );
  }
}
