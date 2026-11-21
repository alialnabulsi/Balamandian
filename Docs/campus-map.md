# Outdoor campus map and navigation foundation

Implemented on `feature/campus-map`, created from fetched `origin/dev` at
`c5f4337`. Work is intentionally uncommitted and unpushed. Neither backend project
is changed. Indoor navigation is deferred.

## Delivery and data boundary

The Map tab now hosts an interactive Mapbox Standard map, with local destination
search, selection, route planning, foreground navigation and route simulation.
The implementation supports adding verified geography without changing UI or
routing logic. It does **not** pretend a complete surveyed campus network is
already available.

Production currently contains one sourced University of Balamand campus reference
at longitude `35.7836648`, latitude `34.3643747`. The source is the **Al Koura
Campus** Google-map destination linked by the
[university contact page](https://www.balamand.edu.lb/ContactUs/Pages/ContactUs.aspx).
That point centers the camera and is searchable; it is not a walking entrance.
The camera envelope is provisional. There is no surveyed property boundary,
individual campus destination inventory with coordinates, custom footprint,
measured height, replacement area, verified entrance or walkable graph available
in this repository. Production routing therefore explains that paths and
entrances are needed. It never substitutes a straight line or Mapbox Directions.

The isolated London fixture is explicitly synthetic. The UI labels it throughout,
real GPS navigation is blocked on it, and release builds cannot enable it. It
allows demonstrations and tests of paths, stairs, restrictions, directed edges,
disconnections, custom extrusion, selection and simulation without inventing
campus geography. See [the fixture instructions](../assets/maps/fixtures/README.md).

## SDK and Android configuration

`mapbox_maps_flutter` is pinned to **3.35.2**. Its mobile package uses native
Mapbox Maps Android **11.35.2** (`android-ndk27`). `geolocator` resolves to
**14.1.2** for foreground GPS. The existing Flutter **3.47.5** / Dart **3.13.4**,
AGP **9.1.0**, Gradle **9.3.1**, Android minSdk **24**, compile/target **36**,
NDK **28.2.13676358**, Java bytecode **17** and debug signing are preserved.
No iOS runner is present; iOS and web are not verified deliverables.

Native compilation exposed Mapbox's known AGP-9 opt-out issue:
[`mapbox-maps-flutter#1149`](https://github.com/mapbox/mapbox-maps-flutter/issues/1149).
The package skips KGP on AGP 9 even when `android.builtInKotlin=false`. The root
Gradle file applies `org.jetbrains.kotlin.android` only to
`mapbox_maps_flutter_mobile` when that opt-out is active, before plugin
evaluation. This keeps the established toolchain and other plugins intact.
Remove the workaround after selecting and verifying a stable Mapbox version
containing the upstream fix. Flutter documents the temporary opt-out in its
[built-in Kotlin migration guide](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers).

### Public runtime token

The app reads `MAPBOX_ACCESS_TOKEN` at build time and configures `MapboxOptions`
before any map is created. Only a `pk.` token is accepted; secret tokens must
never be supplied. The public token ships in the compiled client and is not a
secret vault. Keep it out of tracked source/configuration and use a dedicated
account token with the map-reading scopes needed by your deployment.

```powershell
Copy-Item config/mapbox.example.json config/mapbox.local.json
# Set MAPBOX_ACCESS_TOKEN in that ignored JSON file to your public pk. token.
flutter run --dart-define-from-file=config/mapbox.local.json
flutter build apk --debug --dart-define-from-file=config/mapbox.local.json
```

Alternatively set a local environment variable and run:

```powershell
flutter run --dart-define="MAPBOX_ACCESS_TOKEN=$env:MAPBOX_ACCESS_TOKEN"
```

No token is needed for the dataset CLI or headless routing/widget tests. Missing
credentials show an intentional fallback and keep local catalog/route planning
available. Invalid server credentials and tile/style failures offer a map retry.
`config/*.local.json` is ignored. The connected Mapbox plugin supplied a public
token for this session's local verification; the token value is not recorded in
this report or tracked files. Stable Maven downloads did not require a secret
SDK-download token.

## Architecture and ownership

The dependency flow remains **View → ViewModel → Repository → Service**, with
pure domain services for routing, searching and progress. Constructor injection,
`ChangeNotifier`, `ListenableBuilder` and Flutter's theme system remain the state
and UI conventions. No new state-management or backend framework was introduced.

| Location | Responsibility |
| --- | --- |
| `domain/models/campus/` | WGS84 primitives, destinations, entrances, graph, routes, fixes and permission states; no Mapbox imports. |
| `domain/services/` | A*, search, edge projection, route reconstruction and navigation progress/guidance. |
| `data/services/campus_dataset_service.dart` | Shared strict GeoJSON parser used at runtime and by the CLI. |
| `data/repositories/campus_repository.dart` | Caches validated asset data; failed loads can retry. |
| `data/services/campus_location_service.dart` | Android foreground geolocation and settings bridge. |
| `data/repositories/campus_location_repository.dart` | Location access boundary consumed by the ViewModel. |
| `data/services/route_simulation_service.dart` | Independent timed playback of calculated route geometry. |
| `ui/map/view_models/` | Commands, asynchronous state, selected destination, origin/entrance preferences, tracking and navigation coordination. |
| `ui/map/mapbox/` | Native widget lifecycle, Standard configuration, sources/layers, camera and rendering adapter boundary. |
| `ui/map/widgets/` | Configurable search, categories, result rows, map controls, destination sheet, planner, navigation, feedback and panel components. |
| `tool/validate_campus.dart` | Dataset validation and weak-component report. |

`MainApp` owns the feature ViewModel and dependencies. The indexed-stack Map
branch retains its native widget/controller and camera across tab changes.
`MapWidget` owns native disposal. The surface cancels its gesture subscription,
detaches the adapter and releases the map through widget disposal. Style reloads
reinstall feature sources/layers and restore route, selection and position.
Custom-layer interactions are registered after layer installation and reattached
after reloads; native hit testing resolves catalog IDs. Gesture tests use real
monotonic event timestamps rather than Flutter tests' default zero timestamps.
Map operations are serialized and detached/disposed adapters are ignored.
Location and route state are cleared when the authenticated account leaves.

Shared building IDs and explicit entrance nodes provide the future outdoor/indoor
connection boundary. Multiple geometry sections already share a building ID.
Indoor floor geometry, transitions, floor costs, positioning, interior models and
indoor UI are deliberately absent. They can extend the graph/cost policy later;
there is no assumption that geometric line crossings imply connectivity.
The current parser intentionally validates outdoor, nondegenerate edges. Indoor
floor metadata and zero-horizontal-distance transitions will need their own
validation rules and positive transition penalties; the heap search/cost-policy
boundary already supports that future extension.

## Interface and interactions

Explore mode preserves the shell top bar and bottom tabs. Its quick-action fan
is hidden on Map so it cannot overlap controls. The map is an opaque surface,
covering the global illustration. Panels use the existing palette, typography,
surfaces, 48dp controls, async button, feedback and skeleton components.

The compact search field supports local name/code/category/alias lookup, clear,
cancel, no-results feedback, stable ordering and category chips. Result rows and
map destination dots select catalog records; custom building taps resolve their
linked destination. Selection animates the camera and highlights custom sections.
The information panel displays only supplied code/category/description/image.
No hours, university photos or institutional claims are invented.

The control group provides a bearing-aware north reset, campus overview,
current-location recenter and 2D/3D pitch toggle. Standard's day/night preset
follows app brightness. Zoom is constrained to 14–21, pitch to 0–65 degrees;
the initial view uses zoom 15.6 and pitch 45. Viewport padding reserves room for
search, controls and the current panel. Mapbox's logo and attribution stay
enabled and are moved above the panel into visible map space.

Planning offers a manual starting entrance, current GPS, start/destination swap,
entrance selection, long-press path origins, avoid-stairs preference, distance,
estimated duration, real navigation and route simulation. The route uses a white
casing, branded blue line and distinct start/destination markers. Camera fitting
includes the full route. Controls and sheets scroll on small/landscape screens.

Active navigation temporarily hides shell bars, shows the upcoming geometric
maneuver, remaining distance/time, progress, recenter and End action. Android
back ends navigation before leaving the Map branch. Arrival shows an explicit
completion state; exit restores shell controls. Navigation offers text guidance;
spoken instructions and commercial navigation SDK features are not included.

The interaction design adapts the search → place → route preview → start sequence
from [Google Maps](https://support.google.com/maps/answer/3273406?co=GENIE.Platform%3DAndroid&hl=en),
and entrance/step awareness and walking preferences from
[Apple Maps](https://support.apple.com/guide/iphone/get-walking-directions-iph8eae299d1/27/ios/27).
Mapbox's [pedestrian map design discussion](https://www.mapbox.com/blog/mapbox-core-styles-redesigns)
informed path/entrance hierarchy. These are design influences, not claims of
matching their navigation accuracy or coverage.

## Selective building replacement

Standard remains the basemap; there is no global building-hide configuration.
Validated, explicitly approved replacement masks form a separate source. A typed
`ClipLayer` uses `clipLayerScope: ['basemap']` with `clipLayerTypes: ['model']`.
Custom `FillExtrusionLayer` definitions are in the `middle` slot, with data-driven
top/base heights and terrain alignment. The `basemap` scope protects application
extrusions/routes/markers from clipping. Only building groups with approved
replacement masks enter the custom rendering source.

The [official clip specification](https://docs.mapbox.com/style-spec/reference/layers/#clip)
allows **model** and **symbol** as additional types. `building` and
`fill-extrusion` must not be inserted in that array. We include instanced models
for trees in a replacement region, and preserve symbols to avoid removing useful
neighboring labels. Clip is intended for 3D content; arbitrary 2D basemap fills
and labels are not assumed to disappear. A whole intersecting 3D feature may be
affected: draw masks against complete old footprints and inspect neighbors.

The [official landmark replacement example](https://docs.mapbox.com/mapbox-gl-js/example/clip-layer-building/)
provides the clipping pattern; installed Flutter/native APIs were checked rather
than copying JavaScript method names. `CampusStyleData` keeps source activation
inspectable in tests. Native verification compares unclipped, clipped, replacement,
2D, terrain and route snapshots; its actual results are recorded below.

Known limits: Standard's imported layers are not individually exposed for generic
mutation. Procedural buildings, legacy extrusions, trees, labels and 2D footprints
must be reviewed per region/style revision. No verified campus building exists
to approve a production mask against. If a particular building or 2D footprint
does not clip, keep its mask unapproved and its custom group inactive; investigate
a local style/tileset replacement for that region. Never hide all buildings as a
fallback. No detailed 3D model pipeline is implemented; stable building IDs and
separate geometry groups allow that rendering extension later.

Terrain top/base alignment is requested in metres above ground. It does not turn
a height attribute into elevation above sea level. Draped lines can render below
symbols/3D content irrespective of slot; Standard rendering order and terrain
occlusion require device inspection. A route through an unverified footprint is
not fixed by drawing it on top: correct the GIS network. See
[Mapbox layer ordering](https://docs.mapbox.com/flutter/maps/guides/styles/work-with-layers/).

## Routing algorithm and correctness

A* uses a binary min-heap with deterministic node/edge tie ordering and lazy
discarding of stale heap entries. Traversal cost is summed geometry length plus
an extensible **nonnegative**, finite policy penalty. Restricted edges are always
excluded, one-way arcs are explicit, and avoid-stairs excludes `type: stairs`.
Verified-access policy additionally excludes unknown/inaccessible edges.

The heuristic is spherical great-circle distance. It is scaled by the minimum
edge-length/node-distance ratio (capped at 1) to preserve admissibility even
within endpoint digitization tolerance. Nonnegative extra penalties preserve
that lower bound. Dijkstra mode sets the heuristic to zero. Reconstruction
retains oriented edge coordinate sequences and entrance identity; route distance
comes from selected geometry, and weighted cost selects among entrances.

Duration assumes **1.25 m/s (4.5 km/h)**. It is an estimate, not measured campus
travel time; terrain, crowds, waiting, mobility and stair speeds are not modeled.
The default objective is shortest distance, not fastest or universally accessible
travel. The graph is static at the bundled revision and must be maintained.

GPS/map origins project onto eligible edge segments. Manual picks require a path
within 5 m, GPS picks within 8 m and reported accuracy no worse than 25 m. These
are conservative noise tolerances, not permission to cross walls. No lateral
connector is drawn or traversed. The temporary start has only legal directed
suffix/prefix arcs; disconnected/invalid origins and entrances produce actionable
errors. Near-equal parallel paths remain an ambiguity requiring field review.

The all-pairs fixture tests compare A* and Dijkstra across normal, avoid-stairs
and verified-access policies. Tests also check geometry/length validation,
directed reconstruction, disconnected networks, unsafe snapping, search, location
states, off-route cooldown, simulation and UI transitions. These establish
algorithmic behavior on test data, not real campus connectivity.

## Foreground location, progress and simulation

Only coarse/fine foreground permissions are declared. Permission is requested
after a user location action; exploration and manual routing do not request it.
Denied, permanent denial, disabled services, acquisition timeout and stream errors
have distinct feedback/settings actions. Approximate fixes can display their
reported accuracy while unsafe route matching is rejected.

Location streams use a 3 m displacement filter. Acquisition has a bounded wait;
tracking is cancelled when the map is hidden or the app is not resumed, and
resumes without automatically reopening permission prompts. No background service
or permission is requested. The map displays the provider's position/accuracy;
navigation camera follow uses heading when supplied. The native puck is not
enabled as a second independent location subscriber. No location history is
stored or sent to Balamandian-API.

Progress rejects stale/out-of-order/poor fixes and implausible forward jumps.
Arrival requires proximity to the route end and useful accuracy. Off-route
detection requires three spaced samples beyond `max(18m, 1.5 × accuracy)`, with a
15-second reroute cooldown. Rerouting uses the same custom graph and safety
checks. Failure retains the route with an explanation instead of inventing a
connection. Thresholds need campus walking/GPS trials and are not claims of
commercial turn-by-turn accuracy.

Simulation uses a separate provider and an elapsed-time clock over actual route
geometry. It feeds the same progress/guidance controller, moves the camera,
supports pause/resume and 1×/2×/4× playback, pauses when hidden/backgrounded and
stops cleanly. Its label and differently colored position distinguish it from
GPS. Campus simulation requires a real calculated campus route; the supplied
synthetic network is a separate opt-in development demonstration.

Local graph routing and search require no network once assets load. Map imagery
still needs Mapbox connectivity/cache availability. No offline tile-pack workflow
is implemented or claimed. Skeletons and local async labels cover dataset/map
loading, calculation, acquisition and navigation startup without artificial
production delays. Camera/Flutter transitions honor reduced motion.

## Data handoff

The complete file/property contract, validation commands and exact ten-step
Pix4D → QGIS → WGS84 export workflow are in
[assets/maps/campus/README.md](../assets/maps/campus/README.md). Supply the approved
orthomosaic/CRS/accuracy report, surveyed campus boundary, official destination
inventory and coordinates, measured building sections, independent replacement
masks, door locations and field-verified paths/restrictions/accessibility.
Approve clipping and walk representative routes before enabling production data.

## Verification record

Final verification completed on **2026-11-21** (Asia/Beirut).

| Check | Result |
| --- | --- |
| Formatting | `dart format --output=none --set-exit-if-changed lib test tool integration_test test_driver`: 255 files checked, zero changes. |
| Static analysis | `flutter analyze --no-pub`: no issues. |
| Full regression suite | `flutter test --no-pub --concurrency=2`: **379 passed**, including auth/startup, marketplace, profiles, routing and shell. |
| Final fixture regression | Dataset, routing/progress, map widgets/ViewModels and shell: **69 passed** after the final synthetic-fixture placement update. |
| Production and fixture CLI | Both valid. Production: 1 reference destination, no routes. Fixture revision 2: 4 destinations, 4 entrances, 7 nodes, 8 edges, 2 weak components. |
| Physical Android | Native end-to-end scenario passed on Samsung SM A546E, Android 17 / API 37, device `RZCW807CGEW`. |
| Normal application APK | ARM64 debug APK built from `lib/main.dart` with production campus data and a public runtime token. |

The native scenario exercises the actual production Mapbox surface: style/source
installation, querying and tapping a destination marker, basemap-scoped clip
properties, custom extrusion, 2D/3D camera changes, DEM terrain, calculated route,
simulation progress, pause and exit, then the sourced Qalhat map. Eight native
snapshots were exported and visually reviewed. A combined device screenshot
also confirms the Mapbox logo and attribution are visible above the navigation
panel. Light/dark and constrained-layout widget renders were reviewed separately.

Observed clipping behavior: the intersecting Standard 3D building disappeared,
including portions beyond the small replacement polygon; surrounding buildings
remained. The application extrusion survived clipping, confirming scope isolation.
Basemap POI labels and ground paint remained in 2D. Trees outside the replacement
region remained. Removal of every native building/model variant and trees inside
surveyed campus masks is **not** established by this single fixture.

Terrain loaded and rendered the custom geometry without a style/API error.
London's low relief does not establish correct alignment for every steep campus
footprint. Ground-draped route lines can be occluded by pitched buildings; the
synthetic fixture was adjusted to place its start/end outside basemap roofs and
its library entrance outside its custom footprint. The line and simulated fix
are visible in the final demonstration, while a short segment can still pass
behind the pitched extrusion. This is a rendering/GIS review requirement, not a
reason to globally hide buildings or draw a false elevated walking connection.

No real-campus walking, GPS deviation, wheelchair-accessibility, closure or
entrance-availability trial has been performed. Permission-state handling and
foreground suspension are verified with platform/service fakes. Exploration and
simulation on the physical device did not request GPS. Field GPS validation,
per-building clipping approval and the missing verified geographic data remain
the production-release blockers. Full offline tiles, iOS and web are unverified.

APK: `build/app/outputs/flutter-apk/app-debug.apk`, **186,868,306 bytes**.
SHA-256: `8F316189486C8B4C16241E19B3E8B1A3C947711C34EE6AECB2F56AF79F44354C`.
This is the existing development-signing configuration, intended for local Android
testing. The normal app is restored on the test device after the dedicated test
target; stored authentication data is preserved.

Reproducible final APK command:

```powershell
flutter build apk --debug --target=lib/main.dart --target-platform=android-arm64 --dart-define-from-file=config/mapbox.local.json
```

Reproducible native test command:

```powershell
flutter drive --driver=test_driver/campus_map.dart --target=integration_test/campus_map_test.dart -d RZCW807CGEW --dart-define-from-file=config/mapbox.local.json
```

The test entry bypasses authentication only inside the dedicated integration
target, leaves saved sessions unchanged, and releases the existing native splash.
Its host driver exports native map snapshots into the ignored
`build/campus-map-verification/device/` directory. The normal APK uses `lib/main.dart`.

Suggested commit message after review:

`feat(map): add campus Mapbox rendering and outdoor routing foundation`

## Official references consulted

- [Flutter MVVM architecture](https://docs.flutter.dev/app-architecture/guide)
  and [recommendations](https://docs.flutter.dev/app-architecture/recommendations).
- [Flutter lifecycle listener](https://api.flutter.dev/flutter/widgets/AppLifecycleListener-class.html)
  and [integration testing](https://docs.flutter.dev/testing/integration-tests).
- [Dart streams](https://dart.dev/libraries/async/using-streams).
- [Mapbox Flutter installation](https://docs.mapbox.com/flutter/maps/guides/install/),
  [camera](https://docs.mapbox.com/flutter/maps/guides/camera-and-animation/camera/),
  [animations](https://docs.mapbox.com/flutter/maps/guides/camera-and-animation/animations/),
  [location](https://docs.mapbox.com/flutter/maps/guides/user-location/),
  [Standard styles](https://docs.mapbox.com/map-styles/guides/standard-styles/),
  [layers](https://docs.mapbox.com/style-spec/reference/layers/) and
  [selected package](https://pub.dev/packages/mapbox_maps_flutter/versions/3.35.2).
- [Geolocator publisher documentation](https://pub.dev/packages/geolocator)
  and [Android contextual/approximate location](https://developer.android.com/develop/sensors-and-location/location/permissions/runtime).

Some legacy Flutter clip/terrain example URLs were unavailable. The current
official style specification, Mapbox's official replacement example and the
installed 3.35.2 source/API declarations were used for compatibility checks.
