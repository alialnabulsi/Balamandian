import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'routing/app_router.dart';
import 'ui/core/themes/app_theme.dart';
import 'ui/auth/view_models/auth_ui_controller.dart';

class MainApp extends StatefulWidget {
  const MainApp({
    super.key,
    this.authUi,
    this.themeMode = ThemeMode.system,
    this.initialLocation = '/welcome/splash',
    this.holdSplash = false,
  });
  final AuthUiController? authUi;
  final ThemeMode themeMode;
  final String initialLocation;
  final bool holdSplash;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final GoRouter _router = createAppRouter(
    initialLocation: widget.initialLocation,
    holdSplash: widget.holdSplash,
  );
  late final AuthUiController _defaultAuthUi = AuthUiController();

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
