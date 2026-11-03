# Focused onboarding and authentication refinement

Completed 2026-11-03 against the final refinement brief. The existing feature,
components, assets, MVVM boundaries and GoRouter structure were retained. All
changes are uncommitted on `dev`; backend repositories and Home are untouched.

## Changes and design decisions

### Native and Flutter splash

The initial white surface came from `flutter_native_splash.yaml` and generated
Android resources. Native launch and normal-window backgrounds now use the same
approved blue `#0E569E` as Flutter, in both appearances and Android 12+ resources.
Android's system splash and existing crest remain intact. No system-splash
disabling, artificial native hold or production renderer override was added.

Regeneration uses the existing `flutter_native_splash` dependency. The four
`NormalTheme` window backgrounds were also set to branded blue to avoid the
original white fallback while Flutter initializes. Regenerating the native
resources later should retain/reapply this normal-window background setting.

The Flutter splash retains its crest coin, rays, wordmark, subtitle and hierarchy.
The bottom olive/signature/quote and linear loading indicator were removed.
`SplashLoadingLogo` adds a 3 px yellow circular stroke, separated from the crest
by 10 logical pixels. Its 156 px bounds contain the original 132 px crest.

The splash owns one 2100 ms controller. `Canvas.drawArc` starts at `-π/2` and
increases its positive sweep to `2π`, drawing clockwise from the top. The stroke
is a foreground painter so the existing coin shadow cannot dull its yellow.
Only painting updates each frame; the crest retains its existing animation.

Controller completion requests navigation exactly once, guarded against disposal,
pending navigation and repeated notifications. Reduced motion shows the completed
outline immediately and uses a 250 ms startup delay. There is no independent timer
that could advance before the stroke finishes. Controllers are disposed normally.

Startup still defaults to campus onboarding on every launch. `MainApp.afterSplash`
and the corresponding router/view input provide a small future startup-policy
boundary. `MainApp.onOnboardingCompleted` emits when an accepted tour transition
enters auth entry, including Skip. The event runs after local navigation and is
protected by the existing transition lock. No storage or completion policy is
implemented; the host can decide how to use that event later.

### Onboarding 3

The existing assistant components were refined in place. The card's minimum
height fell from 250/228 to 182/166 logical pixels at regular/compact sizes.
The mascot uses 34% of the artwork width instead of 46%, and the card is slightly
wider. Internal/footer content and excess spacing were removed; main headline,
description and form/CTA typography were not indiscriminately scaled down.

The preview now shows:

> How can I get ready for class?

> Check your schedule, review your notes, and plan your next stop.

The existing blue question bubble and crest-led response distinguish the two
speakers. The title remains Campus Assistant. “Your campus companion” and the
“Ask your campus assistant” footer are gone. This is a static illustration with
no chat behavior, typing simulation or campus-location claims.

The card tilt is gentler, the original rays and orbit are smaller and repositioned,
and the olive is reduced slightly. Decoration stays in the artwork area. The
robot no longer dominates the preview. Tool cards are aligned horizontally for
their moving track. The original illustration assets are unchanged.

Get Started is fully visible without scrolling at 412×915 with 50 px top and
24 px bottom insets, and on the Pixel 8 emulator. Narrow layouts and large text
retain scrolling so the action remains reachable.

### Tool-card loop

`AnimatedToolCards` reuses `ToolTile`, its icons, labels and colors. One 7200 ms
controller drives three 2400 ms stages. Each stage holds for 1560 ms and slides
for 840 ms with cubic easing and a 3 px hop. The centered tile scales to 1.04;
neighboring tiles scale to 0.94. Focus starts at Notes, then Schedule, then GPA.

Repeated copies of the same three static tiles enter and leave beyond a clipped
track. At one complete cycle, every visible position, scale and hop is identical
to the first frame. There is no visible teleport or page-controller reset. Cards
do not overlap; partial edge cards appear only while sliding into/out of view.

The tile children are reused across animation frames and isolated by a repaint
boundary. Height accounts for text scaling. The decorative loop is excluded from
hit testing and accessibility announcements. It stops when offscreen through
`TickerMode.valuesOf`, in the background through a lifecycle observer, and under
reduced motion. Reduced motion leaves Notes centered. Controller and observer are
disposed when the illustration is removed.

### Auth navigation and color flow

Auth entry has no back arrow. Its former 48 px header space is retained so the
photo/crest composition does not jump upward. GoRouter replaces tour destinations;
system Back at entry exits the app instead of reopening onboarding. Login and
signup still return to entry, and setup still returns to signup.

The shared `AccessFrame` now requests a plain `AppIconButton` for all three auth
headers. Outlined background/container styling is removed, while the existing
48×48 invisible touch target, alignment, tooltip, pending behavior and callbacks
remain unchanged.

Light entry now fades the original library photo into existing pale-blue
`primaryContainer #EAF3FC`, then light canvas `#F7FAFC`. Wordmark/body/link colors
use existing dark text, blue and success-green roles. The olive uses blue at 10%
opacity. Login is blue with white text, matching the light login/signup/setup CTA
role. Dark entry retains navy `#031D32`, the original yellow login button and
green signup link. That yellow remains an intentional high-contrast brand accent.
There is no global button recoloring. Onboarding 1/2 retain yellow/green CTAs.

Entry status icons remain light over the photo. The Android navigation-bar icon
brightness now follows the lower canvas: dark icons for light entry and light
icons for dark entry. Other screen palette values are unchanged.

## Verification

- `dart format lib test`: completed.
- `flutter analyze --no-pub`: **no issues**.
- `flutter test --no-pub`: **53 passed**. Relevant additions cover actual rendered
  quarter/half/full clockwise stroke pixels, completion-driven splash navigation
  exactly once, tool focus order and loop seam, offscreen/reduced-motion pause,
  completion intent, entry Back behavior, unboxed auth controls, theme variants
  and the safe-inset primary viewport.
