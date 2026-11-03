# Final UI polish and splash synchronization

Implemented on `dev`, uncommitted. This pass preserves the approved screens,
themes, button colors, routing, validation, and UI-only boundaries. No dependency,
backend, storage, session, or onboarding-persistence integration was added.

## Splash: cause and synchronization

The old splash controller started from `didChangeDependencies`. Widget readiness
does not mean Android has uncovered the Flutter surface. Both the loading stroke
and the separately animated crest could therefore advance behind the native
launch screen.

The Android 12+ handoff now uses the platform's `SplashScreen` exit listener and
a small `balamandian/splash` method channel:

1. Flutter paints a stable crest with zero stroke and hidden decorations. It
   requests `prepare` and precaches the existing native logo asset.
2. After the first Flutter frame, Android's splash-exit callback supplies the
   actual icon position in Flutter-view logical coordinates. Android retains its
   splash view while Flutter lays out the matching crest.
3. Flutter submits that matching frame, then requests `reveal`. Android removes
   its splash view on a display frame and acknowledges on the following vsync.
4. Only that acknowledgment enables the Flutter animation. Activity entrance and
   focus events are deliberately not used as evidence that the splash is gone:
   device verification demonstrated that entrance completion can precede splash
   transfer.
5. The existing 2.1-second visible timeline runs once, then uses the existing
   onboarding transition. There is no arbitrary startup-delay timer.

The platform exit listener replaces the default exit fade, so no extra fading
native copy covers the beginning of the Flutter stroke. Android's required
system splash and entrance remain enabled. On Android versions below 12, the
first Flutter UI display callback and the display-frame acknowledgment handle
the legacy launch background. A direct initial route without the branded splash
releases the native overlay from the app root after its first frame. Repeat
requests in the same Activity reuse the native handoff state.

Backgrounding and disabled `TickerMode` pause the timeline at its current value;
resuming continues it. Disposing cancels Flutter animation work and native
pending replies are cancelled on Activity destruction. Reduced motion displays
the completed illustration without entrance movement after native dismissal,
then advances after 250 ms. Mounted checks, pending-navigation checks, and the
existing navigation guard ensure advancement once.

This follows Flutter's documented Android splash handoff and Android's public
exit-listener API. The existing `flutter_native_splash` package remains a build
tool; its optional `preserve/remove` mechanism defers the first frame rather than
providing the visibility acknowledgment needed here.

