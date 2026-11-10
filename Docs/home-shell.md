# Home Shell

Session ownership, identity handoff, route access and logout have since been
completed in [the session lifecycle implementation](auth-session-lifecycle.md).
The notes below describe the original shell implementation.

Implemented on `feature/home-shell`, based on the clean, fetched and up-to-date
`dev` branch. No commits, merges into other branches, or pushes are part of this task.

## Composition and reuse

`AppShell` owns one Scaffold, its top bar, native Material 3 account drawer,
route-dependent body, bottom bar, and floating quick-actions control. The existing
startup/authentication ShellRoute remains separate. No additional state-management
package or shell ViewModel is needed: navigation, layout and animation are local
presentation concerns under the existing MVVM conventions.

| Component | Responsibility |
| --- | --- |
| `ShellDestination` | Central paths, labels, icons, tab indices and drawer/auxiliary destination lists. |
| `BalamandianTopBar` | Avatar callback, responsive branded wordmark, configurable actions and future badge slots. |
| `AppIconButton`, `AppAvatar` | Labeled 48 dp targets and configurable images with a neutral fallback. |
| `AppAccountDrawer`, `AccountHeader` | Native scrollable drawer destinations and available identity; no invented account data. |
| `AppBottomBar`, `AppNavigationItem` | Four tab buttons with selected semantics, plus an independent gold Create action and native safe-area handling. |
| `ExpandableQuickActions`, `QuickAction`, `AppQuickAction` | Configurable three-action fan, reusable circles, native modal dismissal/focus, and staggered 280 ms scale/translation/fade. |
| `AppBrandedBackground` | Static repeating custom-painted olive branches, caps, books and academic sparks, isolated in a RepaintBoundary. |
| `AppFeaturePlaceholder` | Accessible empty-state copy with optional back action; centers when space permits and scrolls on short screens. |
| `ShellTokens`, `ShellPalette` | Shared shell geometry/motion and filled blue action colors. The gold accent and light/dark surfaces use ColorScheme/component themes. |

The wordmark scales down to keep its full text visible on narrow phones. Content
text follows the system text scale. Quick-action circles grow with text scale,
fit within safe bounds, and fit short labels within the available circle.
Reduced-motion preferences skip the fan transition. Actions use themed dark
surfaces in dark mode and white surfaces in light mode.

## Destinations and identity

| Location/control | Current behavior |
| --- | --- |
| `/` | Branded background and community-feed empty state; no social data or widgets. |
| `/map`, `/market`, `/profile` | Independent persistent branches with clearly labeled coming-soon bodies. |
| `/guide`, `/ai`, `/tools`, `/settings` | Nested Home placeholders, with Android back and a visible Back to Home action. No bottom tab is selected on these auxiliary routes. |
| Avatar | Opens the left drawer; back, swipe and outside tapping use Scaffold/NavigationDrawer behavior. |
| Search, Notifications, Messages, Create | Explicit coming-soon SnackBar feedback; Create never becomes a tab. |
| Quick actions | Guide upper-left, AI upper-right, Tools lower-left, Close lower-right. Outside taps, close and back dismiss the popup before underlying navigation. Selecting an action collapses before navigating. |

`StatefulShellRoute.indexedStack` retains loaded tab widgets. Tapping the current
tab resets its nested location; tapping Home always returns to `/`. The Home root
widget remains mounted when switching tabs. Replacing Home's empty state with a
ListView or CustomScrollView of feed components requires no shell restructuring.

Login and OTP ViewModels now retain the `AuthUser` already returned by their
existing repository operations. Optional success callbacks pass it to the router
only after successful secure session storage, before the existing `go('/')`.
The router retains this identity in memory for its lifetime; the drawer shows
the returned institutional email and SIS ID. There is no returned avatar/name,
so the avatar remains neutral. Direct shell routes without an in-memory identity
also use a neutral header. This introduces no startup token read, profile request,
session restoration, route guard, logout or guest flow.

## Changed file tree

`+` new, `~` modified. No dependencies or runtime image assets were added.

