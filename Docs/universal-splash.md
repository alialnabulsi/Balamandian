# Universal animated entry

Implemented on the existing `feature/auth-session-lifecycle` branch, with changes
left uncommitted. No new branch, commits, merges, pushes, application-data reset,
backend changes, new dependencies or encryption changes were made.

## Why the animation could be skipped

Session restoration previously selected Home as soon as `/me` succeeded. The
held `SplashScreen` inside `SessionGateScreen` could be removed before its
animation finished, or before it appeared at all. The native-overlay release
fix prevented a deadlock but did not make animation completion a prerequisite
for leaving startup. There was no persisted onboarding-completion flag.

## Entry coordination

`AppEntryViewModel` now coordinates two independent operations: the original
splash animation and session/entry-data resolution. `MainApp` creates it once
alongside the existing auth repository and router. Initialization starts the
existing session restoration and onboarding read concurrently, after Flutter
binding initialization and without blocking `runApp`.

All initial routes first display `/welcome/splash`. That route composes the same
`SplashScreen`, retaining its widget/controller while data readiness changes.
The existing controller reports actual completion through
`onAnimationCompleted`; no fixed-delay replacement is used. The splash becomes
eligible to leave only after both operations finish. Its existing curved wipe
then opens the resolved destination through `StartupFlow`.

| Entry state | Destination after the original animation |
| --- | --- |
| First launch, no completed onboarding | Existing onboarding tour |
| Returning user, no saved session | Existing Getting Started authentication entry |
| Valid saved session | Home |
| Confirmed expired/revoked session | Login with the existing notice |
| Temporary network/backend failure | Existing Retry/recovery screen, token retained |
| Entry-preference read failure | Recovery with Retry; session data is retained |

An explicit initial location used by a host/preview still passes through the
animation and existing auth guards. Normal app entry uses Home or the table
above. Fast `/me` cannot shorten the animation. When validation is slower, the
same splash stays mounted with its completed circle until bounded validation
finishes. Retry after recovery uses a small branded progress component rather
than starting a new app-entry animation.

`AuthRepository` continues to own credentials, user identity and session state.
The entry view model reads that state without duplicating it. Restoration and
`/me` deduplication, invalid-session cleanup, logout, secure-storage deadlines
and the existing StatefulShellRoute remain intact.

## Design and native handoff

The existing blue background, `assets/branding/splash_logo.png`, circle painter,
rays, title/subtitle entrances, intervals and 2,100 ms timeline are preserved.
Reduced motion retains the existing branded static illustration and 250 ms
accessible presentation. The artwork/rendering body and asset files were not
redesigned or duplicated.

`StartupFrame` extracts the original canvas, clipping and 440 dp viewport so
launch and foreground re-entry use identical layout constraints, including on
wider displays. The original startup wipe is retained.

The splash still waits for the existing native `prepare`/`reveal` acknowledgment
before starting its visible animation. Mounted-destination `NativeSplashReveal`
fallbacks remain in place. Android configuration and `MainActivity` did not
change in this task. Foreground re-entry has no native overlay, so that use of
the same splash skips only the native handshake and uses the current viewport.

## Background re-entry

`AppEntryOverlay` owns one disposed-with-the-widget `AppLifecycleListener`.
Only a documented `paused` → foreground return arms a replay. `inactive` events
alone, such as notification-shade focus loss, do not. The initial resumed event
does not arm replay, and backgrounding during the initial splash continues that
same paused animation rather than creating another one.

On genuine re-entry, the original splash overlays the retained router. Offstage,
TickerMode and focus exclusion prevent underlying rendering, interaction and
animation while keeping branch navigators, selected tab, forms and dialogs
mounted. The animation's completion removes the overlay; there is no route
replacement or forced Home navigation. Repeated lifecycle events cannot create
overlapping replays. Pausing a replay pauses the same controller.

Re-entry neither restores the session again nor calls `/me`. Existing repository
authentication failures and route guards remain authoritative. Hot reload
preserves the view model, router and current screen. Hot restart creates a new
coordinator, plays the full splash and restores the saved session once.

## Onboarding persistence

`OnboardingRepository` and `SecureOnboardingStore` persist a single non-sensitive
completion flag in `balamandian.onboarding_completed`, separate from the session
credential record. The existing platform storage dependency/configuration is
reused. Reads/writes are bounded at 10 seconds and duplicate operations share
their futures. No token, password or account data is stored in this flag.

Finishing the tour saves completion before leaving it. Write failure keeps the
tour visible with an actionable error; Get Started retries. Existing installed
accounts with a restored or expired issued session are treated as returning
users and acquire the marker. Later login/local sign-out also records this
history. Logout does not delete onboarding completion.

For an older installation that already completed the tour but has neither a
saved session nor any historical completion marker, that fact cannot be recovered
from the previous implementation. Such an installation sees the tour once;
future completion is persisted. No speculative migration or fabricated account
history is used.

