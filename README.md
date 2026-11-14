# Balamandian

A Flutter Android client. This README records the agreed architecture and code
organization, adapted from Flutter's [Compass architecture case study](https://docs.flutter.dev/app-architecture/case-study#package-structure),
architecture guide, and recommendations. These are principles to apply as the
app grows, rather than a requirement to reproduce every Compass directory.

Current architecture-related structure, including prepared directories:

Directories marked `prepared` contain only a `.gitkeep` file so Git can track
them. They do not contain feature implementations or tests.

```text
assets/marketplace/images/         # Approved local photos and generic fallback.
lib/
  main.dart                       # Entry point: launches the app.
  app.dart                        # Root widget and MaterialApp configuration.
  routing/
    app_router.dart               # Application route table and router factory.
  ui/
    core/
      themes/
        app_theme.dart            # Shared application theme.
      ui/                         # Shared branding, controls, copy, artwork and motion.
    home/
      widgets/
        app_shell.dart            # Persistent Home navigation and composition.
        home_screen.dart          # Branded future-feed empty state.
    marketplace/
      widgets/                    # Live marketplace and nested place detail components.
      view_models/                # Search, filters, pagination, favorites and ratings.
    onboarding/
      widgets/                    # Splash, three tour screens, artwork and startup flow.
      view_models/                # App entry coordination and foreground re-entry.
    auth/
      widgets/                    # Entry choices, sign-in/up and account setup.
      view_models/                # Credentials/OTP state, deferred profile UI state.
  data/
    repositories/                 # Auth and marketplace contracts/API implementations.
    services/                     # Auth/marketplace HTTP, secure session storage, external links.
  domain/
    models/                       # Auth types and immutable marketplace DTOs/pages/errors.
test/
  domain/models/                  # Marketplace response and immutable-model tests.
  routing/
    app_router_test.dart          # Router wiring and lifecycle checks.
  ui/
    onboarding/                   # Tour, navigation, transitions and reduced motion.
    auth/                         # Form, pending, photo and callback tests.
    marketplace/                  # ViewModels, widgets, layout, accessibility and screenshots.
    startup_visual_test.dart      # Native screenshots and constrained-layout checks.
  data/
    repositories/                 # Auth orchestration and protected marketplace boundary tests.
    services/                     # Mocked HTTP contract and secure-storage tests.
```

The [reference folder diagram](Docs/Images/FolderStructure.png) illustrates
broader possible organization, including deferred paths; it is not the current
repository tree. The text tree above records the actual prepared structure.

`main.dart` launches `MainApp`; `app.dart` owns the root `MaterialApp.router`
and router lifecycle. Startup opens `/welcome/splash`; the approved startup
destinations and email OTP verification live under `/welcome`. Home stays at `/`
inside the persistent application shell, alongside Map, Market and Profile.
Inter typography and the handoff's exact light/dark palette are shared themes.
Registration, email OTP verification/resend and SIS login connect to Balamandian-API.
Successful verification/login securely saves the newly issued session before opening Home.
The shared authentication repository restores saved sessions through `/me`, owns
the current account identity, protects shell routes, and coordinates current-session
logout. See [the session lifecycle report](Docs/auth-session-lifecycle.md) for
state transitions, recovery behavior, verification, and Android test steps.
The [startup regression report](Docs/auth-startup-regression.md) documents native
splash release during saved-session restoration and restart/device verification.
The [universal splash report](Docs/universal-splash.md) records full animation
coordination, persisted onboarding completion, and retained-navigation re-entry.
See [the API integration report](Docs/auth-api-integration.md) for configuration,
scope and verification, and [the initial UI report](Docs/onboarding-auth-implementation.md)
for the initial screen map and integration contract. The
[focused refinement report](Docs/onboarding-auth-refinement.md) records updated
splash, tool-card motion, navigation and entry theme behavior. The
[final polish report](Docs/onboarding-auth-final-polish.md) documents native
splash synchronization, logo continuity and the final assistant/auth copy changes.

Agreed architecture and future organization:

Use Compass's hybrid organization: group UI code by feature and shared data code
by type. Keep the existing `lib/ui/<feature>/` layout, without adding a separate
`features/` level. The table defines placement conventions. The onboarding and
authentication features use the directories shown above;
create other future paths only alongside code needed by a real feature.