```text
~ README.md
+ Docs/home-shell.md
lib/
  routing/
    ~ app_router.dart
    + shell_destination.dart
  ui/
    auth/
      view_models/
        ~ credentials_view_model.dart
        ~ otp_view_model.dart
      widgets/
        ~ credentials_screen.dart
        ~ otp_screen.dart
    core/
      themes/
        ~ app_theme.dart
        + shell_tokens.dart
      ui/
        + app_feature_placeholder.dart
        avatars/
          + app_avatar.dart
        backgrounds/
          + app_branded_background.dart
        buttons/
          + app_icon_button.dart
        navigation/
          + account_header.dart
          + app_account_drawer.dart
          + app_bottom_bar.dart
          + app_navigation_item.dart
          + balamandian_top_bar.dart
        quick_actions/
          + app_quick_action.dart
          + expandable_quick_actions.dart
    home/widgets/
      + app_shell.dart
      ~ home_screen.dart
test/
  routing/
    ~ app_router_test.dart
  ui/
    auth/
      ~ credentials_test.dart
    home/
      + home_shell_test.dart
```

## Verification

Use the installed Flutter/Dart SDK binaries if they are not on PATH.

```sh
dart format <changed Dart files>
flutter analyze --no-pub lib/routing lib/ui/home lib/ui/core lib/ui/auth/view_models/credentials_view_model.dart lib/ui/auth/view_models/otp_view_model.dart lib/ui/auth/widgets/credentials_screen.dart lib/ui/auth/widgets/otp_screen.dart test/ui/home test/routing/app_router_test.dart test/ui/auth/credentials_test.dart
flutter test --no-pub test/ui/home/home_shell_test.dart test/routing/app_router_test.dart test/ui/auth/credentials_test.dart
```

Focused coverage includes tab/root widget retention, Create feedback, all top-bar
feedback, native drawer dismissal and Settings, all three quick-action destinations,
staggered motion, reduced motion, external navigation dismissal, nested-route back
behavior, authentication remaining outside the shell, successful signup/login with
identity handoff, and secure-storage failure behavior. Layout/accessibility checks
include 320×640 phones at 2× text, 640×320 landscape, gesture insets, selected-state
semantics, Android touch targets, labeled targets and text contrast in both themes.
Shell tests fail if any network request is made.

Results: 24 changed Dart files formatted; focused analysis reported no issues.
All 19 focused shell/routing/authentication tests passed. After migrating the
selected-semantics assertion to the current `flagsCollection` API, the two
light/dark accessibility cases were rerun and passed.

Rendered Flutter previews were inspected at 390×844 in light/dark mode (collapsed,
expanded and drawer) and at 320×640. Local PNGs are in the ignored
`build/ui-verification/home-shell/` directory. No full Android build or live backend
test was run; successful-auth navigation uses the existing mocked-HTTP widget flows.

## Remaining product decisions

The feed, profile data/avatar source, map, marketplace, Guide, AI, Tools, Settings,
search, notifications, messages and Create functionality remain deferred. The shell
adds no social models, services, repositories or backend changes. Authentication
access policies, restoration and logout still need their separate requirements.

## Official documentation consulted

- [Flutter architecture guide](https://docs.flutter.dev/app-architecture/guide)
- [Flutter themes](https://docs.flutter.dev/cookbook/design/themes)
- [go_router StatefulShellRoute](https://pub.dev/documentation/go_router/latest/go_router/StatefulShellRoute-class.html)
- [Material NavigationDrawer](https://api.flutter.dev/flutter/material/NavigationDrawer-class.html)
- [Scaffold drawer](https://api.flutter.dev/flutter/material/Scaffold/drawer.html)
- [Material BottomAppBar](https://api.flutter.dev/flutter/material/BottomAppBar-class.html)
- [RawDialogRoute](https://api.flutter.dev/flutter/widgets/RawDialogRoute-class.html)
- [Staggered animations](https://docs.flutter.dev/ui/animations/staggered-animations)
- [Reduced animations](https://api.flutter.dev/flutter/widgets/MediaQuery/disableAnimationsOf.html)
- [SingleChildScrollView constraints](https://api.flutter.dev/flutter/widgets/SingleChildScrollView-class.html)
- [Transform hit testing](https://api.flutter.dev/flutter/widgets/Transform/transformHitTests.html)
- [Widget testing](https://docs.flutter.dev/cookbook/testing/widget/introduction)
- [Dart formatting](https://dart.dev/tools/dart-format)
