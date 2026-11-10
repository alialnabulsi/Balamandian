# Authentication startup regression

Corrected on the existing `feature/auth-session-lifecycle` branch. All earlier
uncommitted session work is preserved. No commits, resets, merges, pushes,
application-data clearing, backend changes or API-contract changes were used.

## Confirmed cause

`MainApp.initState` previously registered a single post-frame callback which
read `router.routeInformationProvider.value.uri.path`. It released Android's
native overlay only if this was different from `/welcome/splash`.

During initial go_router parsing, that provider can still hold the initial
`/welcome/splash` URI even though the authentication redirect selects `/session`.
The callback therefore skipped `NativeSplashHandoff.reveal` and never ran again.
`SessionGateScreen` originally rendered a separate loading design without the
existing splash's native prepare/reveal handshake. When validation finished,
Home or recovery could be correctly selected underneath an unreleased native
overlay. `MainActivity` intentionally retains its Android 12+ splash view until
Flutter calls `reveal`, so it could remain visible indefinitely.

Two regression tests were added before production changes. Both failed with
no `reveal` calls: saved-token startup with a pending `/me`, and an immediately
successful saved-token validation. The earlier 125 tests checked Flutter routes
and storage behavior but did not assert Android overlay release on these paths.

Fresh login worked because the no-token path eventually built the original
`SplashScreen`, which performs the handoff itself; login then used the session
already returned by the backend. Reopening introduced a different path through
`/session`. The native overlay race explains the cold-launch obstruction.
The original affected installation had been removed before this diagnostic
session, so its exact hot-restart request state/logs could not be recovered;
we do not attribute an unobserved transport or storage failure to a specific
device defect.

## Changes

- Removed the root's one-time URI-based release decision.
- Added `NativeSplashReveal`, a presentation component that releases the overlay
  after the destination it wraps actually renders its first frame. The router
  uses it for Home/auth entry, and recovery uses it for errors.
- Session validation now composes the original `SplashScreen(hold: true)`,
  including the existing `assets/branding/splash_logo.png`, blue canvas, loading
  stroke, rays, title and subtitle. A held splash does not depend on onboarding's
  `StartupNavigation` or navigate itself. Validation success immediately opens
  Home; it never waits for the decorative animation to finish.
- `MainActivity` completes a pending logo-layout reply when another destination
  releases the overlay first. This handles a route change during the existing
  native/Flutter handoff without a fallback delay or a new native splash design.
- Added explicit 10-second read/delete deadlines around secure-storage I/O;
  HTTP retains its existing 30-second abortable timeout. A pending storage read
  was otherwise unbounded. This is defensive recovery, not evidence that a
  keystore hang caused the reported incident. Transient/read failures retain
  tokens and expose Retry or explicit local sign-out.
- Restoration checks its generation after asynchronous work, before either
  success or failure updates state. Logout/new login/disposal supersede old
  startup results. Local sign-out no longer waits for obsolete validation.
- A timed-out storage deletion remains shared until the underlying mutation
  actually completes; retry cannot start competing deletions. Identity stays
  hidden and protected routes blocked until cleanup is confirmed.
- Minimal debug-only `[session]` stages identify secure-read start, token
  presence, validation start/completion/failure, and enum state changes. They
  never contain token values, passwords, OTPs, user identity, keys or raw errors.

The repository remains the session source of truth. `SessionViewModel` forwards
state and actions. `MainApp` still owns one router and starts restoration once
per application initialization. Hot reload retains these objects; hot restart
and cold launch create new objects and read the existing secure record. No
onboarding-persistence mechanism existed or was added.

## Startup sequence

1. Initialize Flutter's binding and call `runApp` immediately.
2. Construct the shared repository and router, start one secure read.
3. Render the existing Flutter splash while credentials are unvalidated. The
   native handoff depends on actual mounted views, not the initial router URI.
4. No token: preserve the original splash/onboarding/auth-entry behavior.
5. Saved token: validate once through `GET /api/v1/auth/me` with bearer auth.
6. Success: publish the returned identity and expiry, then let the existing
   router guard open Home immediately.
7. Confirmed `401 UNAUTHENTICATED`: securely clear the token and show Login with
   the expiration notice. Network/5xx/response failures preserve the token and
   show visible recovery; Retry explicitly validates again.

No refresh tokens, validation bypass, polling, artificial startup delay,
hardcoded navigation workaround, encryption changes or forced re-login were
introduced.