| Location | Responsibility | Current status |
| --- | --- | --- |
| `lib/ui/<feature>/widgets/` | Feature screen and its local widgets. | Implemented for `home`, `onboarding`, `auth` and `marketplace`. |
| `lib/ui/<feature>/view_models/` | Presentation logic, UI state, and user-action methods. | Auth presentation, credential validation, photo state, and app-entry/re-entry coordination. |
| `lib/ui/core/ui/` | Reusable, configurable widget classes shared across features. | Shared branding, buttons, fields feedback, body copy, crest and decorative motion. |
| `lib/ui/core/themes/` | Shared theme configuration. | Exists. |
| `lib/data/repositories/` | Sources of truth organized by application data type; contracts and implementations, including authentication and session state. | Authentication and marketplace contracts/API implementations; auth persistence completes before authentication succeeds. |
| `lib/data/services/` | External API access, response decoding, local storage, and other data-source adapters; no presentation logic or application data state. | Auth/marketplace HTTP, secure credential store and injectable external URL launching. |
| `lib/data/model/` | API-specific response/request models when a separate representation is needed. | Conditional future path, using Compass's singular `model/` name. |
| `lib/domain/models/` | Immutable application data types consumed by repositories and view models. | Auth models and immutable marketplace categories, places, posts, pages, mutation results and failures. |
| `lib/routing/` | Application route configuration. | Exists. |

Onboarding screens, page components, and local UI belong in
`lib/ui/onboarding/widgets/`; their presentation state and user actions belong
in the adjacent `view_models/`. Authentication UI, such as welcome, login,
account creation, and OTP verification, belongs in `lib/ui/auth/widgets/`, with
presentation state and commands in its `view_models/`. These are placement
conventions; OTP reuses the approved authentication components. Both features use the same architecture and
component-first rules: inspect existing widgets before adding reusable,
configurable widget classes, compose screens from them, and centralize shared
styling in the theme.

Views render state and forward user actions to their view models. Keep business
and data-access logic out of widgets; layout, animation, and simple navigation
remain view responsibilities. Pair a view with a view model when it needs
presentation logic; this does not mean one view model per individual widget.
Keep `main.dart` minimal and `app.dart` as the root application configuration.

Data boundaries:

The Flutter client communicates with Balamandian-API and must never call SIS-API
directly. Balamandian-API owns the backend authentication workflow and SIS-API
integration. The dependency direction is
`View -> ViewModel -> Repository -> Service -> Balamandian-API`. Views do not
call repositories or services directly; view models consume repositories and
do not make HTTP requests. Services do not contain presentation logic.

View models consume repository contracts; repositories privately consume services
and expose application models. Data and resulting state updates flow back toward
the UI. Repositories own data updates and the data policies a feature actually
requires. Keep repositories independent of each other; combine their outputs in
the view model, or an optional use case when warranted.

Introduce focused abstract repository contracts and their required implementations
with the consuming feature and approved API contract. Inject services and
repositories through constructors and wire dependencies at the application
composition point when needed. Separate API models from application models only
when their shapes or responsibilities differ. Placing data types in
`domain/models/` does not require a domain use-case layer.

Testing and deliberately deferred structure:

Keep unit and widget tests in `test/`, mirroring the relevant `lib/` paths as
components are added; `test/routing/` already follows this convention. Test new
services, repositories, and view models independently, and views with widget
tests. Introduce fakes alongside tests that need them. A separate `testing/`
subpackage is only justified by actual shared test-support requirements.

Tests mirror the implemented features and data layer. Shared authentication
fixtures and an in-memory credential-store fake live in `test/auth_test_support.dart`.
HTTP tests inject `http.MockClient`; widget tests use the actual service/repository
with mocked network responses. Remove each `.gitkeep` when its directory contains real files.

Authentication uses `http`, build-time `API_BASE_URL`, `flutter_secure_storage`,
and allowlisted error messages. Defer caching, automatic retries and offline
support until feature requirements justify them. The explicitly prepared directories above
are the exception to the normal preference against empty folders; remove each
`.gitkeep` when its directory contains real files. Do not pre-create additional
empty folders, speculative endpoints, generic base repositories, a
dependency-injection container, or code generation. Add use cases only when
complex or repeated logic warrants them.
Compass's `config/`, `utils/`, and separate environment entry points are examples,
not a checklist: introduce them only for concrete configuration, reusable
utilities, or distinct startup requirements. State management, dependency
injection packages, and model code generation remain feature-driven decisions;
Compass's particular package choices are not prerequisites for these boundaries.

Navigation (current foundation and future conventions):

