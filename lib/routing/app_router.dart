import 'package:go_router/go_router.dart';
import 'package:flutter/widgets.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/marketplace_repository.dart';
import '../data/services/external_url_service.dart';
import '../ui/marketplace/widgets/marketplace_screen.dart';
import '../ui/marketplace/widgets/place_detail_screen.dart';
import '../domain/models/pending_registration.dart';
import '../domain/models/auth_session.dart';
import '../ui/core/ui/app_feature_placeholder.dart';
import '../ui/home/widgets/app_shell.dart';
import '../ui/home/widgets/home_screen.dart';
import '../ui/auth/widgets/account_setup_screen.dart';
import '../ui/auth/widgets/credentials_screen.dart';
import '../ui/auth/widgets/getting_started_screen.dart';
import '../ui/auth/widgets/otp_screen.dart';
import '../ui/auth/view_models/session_view_model.dart';
import '../ui/auth/widgets/session_gate_screen.dart';
import '../ui/onboarding/widgets/splash_screen.dart';
import '../ui/onboarding/widgets/native_splash_reveal.dart';
import '../ui/onboarding/view_models/app_entry_view_model.dart';
import '../ui/onboarding/widgets/startup_flow.dart';
import '../ui/onboarding/widgets/tour_screen.dart';
import 'startup_destination.dart';
import 'shell_destination.dart';

GoRouter createAppRouter({
  required AuthRepository authRepository,
  required MarketplaceRepository marketplaceRepository,
  required ExternalUrlService externalUrls,
  required SessionViewModel session,
  required AppEntryViewModel entry,
  bool holdSplash = false,
  Future<bool> Function()? onOnboardingCompleted,
}) {
  return GoRouter(
    initialLocation: StartupDestination.splash.path,
    refreshListenable: Listenable.merge([authRepository, entry]),
    redirect: (context, state) {
      final path = state.uri.path;
      if (!entry.startupCompleted) {
        if (path == StartupDestination.splash.path) return null;
        if (!entry.startupReady) return StartupDestination.splash.path;
      } else if (path == StartupDestination.splash.path) {
        return entry.destination ?? StartupDestination.gettingStarted.path;
      }
      if (entry.error != null) return path == '/session' ? null : '/session';
      final public = StartupDestination.values.any(
        (destination) => destination.path == path,
      );
      final authenticated =
          authRepository.status == SessionStatus.authenticated ||
          (authRepository.status == SessionStatus.signingOut &&
              authRepository.user != null);
      final blocked =
          authRepository.status == SessionStatus.initializing ||
          authRepository.status == SessionStatus.validationError ||
          (authRepository.status == SessionStatus.signingOut &&
              authRepository.user == null);
      if (blocked) {
        return path == '/session' ? null : '/session';
      }
      if (authenticated) return public || path == '/session' ? '/' : null;
      if (path == '/session') {
        return StartupDestination.signIn.path;
      }
      return public ? null : StartupDestination.signIn.path;
    },
    routes: [
      GoRoute(
        path: '/session',
        builder: (context, state) => SessionGateScreen(
          model: session,
          entryError: entry.error,
          onRetry: entry.error == null
              ? null
              : () async {
                  await entry.retryPreferences();
                  if (context.mounted && entry.error == null) {
                    context.go(entry.destination!);
                  }
                },
          allowLocalSignOut: entry.error == null,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => NativeSplashReveal(
          child: AppShell(
            navigationShell: navigationShell,
            location: state.uri.path,
            session: session,
          ),
        ),
        branches: [
          for (final destination in ShellDestination.tabs)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: destination.path,
                  builder: (context, state) =>
                      destination == ShellDestination.home
                      ? const HomeScreen()
                      : destination == ShellDestination.market
                      ? MarketplaceScreen(repository: marketplaceRepository)
                      : AppFeaturePlaceholder(
                          title: '${destination.label} coming soon',
                          description: switch (destination) {
                            ShellDestination.map =>
                              'Your campus map will live here.',
                            _ => 'Your profile will live here.',
                          },
                          icon: destination.icon,
                        ),
                  routes: destination == ShellDestination.market
                      ? [
                          GoRoute(
                            path: ':placeId',
                            builder: (context, state) => PlaceDetailScreen(
                              key: state.pageKey,
                              placeId: state.pathParameters['placeId']!,
                              repository: marketplaceRepository,
                              externalUrls: externalUrls,
                            ),
                          ),
                        ]
                      : destination != ShellDestination.home
                      ? []
                      : [
                          for (final auxiliary in ShellDestination.auxiliary)
                            GoRoute(
                              // Children of '/' retain Home beneath them for back.
                              path: auxiliary.path.substring(1),
                              builder: (context, state) =>
                                  AppFeaturePlaceholder(
                                    title: '${auxiliary.label} coming soon',
                                    description: 'This part of Balamandian is planned for a future update.',
                                    icon: auxiliary.icon,
                                    onBack: () => context.go('/'),
                                  ),
                            ),
                        ],
                ),
              ],
            ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => ListenableBuilder(
          listenable: entry,
          builder: (context, _) => StartupFlow(
            screen: StartupDestination.fromPath(state.uri.path),
            onOnboardingCompleted: onOnboardingCompleted,
            onStartupCompleted: entry.completeStartup,
            onboardingError: entry.onboardingError,
            child: state.uri.path == StartupDestination.splash.path
                ? child
                : NativeSplashReveal(child: child),
          ),
        ),
        routes: [
          for (final destination in StartupDestination.values)
            GoRoute(
              path: destination.path,
              pageBuilder: (context, state) => NoTransitionPage(
                key: state.pageKey,
                child: switch (destination) {
                  StartupDestination.splash => ListenableBuilder(
                    listenable: entry,
                    builder: (context, _) => SplashScreen(
                      hold: holdSplash || !entry.startupReady,
                      nextPath: entry.destination,
                      onAnimationCompleted: entry.animationCompleted,
                    ),
                  ),
                  StartupDestination.campus => const TourScreen(index: 0),
                  StartupDestination.community => const TourScreen(index: 1),
                  StartupDestination.assistant => const TourScreen(index: 2),
                  StartupDestination.gettingStarted =>
                    const GettingStartedScreen(),
                  StartupDestination.signIn => CredentialsScreen(
                    signingUp: false,
                    repository: authRepository,
                    notice: authRepository.sessionNotice,
                  ),
                  StartupDestination.signUp => CredentialsScreen(
                    signingUp: true,
                    repository: authRepository,
                  ),
                  StartupDestination.accountSetup => const AccountSetupScreen(),
                  StartupDestination.verifyEmail => OtpScreen(
                    repository: authRepository,
                    registration: state.extra is PendingRegistration
                        ? state.extra as PendingRegistration
                        : null,
                  ),
                },
              ),
            ),
        ],
      ),
    ],
  );
}