## Regression coverage and checks

`test/routing/session_startup_regression_test.dart` uses the real secure-storage
adapter with a mocked platform channel whose record survives fresh repository
and router instances. It covers login, reassembly/hot reload, simulated Dart
restart, cold launch, logout then relaunch, native overlay release for delayed
and immediate validation, and timeout followed by successful Retry.

`test/data/repositories/session_lifecycle_test.dart` adds unresolved secure reads,
safe deletion timeouts/retry, and late successful/401 startup responses after
logout and a new login. Existing tests still cover invalid sessions, response
parsing/expiry, SIS credential failures, registration/OTP, route protection,
request deduplication, drawer logout and Back behavior.

Results: **133 targeted tests passed**. The Android debug build succeeded and
was installed on the connected Samsung with the required loopback API origin.
All 33 changed Dart files were formatted; focused analysis and Git whitespace
checks passed.
The test log is ignored at `build/auth-startup-regression-tests.log`.

## Device verification

Device: Samsung Galaxy A54 (`SM-A546E`). The user signed in directly on the
phone; no institutional credentials or token values were requested or read.

```sh
adb reverse tcp:3000 tcp:3000
flutter run --no-pub -d <device-id> --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

- No saved record: existing onboarding opened, and the user completed login.
- Lowercase `r`: Home stayed open; no additional restoration/validation stage.
- Uppercase `R`: secure read → token present → one `/me` → authenticated Home.
- Cold launch: detached the Flutter CLI, force-stopped only this package and
  relaunched its Activity. A new Android process read the same token and
  validated once to Home; the native overlay did not remain on screen.
- Offline cold launch: temporarily removed only the existing ADB reverse mapping
  and relaunched. Validation failed into the visible connection-recovery screen,
  with Retry and explicit local sign-out; the native splash was removed.
- Reconnection: restored `tcp:3000` forwarding and tapped Retry using its
  accessibility bounds. The same saved token was still present; exactly one
  new validation completed and Home opened without another login. The phone was
  left online and signed in, with the original forwarding restored.

Screenshots and safe stage logs are ignored under `build/auth-startup-device/`.
Actual device checks cover the connected Samsung and debug Impeller/Vulkan build.
Secure-storage stalls, true HTTP timeout, invalid/revoked tokens, logout/relaunch
and deliberately reordered responses were exercised with focused fakes/platform
channel tests, not by corrupting or revoking the user's live session. Release,
pre-Android-12 and other OEM behavior still need their normal device coverage.

## Files changed in this correction

- `lib/app.dart`
- `lib/routing/app_router.dart`
- `lib/ui/onboarding/widgets/native_splash_reveal.dart` (new)
- `lib/ui/onboarding/widgets/splash_screen.dart`
- `lib/ui/auth/widgets/session_gate_screen.dart`
- `lib/data/repositories/api_auth_repository.dart`
- `android/app/src/main/kotlin/com/example/balamandian/MainActivity.kt`
- `test/routing/session_startup_regression_test.dart` (new)
- `test/data/repositories/session_lifecycle_test.dart`
- `test/auth_test_support.dart`
- `README.md`, `Docs/auth-session-lifecycle.md`, and this report

## Documentation consulted

- [Flutter Android splash screen and embedding](https://docs.flutter.dev/platform-integration/android/splash-screen)
- [Android splash exit behavior](https://developer.android.com/develop/ui/views/launch/splash-screen)
- [Flutter post-frame callbacks](https://api.flutter.dev/flutter/widgets/WidgetsBinding/addPostFrameCallback.html)
- [Flutter frame completion](https://api.flutter.dev/flutter/scheduler/SchedulerBinding/endOfFrame.html)
- [Flutter hot reload versus hot restart](https://docs.flutter.dev/tools/hot-reload)
- [Flutter architecture](https://docs.flutter.dev/app-architecture/guide)
- [go_router notifications and redirects](https://pub.dev/documentation/go_router/latest/go_router/GoRouter-class.html)
- [Secure storage](https://pub.dev/packages/flutter_secure_storage)
- [Dart timeout semantics, including late source completion](https://api.dart.dev/dart-async/Future/timeout.html)

The online `WidgetsBinding.reassembleApplication` API page was inaccessible;
its installed Flutter SDK implementation was inspected when writing the
hot-reload simulation. It waits for a frame, so the test starts reassembly,
pumps that frame, then awaits completion.