References: [Flutter Android splash guide](https://docs.flutter.dev/platform-integration/android/splash-screen),
[Android splash mechanics and dimensions](https://developer.android.com/develop/ui/views/launch/splash-screen),
[flutter_native_splash](https://pub.dev/packages/flutter_native_splash),
[Flutter MethodChannel](https://api.flutter.dev/flutter/services/MethodChannel-class.html),
[Flutter frame completion](https://api.flutter.dev/flutter/scheduler/SchedulerBinding/endOfFrame.html).

## Logo and decorative entrances

Flutter now uses the exact existing `assets/branding/splash_logo.png` used by
the native splash. The rotating `CrestCoin`, gloss, shadows, and logo fade are
removed from this splash only; the authentication entry retains its approved
crest treatment. The PNG was not altered. It is newly included in Flutter's
asset bundle.

Android reports the masked icon view. Its documented 192dp mask corresponds to
the configured 288dp image canvas, so the handoff restores the transparent
padding at a factor of 1.5 around the measured center. This avoids shrinking the
crest by one third when moving into Flutter. On the Samsung capture, the native
and Flutter crest pixels both occupy `x=329..750, y=959..1380`: 422 by 422 pixels.

Both stages retain `#0E569E`. The surrounding canvas also stays blue on displays
wider than the existing 440dp content limit. The logo stays anchored to the
native center; the existing title, subtitle, type sizes and gaps sit beneath it.
This vertical adjustment is required to preserve logo continuity.

The existing rays keep their final shape, color and position. A shared
`SplashEntrance` fades them in while moving them upward by 12dp, driven by the
same gated timeline. Title and subtitle retain their subtle 14dp entrances.
The rays enter over the first 462 ms; the ring begins at 168 ms and draws from
the top clockwise over the remaining 1,932 ms. Typography enters concurrently.
The total visible splash duration remains 2,100 ms. The removed quote stays absent.

## Assistant, tool focus, and authentication

The assistant card now shows exactly:

- Student: "Where can I apply for financial aid?"
- Assistant: "You can apply online through the University's Financial Aid Application."
- An underlined, themed "Financial Aid Application" reference. Its tooltip holds
  the [official reference URL](https://www.balamand.edu.lb/FinancialAidApplication/).
  This is a static illustration with no chat action, URL-launch dependency, or
  runtime network request.

Two card gaps decrease from 12dp to 8dp to accommodate the reference. The card's
style, mascot, decorative shapes, overall screen layout, and CTA stay intact.
The complete Get Started button fits the primary phone and the connected
Samsung's smaller 384 by 832dp display, with safe areas.

The tool track changes only its focus gain: `.94 + .10 * focus` becomes
`.94 + .16 * focus`. Center scale rises from 1.04 to 1.10; side scale stays .94.
The existing height already has enough vertical clearance. Notes → Schedule →
GPA order, 7.2-second cycle, hold/slide timing, hop, icons, colors, clip viewport,
loop seam, and reduced-motion behavior remain unchanged.

Login and signup omit their requested descriptions. The shared `AccessFrame`
and `AccessHeading` accept an optional description and omit its preceding 12dp
gap when absent. Existing heading-to-form padding remains, avoiding a leftover
paragraph-sized blank area. Account setup still supplies its original copy and
is unchanged. Labels, validation, branding, progress, buttons, back arrows,
keyboard scrolling, and navigation retain their behavior. No color tokens or
button color choices changed.

## Focused verification

- `flutter analyze --no-pub`: no issues.
- Focused onboarding, credentials, entry, tool-motion, and visual tests:
  **53 passed**. A subsequent route/splash check passed **5 tests**, including
  four of those splash cases and the existing routing test: **54 distinct tests**.
- Added/updated checks cover delayed native acknowledgment, zero hidden progress,
  measured-logo placement, the complete visible duration, one navigation,
  clockwise painted pixels, background pause/resume, disposal during handoff,
  reduced motion, stronger focused zoom, loop continuity, exact new copy,
  removed descriptions, and direct-route overlay release.
- Visual tests cover 412 by 915dp light/dark, 360 by 800dp, and 320 by 640dp with
  2x text, cutouts and form keyboard insets. No Flutter overflow exceptions.
  Onboarding 1 and 2 light/dark PNG hashes are identical to the pre-refinement
  reference. Existing entry and account-setup screens are still covered.
- Android arm64 debug build: successful using the installed Flutter SDK and
  cached Gradle dependencies. No production renderer override was introduced.
- Physical device: Samsung Galaxy A54 (`SM-A546E`), Android 16 / API 36,
  1080 by 2340px at 450dpi. Cold launch and a warm Activity relaunch were captured
  using the default Impeller Vulkan renderer. Warm launch retained process
  `20896` before/after, so it was not mislabeled as another cold launch.
- Captured native crest → stable matching Flutter crest → partial/full yellow
  circle → onboarding. Logo bounds are identical across stages. Also inspected
  assistant, login and signup in both themes; verified visible Get Started,
  empty-form validation with the real keyboard, login back to entry, and signup
  entry navigation. The device's original dark-mode setting was restored.
  A direct `/welcome/sign-in` launch also displayed the form successfully,
  followed by a final normal cold-launch check of the rebuilt APK.
- `git diff --check`: clean.

Review artifacts are ignored under `build/`:

- [Physical review sheet](../build/final-polish-android/review.png)
- [Cold-launch sequence](../build/final-polish-android/cold-sequence.png)
- [Warm-launch sequence](../build/final-polish-android/warm-sequence.png)
- [Cold-launch recording](../build/final-polish-android/cold-launch.mp4)
- [Keyboard and validation](../build/final-polish-android/login-validation-keyboard.png)
- [Analysis log](../build/final-polish-analysis.txt)
- [Focused test log](../build/final-polish-tests.txt)
- [Routing/splash test log](../build/final-polish-routing-tests.txt)
- [Android build log](../build/final-polish-android-build.txt)

Limits: physical GPU verification covers this Samsung/Android version only.
Other OEMs, pre-Android-12 runtime behavior and release-mode frame performance
have not been measured. Headless Flutter screenshots and widget tests are
additional evidence, not physical-device GPU confirmation. Captures sample the
transition; exact zero-before-dismissal and exactly-once timing are also checked
by controlled acknowledgment tests. No backend or authentication request was made.

## Exact changed files

Modified production/configuration files:

1. `android/app/src/main/kotlin/com/example/balamandian/MainActivity.kt`
2. `lib/app.dart`
3. `lib/ui/onboarding/widgets/splash_screen.dart`
4. `lib/ui/onboarding/widgets/splash_loading_logo.dart`
5. `lib/ui/onboarding/widgets/startup_flow.dart`
6. `lib/ui/onboarding/widgets/assistant_preview.dart`
7. `lib/ui/onboarding/widgets/animated_tool_cards.dart`
8. `lib/ui/auth/widgets/access_frame.dart`
9. `lib/ui/auth/widgets/access_heading.dart`
10. `lib/ui/auth/widgets/credentials_screen.dart`
11. `pubspec.yaml`

New production files:

12. `lib/ui/onboarding/widgets/native_splash_handoff.dart`
13. `lib/ui/onboarding/widgets/splash_entrance.dart`

Modified tests:

14. `test/routing/app_router_test.dart`
15. `test/ui/startup_test_support.dart`
16. `test/ui/onboarding/splash_test.dart`
17. `test/ui/onboarding/tool_cards_test.dart`
18. `test/ui/onboarding/tour_test.dart`
19. `test/ui/auth/credentials_test.dart`

Documentation:

20. `README.md` (modified)
21. `Docs/onboarding-auth-final-polish.md` (new)

Git: `dev`, 18 modified tracked files plus 3 new files; all unstaged and
uncommitted. No commit or push. The starting working tree was clean, and backend
repositories were not accessed or changed.
