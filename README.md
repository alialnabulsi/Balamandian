# Balamandian

A Flutter application, organized incrementally around Flutter's recommended
UI/Data separation and MVVM principles.

```text
lib/
  main.dart                       # Entry point: launches the app.
  app.dart                        # Root widget and MaterialApp configuration.
  ui/
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
- Introduce shared widgets or themes under `lib/ui/core/` when they are needed
  across views. Add domain models or use cases only when actual requirements
  call for them.

These future directories are intentionally absent until they contain working
code. No state-management package or implementation is needed for the current
screen.

Architecture references:

- [Flutter architecture guide](https://docs.flutter.dev/app-architecture/guide)
- [Flutter architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations)
- [Compass case study and package structure](https://docs.flutter.dev/app-architecture/case-study)

Validation commands (run from the repository root):

```sh
dart format lib
flutter analyze
flutter test
flutter build apk
```

The repository currently has no `test/` directory; `flutter test` exits with code
1 and reports `Test directory "test" not found.`