## Verification

- **149 targeted tests passed**, including the existing auth, storage, routing,
  drawer, onboarding animation and tool-motion checks.
- Focused analysis reported no issues across **21 changed Dart files**; changed
  Dart files were formatted and Git whitespace checks passed.
- New regression tests cover first/returning launch, valid/expired/offline
  sessions, fast validation retaining the full animation, slow validation
  retaining one completed splash, hot reload/restart, retained navigation on
  re-entry, temporary inactive states, onboarding persistence and storage recovery.
- Platform-channel tests check the dedicated onboarding key and malformed flag;
  repository tests check deduplication, persistence across instances and retry.
- The original native acknowledgment, pixel-painted circle progression,
  background pause, reduced-motion and signup/login/OTP tests remain passing.

```sh
dart format <changed Dart files>
flutter analyze --no-pub <changed Dart files>
flutter test --no-pub test/data test/routing test/ui/auth test/ui/home test/ui/onboarding
git diff --check
```

## Samsung verification

Used the connected Samsung Galaxy A54 (`SM-A546E`) with the existing backend:

```sh
adb reverse tcp:3000 tcp:3000
flutter run --no-pub -d <device-id> --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

Performed:

- Logged-in launch and hot restart: one session read/validation; the full splash
  completion stage precedes opening Home, even with a fast `/me` response.
- Hot reload on Market: the same Market screen remains, with no new entry or
  validation stages.
- Home-button background return to the running Activity: the original partial
  circle was visually inspected, then Market returned without another `/me`.
- Notification shade expanded/collapsed: no additional foreground-splash stage.
- Logged-in cold launch in a new process: native blue stage, Flutter splash,
  then authenticated Home. Captured the launch sequence on video.
- Offline cold launch with only ADB forwarding temporarily removed: validation
  fails, the full animation completes, then recovery appears. Restoring the
  original forwarding and tapping Retry reaches Home without replaying entry.
- Drawer logout and relaunch: protected UI is removed; the next launch plays
  the animation and remains unauthenticated. The final build was installed with
  application data retained, and the user signed in directly on the phone again.

An abrupt force-stop immediately after one logout produced a reread of the
already-revoked token. `/me` rejected it and cleanup returned to Login without
exposing protected content; the following launch read no token. This observation
does not establish a new splash defect or justify changing storage encryption;
forced-termination storage durability would need a separate focused investigation.

Screenshots, videos and safe stage logs are ignored under
`build/universal-splash-device/`; test/build logs are in ignored `build/`.
No user passwords, OTPs or bearer values were requested or logged. Full signup
and OTP completion were verified with mocked contracts; no new institutional
account was created on the phone. Other OEMs, pre-Android-12 devices and release
builds remain outside this device pass.

## Files

New production files:

- `lib/data/services/onboarding_store.dart`
- `lib/data/repositories/onboarding_repository.dart`
- `lib/ui/onboarding/view_models/app_entry_view_model.dart`
- `lib/ui/onboarding/widgets/app_entry_overlay.dart`
- `lib/ui/onboarding/widgets/startup_frame.dart`
- `lib/ui/auth/widgets/session_loading_state.dart`

Updated production files: `lib/app.dart`, `lib/routing/app_router.dart`,
`lib/ui/onboarding/widgets/splash_screen.dart`, `startup_flow.dart`, and
`lib/ui/auth/widgets/session_gate_screen.dart`. The populated onboarding
view-model directory no longer needs its `.gitkeep`.

New tests: `test/ui/onboarding/universal_splash_test.dart` and
`test/data/repositories/onboarding_repository_test.dart`. Existing routing,
splash/tour and shared widget fixtures now inject onboarding storage explicitly
and wait for the real entry presentation before inspecting feature screens.

## Official documentation

- [Flutter architecture](https://docs.flutter.dev/app-architecture/guide)
- [AppLifecycleListener](https://api.flutter.dev/flutter/widgets/AppLifecycleListener-class.html)
- [Lifecycle states and inactive versus paused](https://api.flutter.dev/flutter/dart-ui/AppLifecycleState.html)
- [AnimationController](https://api.flutter.dev/flutter/animation/AnimationController-class.html), [completion status](https://api.flutter.dev/flutter/animation/AnimationStatus.html)
- [Android splash handoff](https://docs.flutter.dev/platform-integration/android/splash-screen)
- [go_router redirects](https://pub.dev/documentation/go_router/latest/topics/Redirection-topic.html)
- [Offstage](https://api.flutter.dev/flutter/widgets/Offstage-class.html), [TickerMode](https://api.flutter.dev/flutter/widgets/TickerMode-class.html)
- [Existing secure-storage package](https://pub.dev/packages/flutter_secure_storage)
