# Balamandian

A Flutter application, organized incrementally around Flutter's recommended
UI/Data separation and MVVM principles.

```text
lib/
  main.dart                       # Entry point: launches the app.
  app.dart                        # Root widget and MaterialApp configuration.
  routing/
    app_router.dart               # Application route table and router factory.
  ui/
    core/
      themes/
        app_theme.dart            # Shared application theme.
    home/
      widgets/
        home_screen.dart          # Existing starter screen.
```

The starter screen is static, so it currently needs only a view. Add components
when real behavior requires them:

- Keep feature screens and their widgets in `lib/ui/<feature>/widgets/`.
- Put presentation logic and UI state in
  `lib/ui/<feature>/view_models/`, with a view model for each view that needs one.
  Views render state and forward user actions to their view models.
- Put sources of truth for application data in `lib/data/repositories/` and
  external data access in `lib/data/services/`. View models consume repositories;
  widgets should not access services directly. Data components can be shared
  across features, so organize them by type rather than by UI feature.
- Keep shared themes in `lib/ui/core/themes/`. Introduce shared widgets under
  `lib/ui/core/` when they are needed across views. Add domain models or use cases
  only when actual requirements call for them.

Additional directories are intentionally absent until they contain working
code. No state-management package or implementation is needed for the current
screen.

Navigation uses Flutter's recommended `go_router` package with
`MaterialApp.router`. The route table lives in `lib/routing/app_router.dart`;
the only registered destination is `/`, which displays the existing home screen.
`MainApp` owns one router for its widget lifecycle, retains it across rebuilds,
and disposes it when removed. `main.dart` remains only an entry point, and the
existing application theme is still applied at the app root.

Add real destinations to the route table when their features exist. Widgets
can use go_router's context navigation methods for simple navigation. Keep
session and authorization decisions out of feature widgets; introduce router
redirects or guards that consume the actual application state once authentication
and screen access policies are specified. Client routing will not replace
server-side authorization.

Authentication redirects, session refresh behavior, roles and access rules,
post-login destinations, tab shells, nested navigators, and state restoration
are deferred until their requirements exist. Native app-link configuration is
also deferred; adopting a declarative router alone does not configure it.
Unmatched locations currently use go_router's built-in error handling; a custom
not-found experience awaits an approved design. No placeholder routes, access
policies, navigation wrappers, or route code generation are included.

Navigation references:

- [Flutter navigation and routing](https://docs.flutter.dev/ui/navigation)
- [Flutter architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations)
- [go_router configuration](https://pub.dev/documentation/go_router/latest/topics/Configuration-topic.html)
- [go_router redirection](https://pub.dev/documentation/go_router/latest/topics/Redirection-topic.html)
- [MaterialApp.router](https://api.flutter.dev/flutter/material/MaterialApp/MaterialApp.router.html)

The application theme is defined once in `lib/ui/core/themes/app_theme.dart`
and applied by `MaterialApp` in `lib/app.dart`. It uses `ThemeData.light()`,
preserving Flutter's existing Material 3 colors, typography, and component
defaults. The starter screen inherits its styling without local overrides.

No approved in-app palette, typography specification, component styles, or
dark-mode requirements were found in this repository. Launcher and splash
branding define assets and white backgrounds for those native surfaces; they
do not establish an in-app palette. The current theme is a technical baseline,
not an approved Balamandian visual design.

As design specifications become available, configure the theme's `colorScheme`
and `textTheme` centrally. Use `ColorScheme.fromSeed` if the approved design calls
for a generated palette, or supply the specified color roles directly. Add
component themes for approved shared styles when those components are used.
Custom widgets should read semantic values from `Theme.of(context).colorScheme`
and `Theme.of(context).textTheme`. Standard Material widgets already inherit
the app theme. Dark-theme support and theme switching await product requirements.

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

Lightweight validation commands (run from the repository root after resolving
dependencies):

```sh
dart format lib test
flutter analyze --no-pub
flutter test --no-pub test/routing/app_router_test.dart
```

The routing widget test checks startup, the inherited color scheme, the root
back stack, and preservation of the router and current location across an app
rebuild. It also unmounts the app to exercise router cleanup.
