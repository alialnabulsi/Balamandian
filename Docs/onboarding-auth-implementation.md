# Onboarding and authentication UI implementation

This records the initial implementation. See the later
[focused refinement report](onboarding-auth-refinement.md) for current splash,
onboarding-3, tool animation, auth navigation and entry-theme updates.

Implemented on 2026-11-03 against the complete v1.1.0 handoff. Its source, tokens,
assets, behavior documentation and screenshots were inspected. Stylesheet order
is honored: `startup-refresh.css` overrides `onboarding.css`. This is native
Flutter UI; React is retained only in the original, previously untracked handoff.

## Screens and navigation

| Destination | Status and behavior |
| --- | --- |
| `/welcome/splash` | Implemented: blue canvas, original crest coin, rays, olive, signature and timed progress. Advances after 2350 ms, or 250 ms with reduced motion. |
| `/welcome/campus` | Implemented: exact campus photo/crop, vertical and edge fades, ambient decoration, yellow Continue. |
| `/welcome/community` | Implemented: exact fair photo and asymmetric elliptical clipping, sun, olive and green Continue. |
| `/welcome/assistant` | Implemented: native feature card, exact transparent robot, Schedule/Notes/GPA tiles and blue Get started. Illustration is descriptive and noninteractive. |
| `/welcome/getting-started` | Implemented: navy library backdrop in both themes, crest animation, yellow SIS login, green signup link and guest callback. |
| `/welcome/sign-up` | Implemented: SIS ID, password visibility, presence validation, step indicator, switch/back, host pending/error inputs and submission callback. |
| `/welcome/sign-in` | Implemented: email or SIS ID, password visibility, presence validation, switch/back, host pending/error inputs and submission callback. |
| `/welcome/account-setup` | Implemented: optional local photo and bio, display-only institutional fields, second step and submission callback. Entered only by an explicit host navigation decision. |
| `/` | Existing Home implementation preserved. It is not a submission or guest destination. |

The router starts at splash. Three tour steps support progress controls,
horizontal swipes (55 logical-pixel threshold), keyboard arrows and system Back.
Skip enters getting started; its Back returns to the last visited tour step.
Authentication Back returns to entry; setup Back returns to signup. No progress
completion or first-run choice is persisted. Native back navigation and visible
navigation controls are disabled while the host is pending or a wipe is running.

`ShellRoute` retains the transition controller while the route child changes.
`NoTransitionPage` prevents an additional default page transition. Navigation is
locked synchronously before the first animation frame. There are no session
guards, redirects or authenticated-state assumptions.

## Final Flutter structure

```text
lib/
  app.dart                         # Host composition, theme and router lifetime
  main.dart                        # Existing minimal entry point
  routing/
    app_router.dart
    startup_destination.dart
  ui/
    core/
      themes/
        app_theme.dart
        startup_tokens.dart
      ui/
        action_button.dart
        asset_icon.dart            # AssetIcon and labeled AppIconButton
        body_copy.dart
        brand.dart                 # Brand, exact crop and asset paths
        copy_entrance.dart
        crest_coin.dart
        decorative_art.dart
        form_message.dart
    onboarding/
      widgets/
        startup_flow.dart          # Navigation scope and curved wipe
        splash_screen.dart
        tour_screen.dart
        tour_artwork.dart
        tour_copy.dart
        tour_progress.dart
        assistant_artwork.dart
        assistant_preview.dart
        tool_tile.dart
      view_models/                 # Remains prepared; no empty VM was added
    auth/
      widgets/
        getting_started_screen.dart
        access_frame.dart
        access_heading.dart
        credentials_screen.dart
        auth_field.dart
        account_setup_screen.dart
        profile_photo_control.dart
        university_details_card.dart
      view_models/
        auth_ui_controller.dart
        credentials_view_model.dart
        profile_view_model.dart
    home/widgets/home_screen.dart  # Unchanged
  data/                            # Prepared directories unchanged
  domain/                          # Prepared directory unchanged
test/
  routing/app_router_test.dart
  ui/
    startup_test_support.dart
    startup_visual_test.dart
    onboarding/tour_test.dart
    auth/credentials_test.dart
    auth/profile_test.dart
assets/onboarding/
  images/                          # Six original images
  illustrations/                   # Original olive PNG and ray SVG
  icons/                           # Twelve original Phosphor SVGs + MIT license
  fonts/                           # Four Inter TTF weights + OFL license
  README.md
```

Meaningful controls, cards, art and headings are configurable widget classes.
Screens compose these widgets. Authentication presentation, validation and local
photo state use small `ChangeNotifier` models; controllers holding sensitive text
remain in their mounted form. No state-management framework was added.

