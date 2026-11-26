import 'package:go_router/go_router.dart';
import 'package:flutter/widgets.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/community_repository.dart';
import '../data/repositories/marketplace_repository.dart';
import '../data/services/external_url_service.dart';
import '../data/repositories/profile_repository.dart';
import '../domain/models/profile_models.dart';
import '../ui/profile/view_models/current_identity_view_model.dart';
import '../ui/profile/widgets/profile_screen.dart';
import '../ui/profile/widgets/edit_profile_screen.dart';
import '../ui/profile/widgets/member_list_screen.dart';
import '../ui/marketplace/widgets/marketplace_screen.dart';
import '../ui/marketplace/widgets/place_detail_screen.dart';
import '../domain/models/pending_registration.dart';
import '../domain/models/auth_session.dart';
import '../ui/core/ui/app_feature_placeholder.dart';
import '../ui/home/widgets/app_shell.dart';
import '../ui/home/widgets/home_screen.dart';
import '../ui/community/view_models/community_inbox_model.dart';
import '../ui/community/widgets/community_composer.dart';
import '../ui/community/widgets/community_entry_screen.dart';
import '../ui/community/widgets/community_feed.dart';
import '../ui/community/widgets/community_inbox.dart';
import '../ui/community/widgets/community_settings.dart';
import '../ui/map/view_models/campus_map_view_model.dart';
import '../ui/map/widgets/campus_map_screen.dart';
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
import 'community_post_link.dart';
import 'startup_destination.dart';
import 'shell_destination.dart';

