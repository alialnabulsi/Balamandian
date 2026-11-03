import 'package:go_router/go_router.dart';

import '../ui/home/widgets/home_screen.dart';
import '../ui/auth/widgets/account_setup_screen.dart';
import '../ui/auth/widgets/credentials_screen.dart';
import '../ui/auth/widgets/getting_started_screen.dart';
import '../ui/onboarding/widgets/splash_screen.dart';
import '../ui/onboarding/widgets/startup_flow.dart';
import '../ui/onboarding/widgets/tour_screen.dart';
import 'startup_destination.dart';

GoRouter createAppRouter({
  String initialLocation = '/welcome/splash',
  bool holdSplash = false,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      ShellRoute(
        builder: (context, state, child) => StartupFlow(
          screen: StartupDestination.fromPath(state.uri.path),
          child: child,
        ),
        routes: [
          for (final destination in StartupDestination.values)
            GoRoute(
              path: destination.path,
              pageBuilder: (context, state) => NoTransitionPage(
                key: state.pageKey,
                child: switch (destination) {
                  StartupDestination.splash => SplashScreen(hold: holdSplash),
                  StartupDestination.campus => const TourScreen(index: 0),
                  StartupDestination.community => const TourScreen(index: 1),
                  StartupDestination.assistant => const TourScreen(index: 2),
                  StartupDestination.gettingStarted =>
                    const GettingStartedScreen(),
                  StartupDestination.signIn => const CredentialsScreen(
                    signingUp: false,
                  ),
                  StartupDestination.signUp => const CredentialsScreen(
                    signingUp: true,
                  ),
                  StartupDestination.accountSetup => const AccountSetupScreen(),
                },
              ),
            ),
        ],
      ),
    ],
  );
}
