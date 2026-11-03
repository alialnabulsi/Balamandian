import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'routing/app_router.dart';
import 'routing/startup_destination.dart';
import 'ui/core/themes/app_theme.dart';
import 'ui/auth/view_models/auth_ui_controller.dart';
import 'ui/onboarding/widgets/native_splash_handoff.dart';

class MainApp extends StatefulWidget {
  const MainApp({
    super.key,
    this.authUi,
    this.themeMode = ThemeMode.system,
    this.initialLocation = '/welcome/splash',
    this.holdSplash = false,
    this.afterSplash = StartupDestination.campus,
    this.onOnboardingCompleted,
  });
  final AuthUiController? authUi;
  final ThemeMode themeMode;
  final String initialLocation;
  final bool holdSplash;
  final StartupDestination afterSplash;
  final VoidCallback? onOnboardingCompleted;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final GoRouter _router = createAppRouter(
    initialLocation: widget.initialLocation,
    holdSplash: widget.holdSplash,
    afterSplash: widget.afterSplash,
    onOnboardingCompleted: widget.onOnboardingCompleted,
  );
  late final AuthUiController _defaultAuthUi = AuthUiController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _router.routeInformationProvider.value.uri.path !=
              StartupDestination.splash.path) {
        // A direct route has no branded splash to release Android's overlay.
        unawaited(NativeSplashHandoff.reveal());
      }
    });
  }

  @override
  void dispose() {
    _router.dispose();
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