## Future integration contract

Pass an `AuthUiController` to `MainApp(authUi: controller)`. The host owns and
disposes an injected controller; the app disposes its default controller. The
controller exposes these constructor callbacks and mutable presentation inputs:

| Interface | Contract |
| --- | --- |
| `onSignUp(Credentials)` | Nonempty trimmed identifier and unmodified password, once per accepted local submit. |
| `onSignIn(Credentials)` | Same contract; the UI does not verify an institutional identity. |
| `onGuest()` | Entry intent only. No guest permissions, session or Home navigation. |
| `onSetupSubmit(ProfileDraft)` | Trimmed optional bio and selected `XFile?`. No upload or saving. |
| `pending` | Host-controlled waiting state. Disables input, navigation, photo actions and submission; shows a compact progress indicator. |
| `formError` | Host-provided text shown in a semantic live region. No backend error-code mapping. |
| `identity` | Optional `UniversityIdentity(name:, major:, faculty:)`, read-only. Blank/absent values show “Provided by SIS”. |
| `MainApp.themeMode` | System by default; explicit light/dark review or host control. |
| `MainApp.initialLocation`, `holdSplash` | Initial route and static splash review, also used by tests. |

The host should set pending before starting a future async command, then supply
any resulting error/identity and clear pending. After real signup acceptance, the
host may select `/welcome/account-setup` through the existing GoRouter. After real
signin/setup acceptance it decides the application destination. Current callbacks
never select that destination themselves. Future repository/service wiring
belongs at the composition boundary, following View → ViewModel → Repository →
Service → Balamandian-API. Nothing was added to those data directories.

Passwords are cleared before dispatch, on form switch and on disposal; they are
never logged, cached, persisted or retained in a shared model. Repeat submits are
locked for the current frame. The default unconnected host reports that no
service is connected and stays on the form. It never fabricates success or an
identity. Missing guest handling emits no fabricated experience.

Photo selection uses the platform gallery picker, accepts locally decoded
JPEG/PNG/WebP up to 1,000,000 bytes, preserves the existing selection on an invalid
replacement, and supports cancellation/change/removal. Bytes remain only in
memory for the preview. Selection work guards against callbacks after disposal;
decoded frame/codec resources are disposed. The bio limit is 240 user-perceived
characters. Drafts reset when the screen is removed or the app restarts; there is
no draft persistence or recovery journey.

## Motion and lifecycle

- Coin: one 1900 ms sequence after a 100 ms delay, specified cubic easing,
  −35° → 690° → 720° Y poses, Z rotation and vertical offsets, 900 px perspective,
  3 px face depth and front/back orientation selected from the facing angle.
- Wipe: exact handoff path painted natively at 180% viewport height; rise −80%
  over 360 ms, replace route, pause 20 ms, exit to −170% over 460 ms. The native
  curve implements GSAP's `power2.inOut` cubic polynomial directly.
- Decorative artwork: original olive alpha silhouette tinted with `srcIn`,
  original ray SVG, 10/14 second sway, specified origins and placement rotations.
- Tour copy: 450 ms opacity/14 px entrance. Splash copy retains delayed entrances.
- Android disable-animations and iOS reduce-motion settings suppress decorative
  motion, coin movement and wipe; a setting change during a wipe completes it.
- Controllers and timers are disposed. Navigator ticker modes silence covered
  routes; repeated decoration is isolated with repaint boundaries. Bundled scene
  images are precached. There are no skeletons for bundled/static content.

## Assets and dependencies

All 26 supplied asset files passed SHA-256 comparison with the handoff manifest.
No replacement artwork, stock images, screenshot backgrounds or network fonts
were introduced. Both font and icon licenses are included in the asset bundle.

Direct dependencies added: `flutter_svg ^2.3.2` and `image_picker ^1.2.4`.
`go_router ^18.1.2` was already present. `pubspec.lock` records the transitive
dependencies; application source contains no network calls. Android SDK levels,
signing, native splash and application identity were not changed.

## Verification results

- `dart format lib test`: completed.
- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: **46 passed**, including the original Home/router
  lifecycle test, splash timing, tour/progress/swipe/keyboard/back navigation,
  animation tap locking, live reduced-motion changes, both forms, password
  clearing, callback-only submission, pending/errors, guest intent, photo
  selection/validation/removal/cancellation, and bio submission.
- Android debug `assembleDebug`: passed using cached dependencies with
  `android/gradlew.bat --offline --console=plain -q assembleDebug`. The initial
  online build stalled on dependency downloads and was stopped before this
  successful cached build. Latest APK: `build/app/outputs/apk/debug/app-debug.apk`.