Navigation uses Flutter's recommended `go_router` package with
`MaterialApp.router`. The route table lives in `lib/routing/app_router.dart`.
`/` displays Home; `/map`, `/market` and `/profile` are persistent shell branches.
`/guide`, `/ai`, `/tools` and `/settings` are lightweight placeholders nested under Home.
`/welcome/*` contains the startup screens and OTP verification outside this shell.
Their persistent shell owns the approved curved wipe and prevents duplicate navigation.
`MainApp` owns one router for its widget lifecycle, retains it across rebuilds,
and disposes it when removed. `main.dart` remains only an entry point. Light/dark
themes, constructor-injected authentication dependencies and shared navigation
presentation state are composed at the app root.

Add real destinations to the route table when their features exist. Widgets
can use go_router's context navigation methods for simple navigation. Keep
session and authorization decisions out of feature widgets; introduce router
redirects or guards that consume the actual application state once authentication
and screen access policies are specified. Client routing will not replace
server-side authorization.

Authentication redirects and session restoration consume the shared repository's
notifications. Every actual launch first plays the original Flutter splash at
`/welcome/splash`, concurrently with session restoration. The existing transition
opens the resolved destination after both complete. `/session` provides Retry
for recoverable validation errors. Shell destinations require an authenticated session; login,
registration, OTP and onboarding remain public. Successful restoration opens
Home; invalid sessions and logout lead to Login with protected history removed.
Refresh tokens, roles and additional access rules remain deferred. The Home shell uses
`StatefulShellRoute.indexedStack` for its four tab navigators. Native app-link configuration is
also deferred; adopting a declarative router alone does not configure it.
Unmatched locations use go_router's built-in error handling; a custom not-found
experience awaits an approved design. Map and Profile placeholders are explicit;
no role policies or route code generation are included. Registration opens `/welcome/verify-email`;
successful verification/login opens Home after secure session persistence.
Account setup and guest actions remain unconnected. Onboarding completion is
persisted separately from credentials: first-time users see the tour, returning
unauthenticated users see the existing auth entry, and validated sessions open
Home after the full splash. Genuine background returns replay the same splash
over the retained router without resetting navigation or calling `/me` again.

The authenticated marketplace now implements `/market` and nested `/market/:placeId`
inside the retained Market branch. Search, categories, news/advertisements, place
details, favorites and personal star ratings use the real marketplace API through
`AuthRepository.withSession`. Local placeholder photos match the approved reference;
external directions/contact links use `url_launcher`. No marketplace data is
hardcoded in Dart. See [marketplace implementation](Docs/marketplace.md) for
architecture, assets, endpoint usage and verification. Map/Profile and all shared
shell controls retain their existing behavior.

See [Home Shell implementation notes](Docs/home-shell.md) for the component tree,
destination behavior, identity handoff, theme decisions and focused checks.

Local authentication development:

```sh
# Android emulator (also the default debug origin)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000

# USB-connected Android phone
adb reverse tcp:3000 tcp:3000
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

Run Balamandian-API separately on port 3000. `API_BASE_URL` is an origin without
an `/api` suffix. Only debug builds allow HTTP, restricted to emulator/loopback
hosts. Profile/release builds require an explicit HTTPS origin, for example
`--dart-define=API_BASE_URL=https://api.example.com`. Build definitions contain
public configuration only; SIS/Resend keys stay in the backend. Session tokens
remain in the existing secure-storage record and are validated at startup.
Transient failures retain the token and block protected UI until validation succeeds.
There is no refresh-token mechanism; expired sessions require login.

Navigation references:

