# Outdoor map UI refinement

The Map tab now opens directly into the geographic map, with a compact floating
search field, vertical controls, and a collapsed campus strip. The global header
remains on the other tabs. Production still has the original campus reference
point and no verified walking graph; destination details therefore say
“Walking directions coming soon” without offering an enabled Directions action.

No geographic assets, backend, database, indoor-navigation scope, native SDK
versions, A* algorithm, or selective building-replacement rules changed during
this refinement. All work remains uncommitted and unpushed.

## Presentation and layout

`CampusMapViewModel` owns one `CampusMapMode`: `explore`, `search`, `selected`,
`planning`, `navigating`, or `arrived`. `searching` is derived from this state.
Search remembers the preceding context, query and category. Selecting a result
closes search and the keyboard. Closing planning returns to the selected place;
closing the place returns to exploration. Campus-strip dismissal persists across
tab changes until the authenticated session is reset.

Android Back dismisses the keyboard before the contextual surface. The shell
keeps the native map mounted in its existing indexed branch. Overlay children
have stable keys, so hiding controls when a sheet expands also preserves the
sheet's controller and position.

`CampusMapFrame` measures the floating header, controls, feedback and actual
sheet height. `BottomChromeScope` supplies the measured shell-bar extent,
including its system inset. The Map scaffold does not resize its native map for
the keyboard; overlays account for the keyboard independently. Other tabs retain
their existing resize behavior.

`CampusPanel` uses `DraggableScrollableSheet` and its supplied scroll controller.
Header and content measurements determine collapsed, intermediate and expanded
stops. Accessible expand/collapse and close actions complement dragging. Planner
actions stay outside the scrolling form, above the bottom navigation and Create
button. Short viewports can scroll the action area as needed. Enlarged text grows
the header and content rather than relying on one screenshot's dimensions.

Only explicit selection/route-preview requests and existing GPS/simulation
follow behavior frame geography. Selection waits until the keyboard has closed
and the new overlays have been laid out. Requests carry revisions and are
discarded after dismissal, a new context, or manual interaction. Layout changes
update camera-padding values and legal-ornament positions without issuing a
camera movement. Ordinary selection preserves zoom, pitch and bearing; fitting
a route preserves bearing and pitch. Native camera commands cancel the preceding
animation; reduced motion uses immediate camera/sheet changes.

Regular destinations use navy pins, selection uses a larger gold pin, and device
position remains a separate circle with accuracy indication. The campus point
is described as an overview reference, not an entrance. Category filters appear
only during search when the catalog has multiple actual categories.

Local search exposes loading, empty and failure snapshots without a production
delay. Late edits cannot reopen closed search. Route generations invalidate
pending calculations; repeated location requests share an acquisition. Location
and map errors appear in contextual feedback, with a separate measured strip
keeping Mapbox branding and attribution clear of both feedback and sheets.

## Physical-device verification

Tested on the connected Samsung Galaxy A54 (SM A546E), Android 17/API 37:

| Measurement | Observed value |
| --- | --- |
| Physical display | 1080 × 2340 pixels |
| Android density | 450 dpi; no density override |
| Flutter logical viewport | 384 × 832 |
| Flutter device-pixel ratio | 2.8125 |
| Android font scale / Flutter scale at 16 | 1.15 |
| Map body top safe inset | 33.78 logical pixels |
| Map body bottom safe inset with tabs | 0; the shell bar handles the bottom inset |

The enlarged-text capture uses a 2× Flutter text-scaler override on this physical
device. Android font/display preferences were left unchanged. Widget tests also
cover 320 × 640 at 2×, 640 × 320 landscape, and light/dark themes.

The native UI integration entry uses the production map screen, real Mapbox
renderer and existing bottom-bar component. Other tabs in that harness are a
retention placeholder. Actual application-shell retention and header behavior
are separately covered by shell widget tests. Denied/unavailable location states
use an injected service; the harness does not alter Android consent or accounts.
The isolated London fixture is explicitly labeled DEMO and supplies route tests.

The following are Android display captures, including the native map, Flutter UI,
keyboard/status/system UI and Mapbox legal ornaments. They are not mockups or SDK
map-only snapshots. The files are in the ignored build directory.

| State | Capture |
| --- | --- |
| Initial collapsed campus strip | [Explore](../build/map-refinement/device-final/01-explore-collapsed.png) |
| Expanded campus information | [Expanded campus](../build/map-refinement/device-final/02-campus-expanded.png) |
| Campus strip dismissed | [Dismissed](../build/map-refinement/device-final/03-explore-dismissed.png) |
| Search with actual keyboard | [Keyboard](../build/map-refinement/device-final/04-search-keyboard.png) |
| Search results | [Results](../build/map-refinement/device-final/05-search-results.png) |
| Empty results | [No results](../build/map-refinement/device-final/06-search-empty.png) |
| Production destination / unavailable walking routes | [Destination](../build/map-refinement/device-final/07-destination-unavailable.png) |
| Campus reset in 3D | [Reset](../build/map-refinement/device-final/08-reset-3d.png) |
| Permission-denied feedback | [Denied](../build/map-refinement/device-final/09-location-denied.png) |
| Position-unavailable feedback | [Unavailable](../build/map-refinement/device-final/10-location-unavailable.png) |
| Enlarged text and insets | [2× text](../build/map-refinement/device-final/11-enlarged-text.png) |
| Available planner, isolated fixture | [Planner](../build/map-refinement/device-final/12-fixture-planner.png) |
| Calculated fixture route | [Route preview](../build/map-refinement/device-final/13-fixture-route-preview.png) |
| Expanded planner with pinned action and legal strip | [Expanded planner](../build/map-refinement/device-final/15-fixture-planner-expanded.png) |
| Paused fixture simulation | [Simulation](../build/map-refinement/device-final/14-fixture-simulation.png) |
| Native finger pan retained after a tab round trip | [Native pan](../build/map-refinement/device-final/16-native-pan-retained.png) |
| Destination selected after closing the native keyboard | [Selection](../build/map-refinement/device-final/17-native-keyboard-selection.png) |
| Open, readable native attribution/legal dialog | [Attribution dialog](../build/map-refinement/device-final/18-attribution-dialog.png) |