- Installed and launched on the Pixel 8 Android 16 emulator (1080×2400, 420 dpi).
  Native tour progression, entry, sign-in, required errors, first-invalid-field
  focus and keyboard scrolling were exercised. Android runtime screenshots are
  in `build/ui-verification/android/`. No application exceptions were reported
  during that smoke check.
- Android touch-target and labeled-control accessibility guidelines pass for
  the sign-in screen; text-field semantics are checked.
- All eight screens rendered and captured at **412×915 light**, **412×915 dark**
  and **360×800 light**. All eight also passed **320×640**, **2× text scaling**
  and cutout checks, with a 280 px keyboard inset on form screens. Primary actions
  remain reachable by scrolling and no RenderFlex overflow was reported.
- Native Flutter rendering was visually inspected against the supplied
  screenshots, including all eight screens in both themes and narrow layouts.
  Photo crops/fades, original art, button variants, type hierarchy and composition
  are closely aligned. This is manual visual comparison, not a pixel-equality
  golden claim. Flutter/browser text rasterization and some line metrics differ.
- `git diff --check`: clean. All changes remain uncommitted on `dev`.

Generated screenshots: `build/ui-verification/{mobile-light,mobile-dark,narrow}/`.
Comparison contact sheets are under `build/ui-verification/*-comparison.png`.
The screenshot test regenerates the individual images; these are ignored build
artifacts, not production assets or checked-in golden baselines.

### Deliberate adaptations and remaining checks

The wordmark in the compact tour header keeps its logo proportions at large text
sizes; headings, descriptions and controls still honor system scaling. Tour
content and forms grow/scroll when height or text scaling demands it. Guest text
may wrap at large text sizes. These changes preserve normal reference layouts
and prevent inaccessible/clipped controls. Native text fields use padding that
preserves the approved 54/112 px visible control sizes.

Some default-renderer emulator captures showed a clipped control corner or an
absent progress segment. A diagnostic launch with software rendering restored the
rounded controls and full progress row in the checked scenes. This comparison is
consistent with an emulator/renderer issue; it does not establish how a physical
device's GPU will behave. No renderer flags or native renderer configuration were
changed in the production application. The software emulator also had slow
startup frames, so it is not a basis for a smoothness/frame-rate claim.

Static images and widget tests do not establish physical-device frame pacing,
TalkBack reading experience, OEM keyboard behavior or the platform gallery
picker's permission/low-memory behavior. Those remain device acceptance checks.
No release or iOS build has been verified.

OTP/email verification, password recovery and post-authentication destinations
have no supplied designs. They were not invented. Session routing, completion
persistence, SIS identity retrieval, errors from backend codes, profile uploads
and all data integration remain future work with the real application state.

## Git scope

Changed root composition/router/theme, package registration and lockfile, routing
test, README and generated-cache ignore. Added the UI components/models above,
feature tests, exact assets and this report. Removed only `.gitkeep` files from
directories now containing implementations. The original untracked handoff is
preserved. `home_screen.dart`, both backend repositories and all prepared
data/domain directories were left untouched. No commits or pushes were made.
The final working-tree summary, excluding the pre-existing untracked handoff, is
8 modified tracked files, 6 removed empty `.gitkeep` files and 63 new files (30
Dart implementation files, 5 test/support files, 27 asset/license/documentation
files and this report).

## Documentation consulted

- [Flutter architecture guide](https://docs.flutter.dev/app-architecture/guide),
  [recommendations](https://docs.flutter.dev/app-architecture/recommendations) and
  [Compass case study](https://docs.flutter.dev/app-architecture/case-study).
- [Responsive UI](https://docs.flutter.dev/ui/adaptive-responsive),
  [accessibility](https://docs.flutter.dev/ui/accessibility),
  [animations](https://docs.flutter.dev/ui/animations/overview),
  [performance](https://docs.flutter.dev/perf/best-practices) and
  [forms](https://docs.flutter.dev/cookbook/forms/validation).
- API documentation for AnimationController, MediaQuery disableAnimations,
  AccessibilityFeatures reduceMotion, SingleChildScrollView and PopScope.
- Official package documentation for
  [go_router transitions](https://pub.dev/documentation/go_router/latest/topics/Transition%20animations-topic.html),
  [flutter_svg](https://pub.dev/packages/flutter_svg) and
  [image_picker](https://pub.dev/packages/image_picker).
- [Effective Dart design](https://dart.dev/effective-dart/design).