GoRouter createAppRouter({
  required AuthRepository authRepository,
  required MarketplaceRepository marketplaceRepository,
  required ProfileRepository profileRepository,
  required CurrentIdentityViewModel identity,
  required ExternalUrlService externalUrls,
  required SessionViewModel session,
  required AppEntryViewModel entry,
  required CampusMapViewModel campusMap,
  CommunityRepository? community,
  CommunityInboxModel? inbox,
  bool holdSplash = false,
  Future<bool> Function()? onOnboardingCompleted,
}) {
  String? linkedPost(Uri uri) => community == null
      ? null
      : communityPostPath(uri.path) ??
            communityPostPath(uri.queryParameters[communityPostLinkParameter]);

  String withLinkedPost(String path, String? post) => post == null
      ? path
      : Uri(
          path: path,
          queryParameters: {communityPostLinkParameter: post},
        ).toString();

  return GoRouter(
    initialLocation: StartupDestination.splash.path,
    refreshListenable: Listenable.merge([authRepository, entry]),
    redirect: (context, state) {
      final path = state.uri.path;
      final post = linkedPost(state.uri);
      if (!entry.startupCompleted) {
        if (path == StartupDestination.splash.path) return null;
        if (!entry.startupReady) {
          return withLinkedPost(StartupDestination.splash.path, post);
        }
      } else if (path == StartupDestination.splash.path) {
        return post ??
            entry.destination ??
            StartupDestination.gettingStarted.path;
      }
      if (entry.error != null) {
        return path == '/session' ? null : withLinkedPost('/session', post);
      }
      final public =
          StartupDestination.values.any(
            (destination) => destination.path == path,
          ) &&
          path != StartupDestination.accountSetup.path;
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
        return path == '/session' ? null : withLinkedPost('/session', post);
      }
      if (authenticated) {
        if (authRepository.needsProfilePersonalization) {
          return path == StartupDestination.accountSetup.path
              ? null
              : withLinkedPost(StartupDestination.accountSetup.path, post);
        }
        return public ||
                path == '/session' ||
                path == StartupDestination.accountSetup.path
            ? post ?? '/'
            : null;
      }
      return public
          ? null
          : withLinkedPost(StartupDestination.signIn.path, post);
    },
    routes: [
      if (community != null) ...[
        GoRoute(
          path: '/posts/:id',
          builder: (context, state) => NativeSplashReveal(
            child: CommunityEntryScreen(
              key: state.pageKey,
              repository: community,
              id: state.pathParameters['id']!,
              initialPhoto:
                  int.tryParse(state.uri.queryParameters['photo'] ?? '') ?? 0,
              loadAvatar: identity.avatar,
            ),
          ),
        ),
        GoRoute(
          path: '/community/create/post',
          builder: (context, state) =>
              CommunityComposer(repository: community, story: false),
        ),
        GoRoute(
          path: '/community/create/story',
          builder: (context, state) =>
              CommunityComposer(repository: community, story: true),
        ),
        GoRoute(
          path: '/community/edit/:id',
          builder: (context, state) => CommunityEntryScreen(
            key: state.pageKey,
            repository: community,
            id: state.pathParameters['id']!,
            loadAvatar: identity.avatar,
            edit: true,
          ),
        ),
        GoRoute(
          path: '/community/stories/:id',
          builder: (context, state) => CommunityEntryScreen(
            key: state.pageKey,
            repository: community,
            id: state.pathParameters['id']!,
            loadAvatar: identity.avatar,
            story: true,
          ),
        ),
        GoRoute(
          path: '/community/saved',
          builder: (context, state) => CommunityFeed(
            repository: community,
            identity: identity,
            path: 'saved',
            title: 'Saved posts',
          ),
        ),
        GoRoute(
          path: '/community/archive',
          builder: (context, state) => CommunityFeed(
            repository: community,
            identity: identity,
            path: 'archive',
            title: 'Post archive',
          ),
        ),
        for (final kind in ['requests', 'blocked', 'muted'])
          GoRoute(
            path: '/community/$kind',
            builder: (context, state) => CommunityRelationships(
              repository: community,
              kind: kind,
              loadAvatar: identity.avatar,
            ),
          ),
        if (inbox != null)
          GoRoute(
            path: '/community/activity',
            builder: (context, state) =>
                CommunityInboxScreen(model: inbox, loadAvatar: identity.avatar),
          ),
      ],
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) =>
            EditProfileScreen(repository: profileRepository),
      ),
      GoRoute(
        path: '/members',
        builder: (context, state) => MemberListScreen(
          repository: profileRepository,
          kind: MemberListKind.discover,
        ),
        routes: [
          GoRoute(
            path: ':userId',
            builder: (context, state) => ProfileScreen(
              key: state.pageKey,
              repository: profileRepository,
              userId: state.pathParameters['userId']!,
              community: community,
            ),
            routes: [
              for (final kind in [
                MemberListKind.followers,
                MemberListKind.following,
              ])
                GoRoute(
                  path: kind.name,
                  builder: (context, state) => MemberListScreen(
                    key: state.pageKey,
                    repository: profileRepository,
                    kind: kind,
                    userId: state.pathParameters['userId']!,
                  ),
                ),
            ],
          ),
        ],
      ),
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
                    context.go(linkedPost(state.uri) ?? entry.destination!);
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
            identity: identity,
            inbox: inbox,
            communityEnabled: community != null,
            mapNavigationFocus: campusMap.navigationFocus,
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
                      ? community == null
                            ? const HomeScreen()
                            : CommunityFeed(
                                repository: community,
                                identity: identity,
                              )
                      : destination == ShellDestination.market
                      ? MarketplaceScreen(repository: marketplaceRepository)
                      : destination == ShellDestination.profile
                      ? ProfileScreen(
                          repository: profileRepository,
                          community: community,
                        )
                      : destination == ShellDestination.map
                      ? CampusMapScreen(model: campusMap)
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
                                  auxiliary == ShellDestination.settings &&
                                      community != null
                                  ? CommunitySettings(
                                      repository: community,
                                      inShell: true,
                                    )
                                  : AppFeaturePlaceholder(
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
            linkedPost: linkedPost(state.uri),
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
                      nextPath:
                          linkedPost(state.uri) ??
                          (community == null
                              ? null
                              : communityPostPath(entry.initialLocation)) ??
                          entry.destination,
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
                  StartupDestination.accountSetup => AccountSetupScreen(
                    repository: profileRepository,
                    onCompleted: authRepository.completeProfilePersonalization,
                  ),
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