- [Flutter navigation and routing](https://docs.flutter.dev/ui/navigation)
- [Flutter architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations)
- [go_router configuration](https://pub.dev/documentation/go_router/latest/topics/Configuration-topic.html)
- [go_router redirection](https://pub.dev/documentation/go_router/latest/topics/Redirection-topic.html)
- [MaterialApp.router](https://api.flutter.dev/flutter/material/MaterialApp/MaterialApp.router.html)

Theming (current baseline and future conventions):

The application theme is defined once in `lib/ui/core/themes/app_theme.dart`
and applied by `MaterialApp` in `lib/app.dart`. It now uses the approved handoff's
exact colors, bundled Inter weights, control dimensions and system light/dark
appearances. `startup_tokens.dart` centralizes the custom palette, geometry and
motion. `StartupPalette` extends the theme for the handoff's extra semantic colors.
The refined entry uses the existing pale-blue tokens in light appearance and
retains the navy canvas in dark appearance. Native startup now matches the blue
branded Flutter splash; its circular loading stroke controls the first transition.

Configure future approved design changes in `colorScheme`, `textTheme` and
component themes centrally; use specified roles directly when exact colors exist.
Custom widgets should read semantic values from `Theme.of(context).colorScheme`
and `Theme.of(context).textTheme`. Standard Material widgets already inherit
the app theme. The app follows system appearance; `MainApp.themeMode` supports host control and review.
The Home shell adds gold `tertiary` actions, themed navigation surfaces, and a
`ShellPalette` for filled blue quick actions. Its static vector background is
opt-in through `AppBrandedBackground`; authentication keeps its existing artwork.

Theming references:

- [Flutter design and theming](https://docs.flutter.dev/ui/design)
- [Flutter themes cookbook](https://docs.flutter.dev/cookbook/design/themes)
- [Material Design for Flutter](https://docs.flutter.dev/ui/design/material)
- [ThemeData configuration](https://api.flutter.dev/flutter/material/ThemeData/ThemeData.html)
- [Default light theme](https://api.flutter.dev/flutter/material/ThemeData/ThemeData.light.html)
- [MaterialApp theme](https://api.flutter.dev/flutter/material/MaterialApp/theme.html)

Architecture references:

- [Flutter architecture guide](https://docs.flutter.dev/app-architecture/guide)
- [Flutter architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations)
- [Compass case study and package structure](https://docs.flutter.dev/app-architecture/case-study)
- [Compass data-layer case study](https://docs.flutter.dev/app-architecture/case-study/data-layer)

Android development baseline and release limitations:

Observed on 2026-10-31 from the installed Flutter SDK and checked-in configuration.
These values describe the current setup; they do not pin the installed toolchain
or establish that release builds have been validated.

| Component | Observed version or configuration |
| --- | --- |
| Flutter / Dart | Flutter 3.47.5 stable / Dart 3.13.4 |
| Android Gradle Plugin / Gradle wrapper | 9.1.0 / 9.3.1 |
| Kotlin Gradle Plugin declaration | 2.4.0 (`apply false` in settings) |
| Java / Kotlin bytecode targets | 17; this does not specify the JDK used to run Gradle |
| Flutter-managed Android SDK levels | Minimum 24; compile and target 36 |
| Flutter-managed NDK | 28.2.13676358 |

Keep SDK levels and compatibility flags as configured unless a deliberate
toolchain update or feature requirement warrants changes. Android versioning
comes from `pubspec.yaml`: `0.1.0+1` currently maps to version name `0.1.0` and
version code `1`.

- Application ID, namespace, and Kotlin package remain `com.example.balamandian`.
  A final identity requires approval before distribution or identity-dependent
  integrations; none has been selected here.
- Release builds currently use debug signing for local development and are not
  suitable for store publication. Approve key ownership and configure production
  signing during release preparation; keep signing credentials outside Git.
- `INTERNET` permission is in the main manifest for authentication networking.
  Debug-only network rules allow local HTTP; other builds require HTTPS. Secure
  storage is excluded from Android backup and device transfer. Signing remains
  the existing development configuration.

Repository hygiene:

Diagnostic bug-report ZIP/text files and heap dumps are ignored. Keep diagnostic
copies local or in an appropriate restricted location, and review them before
sharing. Untracking a diagnostic archive preserves its local copy but does not
remove copies from earlier commits or existing clones. Any history cleanup needs
a separate exposure assessment and approval.

References:

- [Flutter Android deployment](https://docs.flutter.dev/deployment/android)
- [Android app signing](https://developer.android.com/studio/publish/app-signing)
- [Git ignore rules](https://git-scm.com/docs/gitignore)
- [Git index-only removal](https://git-scm.com/docs/git-rm#Documentation/git-rm.txt---cached)

Lightweight validation commands (run from the repository root after resolving
dependencies):

```sh
dart format lib test
flutter analyze --no-pub
flutter test --no-pub test/routing/app_router_test.dart
```

The routing widget test checks the preserved Home, inherited color scheme, root
back stack, and preservation of the router and current location across an app
rebuild. It also unmounts the app to exercise router cleanup. `flutter test --no-pub`
additionally verifies startup, forms, accessibility, photo handling and responsive
screenshots. Screenshot artifacts are generated in ignored `build/ui-verification/`.
