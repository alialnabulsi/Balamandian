import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';

import '../data/repositories/auth_repository.dart';
import '../domain/models/pending_registration.dart';
import '../domain/models/auth_session.dart';
import '../ui/core/ui/app_feature_placeholder.dart';
import '../ui/home/widgets/app_shell.dart';
import '../ui/home/widgets/home_screen.dart';
import '../ui/auth/widgets/account_setup_screen.dart';
import '../ui/auth/widgets/credentials_screen.dart';
import '../ui/auth/widgets/getting_started_screen.dart';
import '../ui/auth/widgets/otp_screen.dart';
import '../ui/onboarding/widgets/splash_screen.dart';
import '../ui/onboarding/widgets/startup_flow.dart';
import '../ui/onboarding/widgets/tour_screen.dart';
import 'startup_destination.dart';
import 'shell_destination.dart';

GoRouter createAppRouter({
  required AuthRepository authRepository,
  String initialLocation = '/welcome/splash',
  bool holdSplash = false,
  StartupDestination afterSplash = StartupDestination.campus,
  VoidCallback? onOnboardingCompleted,
}) {
  // Only identity already returned by this router's login/verification flow.
  // This is not restored credentials or an authentication/access policy.
  AuthUser? authenticatedUser;
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(
          navigationShell: navigationShell,
          location: state.uri.path,
          user: authenticatedUser,
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
                      : AppFeaturePlaceholder(
                          title: '${destination.label} coming soon',
                          description: switch (destination) {
                            ShellDestination.map =>
                              'Your campus map will live here.',
                            ShellDestination.market => 'The campus marketplace is planned for a future update.',
                            _ => 'Your profile will live here.',
                          },
                          icon: destination.icon,
                        ),
                  routes: destination != ShellDestination.home
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
        builder: (context, state, child) => StartupFlow(
          screen: StartupDestination.fromPath(state.uri.path),
          onOnboardingCompleted: onOnboardingCompleted,
          child: child,
        ),
        routes: [
          for (final destination in StartupDestination.values)
            GoRoute(
              path: destination.path,
              pageBuilder: (context, state) => NoTransitionPage(
                key: state.pageKey,
                child: switch (destination) {
                  StartupDestination.splash => SplashScreen(
                    hold: holdSplash,
                    nextDestination: afterSplash,
                  ),
                  StartupDestination.campus => const TourScreen(index: 0),
                  StartupDestination.community => const TourScreen(index: 1),
                  StartupDestination.assistant => const TourScreen(index: 2),
                  StartupDestination.gettingStarted =>
                    const GettingStartedScreen(),
                  StartupDestination.signIn => CredentialsScreen(
                    signingUp: false,
                    repository: authRepository,
                    onAuthenticated: (user) => authenticatedUser = user,
                  ),
                  StartupDestination.signUp => CredentialsScreen(
                    signingUp: true,
                    repository: authRepository,
                  ),
                  StartupDestination.accountSetup => const AccountSetupScreen(),
                  StartupDestination.verifyEmail => OtpScreen(
                    repository: authRepository,
                    onAuthenticated: (user) => authenticatedUser = user,
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