- The existing visual suite captured all eight screens at 412×915 light/dark and
  360×800 light. All eight also passed 320×640, 2× text, safe-inset and applicable
  keyboard-inset checks, with reachable primary actions and no reported overflow.
- New light/dark campus and community PNGs are **byte-identical** to the saved
  pre-refinement renders. Those approved screens were not redesigned.
- All **26 original handoff assets** still match their SHA-256 manifest.
- Android debug builds passed with cached dependencies. Final emulator build:
  `android/gradlew.bat --offline --console=plain -q -Ptarget-platform=android-x64 assembleDebug`.
  The x64 target was selected after the larger multi-ABI APK hit emulator storage
  limits; application platform/build configuration was not changed.
- Installed and exercised on Pixel 8, Android 16, 1080×2400 at 420 dpi. Native
  screenshots cover blue system launch, branded splash/ring, all tool focus
  states, onboarding 3, entry in both themes, and login/signup plain arrows.
- Native system Back from completed entry resumed the Android launcher, confirmed
  through the resumed activity. Widget tests also verify no return to onboarding.
- `git diff --check`: clean.

A stroke test caught the crest shadow tinting the bottom of the arc; moving the
stroke to the foreground fixed the rendered pixels. Another test boundary was
given 1 ms tolerance for floating-point controller completion. No UI duration was
lengthened to accommodate the test.

## Screenshot evidence and practical limits

Curated native evidence, generated under ignored `build/refinement-android/`:

- `native-launch.png`, `splash-progress.png`, `splash.png`
- `focus-notes.png`, `focus-schedule.png`, `focus-gpa.png`, `tool-focus-states.png`
- `assistant-light.png`, `assistant-dark.png`
- `entry-light.png`, `entry-dark.png`
- `login.png`, `signup.png`
- `startup-sequence.png`, `startup-software-sequence.png`, `review.png`

The startup frame sequences show matching blue native/Flutter surfaces without a
white frame in the captured app launch. The OS controls the native crest's
placement; the later branded composition uses the approved Flutter layout.
Frame sampling cannot exclude every subframe on every device.

The emulator's default GPU path dropped parts of the animated splash even while
the app advanced correctly. A diagnostic software-rendered Android launch showed
the complete crest, wordmark and clockwise outline, and was used for reliable
motion/geometry captures. These are temporary runtime flags, not production app
configuration. Default-GPU fidelity and frame pacing require a physical-device
check; software-emulator timing is not evidence of hardware smoothness. No exact
pixel equivalence or physical-device performance claim is made.

Both themes, narrow layouts and keyboard constraints were verified with widget
tests. Physical-device TalkBack, OEM keyboards and iOS builds were not verified.
The existing future auth/profile callbacks remain UI-only; no repositories,
services, HTTP calls, sessions, SIS/OTP behavior or persistence were introduced.

## Exact changed files

Modified existing files:

```text
flutter_native_splash.yaml
android/app/src/main/res/drawable/background.png
android/app/src/main/res/drawable-v21/background.png
android/app/src/main/res/values/styles.xml
android/app/src/main/res/values-night/styles.xml
android/app/src/main/res/values-v31/styles.xml
android/app/src/main/res/values-night-v31/styles.xml
lib/app.dart
lib/routing/app_router.dart
lib/ui/core/themes/startup_tokens.dart
lib/ui/onboarding/widgets/splash_screen.dart
lib/ui/onboarding/widgets/startup_flow.dart
lib/ui/onboarding/widgets/assistant_artwork.dart
lib/ui/onboarding/widgets/assistant_preview.dart
lib/ui/auth/widgets/access_frame.dart
lib/ui/auth/widgets/getting_started_screen.dart
test/ui/onboarding/tour_test.dart
test/ui/startup_test_support.dart
README.md
Docs/onboarding-auth-implementation.md
```

Created files:

```text
android/app/src/main/res/drawable-night/background.png
android/app/src/main/res/drawable-night/launch_background.xml
android/app/src/main/res/drawable-night-v21/background.png
android/app/src/main/res/drawable-night-v21/launch_background.xml
lib/ui/onboarding/widgets/splash_loading_logo.dart
lib/ui/onboarding/widgets/animated_tool_cards.dart
test/ui/onboarding/splash_test.dart
test/ui/onboarding/tool_cards_test.dart
test/ui/auth/entry_refinement_test.dart
Docs/onboarding-auth-refinement.md
```

No dependencies were added. Generated screenshots/logs/APKs are ignored build
artifacts. Working-tree scope is 20 modified and 10 new files, with no commits or
pushes and no changes to Balamandian-API or SIS-API.

## Documentation checked

- [Flutter animations](https://docs.flutter.dev/ui/animations/overview) and
  [AnimationController lifecycle](https://api.flutter.dev/flutter/animation/AnimationController-class.html).
- [Canvas.drawArc direction and angles](https://api.flutter.dev/flutter/dart-ui/Canvas/drawArc.html).
- [TickerMode.valuesOf](https://api.flutter.dev/flutter/widgets/TickerMode/valuesOf.html),
  [lifecycle observation](https://api.flutter.dev/flutter/widgets/WidgetsBindingObserver-class.html)
  and [PopScope](https://api.flutter.dev/flutter/widgets/PopScope-class.html).
- [Responsive Flutter layouts](https://docs.flutter.dev/ui/adaptive-responsive),
  [Android system splash](https://developer.android.com/develop/ui/views/launch/splash-screen)
  and [flutter_native_splash configuration](https://pub.dev/packages/flutter_native_splash).
- [Effective Dart usage](https://dart.dev/effective-dart/usage).
