import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';

import '../data/repositories/auth_repository.dart';
import '../domain/models/pending_registration.dart';
import '../ui/home/widgets/home_screen.dart';
import '../ui/auth/widgets/account_setup_screen.dart';
import '../ui/auth/widgets/credentials_screen.dart';
import '../ui/auth/widgets/getting_started_screen.dart';
import '../ui/auth/widgets/otp_screen.dart';
import '../ui/onboarding/widgets/splash_screen.dart';
import '../ui/onboarding/widgets/startup_flow.dart';
import '../ui/onboarding/widgets/tour_screen.dart';
import 'startup_destination.dart';

GoRouter createAppRouter({
  required AuthRepository authRepository,
  String initialLocation = '/welcome/splash',
  bool holdSplash = false,
  StartupDestination afterSplash = StartupDestination.campus,
  VoidCallback? onOnboardingCompleted,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
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