Device assertions verified keyboard-first Back, search clearing/cancellation,
selection/dismissal, unavailable production directions, 2D/3D switching, campus
reset, preservation of camera zoom/bearing/center through passive changes and a
tab round trip, retention of the native map element, sheet dragging/expansion,
expanded-content scrolling, the pinned simulation action, and navigation focus
hiding/restoring bottom tabs. Camera retention used an explicit native camera
pose as its starting state. The normal app is rebuilt and restored after the
dedicated test entry; no saved authentication data is cleared.

A second native check used Android input events to drag the real map at zoom
17.2 in 2D, verified follow cancellation and camera retention across tabs, selected
a production result with the keyboard open, and opened the native attribution
dialog. The display capture and Android UI hierarchy confirmed the Mapbox and
OpenStreetMap credits and privacy/legal entries. No link or telemetry setting was
changed. The host checks the foreground package before input or screenshots.

The separate native rendering regression passed marker hit-testing/taps,
selective clipping, 2D/3D replacement rendering, terrain, route rendering,
simulation progress and sourced production-campus rendering. Its map-only
snapshots remain under `build/campus-map-verification/device/`.

## Checks and reproduction

The final normal-entry Android debug APK is
`build/app/outputs/flutter-apk/app-debug.apk` (**186,893,942 bytes**, arm64).
SHA-256: `9D4E91811FEF09A05D2F57067A6EF5286824B02F526417C931B0C081F6D8F5FC`.
It was reinstalled successfully with app data retained. Account/onboarding state
was not changed. This APK supersedes the earlier foundation report's build.

All **85** focused map, shell, domain, dataset and location tests passed. Flutter
analysis reported no issues. Formatting checks and `git diff --check` passed.
Native UI and native rendering regression tests both passed on the Galaxy.
Detailed logs are under `build/map-refinement-*.log`.

```powershell
flutter test --no-pub test/ui/map test/ui/home/home_shell_test.dart test/domain/services test/data/services/campus_dataset_service_test.dart test/data/services/campus_location_service_test.dart
flutter analyze --no-pub
```

To reproduce the native UI captures with an ignored public Mapbox-token file:

```powershell
./tool/verify_campus_map_ui.ps1 -Flutter '<path-to-flutter.bat>' -Adb '<path-to-adb.exe>'
# Native drag, keyboard selection and the attribution dialog:
./tool/verify_campus_map_ui.ps1 -Flutter '<path-to-flutter.bat>' -Adb '<path-to-adb.exe>' -Interactions
```

The helper captures the Android display at named integration-test stages and
writes screenshots/metrics to `build/map-refinement/device/`. It then rebuilds
`lib/main.dart` and reinstalls the normal APK without clearing app data. Pass
`-SkipRestore` only when intentionally keeping the integration entry installed.
Raw build logs stay ignored because Gradle can echo runtime defines.
Keep the device available during the run. The interaction target explicitly
enables real device pointer events in Flutter's test binding, which otherwise
drops Android input events. It resets that option before test cleanup.

Native regression command:

```powershell
flutter drive --no-pub --driver=test_driver/campus_map.dart --target=integration_test/campus_map_test.dart -d RZCW807CGEW --dart-define-from-file=config/mapbox.local.json
```

## Limits and remaining manual checks

Production walking routes, individual building entrances and verified
accessibility still require the real campus datasets. No paths, distances,
times or accessibility claims were fabricated. Fixture distances describe only
the synthetic London network.

Real on-campus GPS acquisition, permission-system dialogs, disabled-service
recovery and walking/deviation/arrival trials still require field testing.
Permission outcomes were injected in this pass. TalkBack navigation, iOS,
tablet layouts and exhaustive offline/network-failure transitions were not
tested on physical hardware. The test's 2× override is not an OS font-setting
change. Native rendering can occlude a route behind a pitched 3D building; the
existing GIS validation requirements remain applicable.

The existing upstream Mapbox/AGP Kotlin compatibility warning and Android graphics
diagnostics remain; both native scenarios rendered and completed successfully.
This refinement does not change the previously documented build workaround.

## Official documentation consulted

- [Flutter architecture](https://docs.flutter.dev/app-architecture/guide)
- [DraggableScrollableSheet](https://api.flutter.dev/flutter/widgets/DraggableScrollableSheet-class.html)
- [DraggableScrollableController](https://api.flutter.dev/flutter/widgets/DraggableScrollableController-class.html)
- [PopScope](https://api.flutter.dev/flutter/widgets/PopScope-class.html)
- [Keyboard view insets](https://api.flutter.dev/flutter/widgets/MediaQueryData/viewInsets.html)
- [Flutter integration testing](https://docs.flutter.dev/testing/integration-tests)
- [Device input in tests](https://api.flutter.dev/flutter/flutter_test/TestWidgetsFlutterBinding/shouldPropagateDevicePointerEvents.html)
- [Mapbox camera](https://docs.mapbox.com/flutter/maps/guides/camera-and-animation/camera/)
- [Mapbox animations](https://docs.mapbox.com/flutter/maps/guides/camera-and-animation/animations/)
