# Marketplace

Implemented using the supplied light/dark marketplace, detail and filter screenshots,
and the approved [interactive reference](https://balamandian-v0-2-0.vercel.app/market).
The Figma design-context connector repeatedly failed during initialization; the user
explicitly authorized the reference and then supplied screenshots. No Figma screenshot
is an application asset, and no successful Figma retrieval is claimed.

## Screens and navigation

- `/market`: Marketplace heading, feature search/filter, horizontal active categories,
  active news/advertisements, Places and explicit pagination.
- `/market/:placeId`: back to Marketplace, cover/gallery, identity/category/favorite,
  aggregate rating, full description, optional contacts, address/directions,
  personal star rating/removal, opening hours and active place posts.

Both routes belong to the existing Market branch of
`StatefulShellRoute.indexedStack` inside `AppShell`. Place/photo/details and post
interactions push the detail route. Android back restores the retained root widget,
search and category; completion of the push quietly refreshes list/post ordering.
Switching shell tabs preserves the marketplace search and loaded state.
The same authentication redirect protects both routes.

Home, Map, Profile, startup/onboarding, drawer/logout, top bar, bottom bar, central
Create and floating Guide/AI/Tools behavior are preserved. Global top-bar Search,
Notifications and Messages retain their coming-soon responses. Body search is a
separate working marketplace control. The reference's proximity wording is replaced
with neutral Places copy and the API's actual address. No new shared-shell styling
or navigation behavior is introduced.

## Ownership and composition

```text
Widget -> ChangeNotifier ViewModel -> MarketplaceRepository
       -> MarketplaceApiService -> Balamandian-API
```

- `lib/domain/models/marketplace_*.dart`: immutable categories, summaries/details,
  images, opening intervals, posts, pages/pagination, mutation results and safe
  failures. Runtime validation checks required fields (including nullable fields),
  IDs, numbers/rating bounds, types, schedules, HTTPS links and pagination. Dates
  become UTC `DateTime`, coordinates/averages become `double`, counts/ratings stay
  integers. Collections are unmodifiable. Deliberate replacement methods preserve
  all other fields and can clear `myRating` after deletion.
- `lib/data/services/marketplace_api_service.dart`: injected `http.Client`, validated
  API origin, abortable requests, 20-second whole-request timeout (constructor maximum
  30 seconds), redirect rejection, URL/query encoding, exact HTTP 200 success and
  data/error envelopes. Only rating PUT sends JSON. Parser/network errors are safe;
  raw server messages are ignored. Positive Retry-After is bounded to 900 seconds,
  preserved on the failure and surfaced in user feedback. Mutations never retry
  automatically.
- `lib/data/repositories/marketplace_repository.dart` and
  `api_marketplace_repository.dart`: the sole marketplace boundary consumed by
  ViewModels. Every operation enters an injected generic authenticated-request
  capability. They neither read secure storage nor retain/expose tokens. The API
  service receives a token only within that callback. Unexpected errors become a
  client-owned failure; `AuthFailure` passes through unchanged.
- `lib/ui/marketplace/view_models/`: one root and one detail ViewModel expose
  immutable renderable state. They own loading/refresh/pagination, commands, pending
  operations, error/success feedback, stale-request generations and disposal.
- `lib/ui/marketplace/widgets/`: focused search, selector/chip, native filter sheet,
  heading, image/fallback, place/post cards, favorite, rating summary, star input,
  hours, location/contact, detail posts, loading/empty/error/feedback and pagination
  components. Screens compose these components with existing theme tokens,
  `AppBrandedBackground`, `FormMessage` and labeled shared icon controls.
- `lib/data/services/external_url_service.dart`: injectable platform operation,
  using official `url_launcher` and `LaunchMode.externalApplication`.

`MainApp` accepts optional marketplace repository and external URL service injection.
Its default API service owns a dedicated HTTP client; MainApp closes only that owned
service/client. An injected repository is borrowed. Screen states own and dispose
ViewModels/controllers; ViewModels cancel debounce timers and ignore late results.
The existing auth repository/router lifecycle is otherwise unchanged.

## Endpoints and sessions

`API_BASE_URL` remains the authentication origin configuration, without an `/api`
suffix. HTTPS is required except debug-only emulator/loopback HTTP, using the same
policy as authentication. The marketplace base path is `/api/marketplace`.

| Method | Relative path | Input |
| --- | --- | --- |
| GET | `/categories` | No query |
| GET | `/places` | Optional trimmed search, category slug; page 1, limit 20 by default |
| GET | `/places/:placeId` | Place UUID |
| GET | `/posts` | Optional type (`news`/`advertisement`), place UUID; page 1, limit 20 |
| PUT | `/places/:placeId/favorite` | No body |
| DELETE | `/places/:placeId/favorite` | No body |
| PUT | `/places/:placeId/rating` | JSON `{ "rating": 1..5 }` |
| DELETE | `/places/:placeId/rating` | No body |

All reads and writes use `AuthRepository.withSession`. A backend
`401 UNAUTHENTICATED` becomes the existing `AuthFailure`; `ApiAuthRepository` removes
local credentials and its notifications activate the existing route guard. Widgets
and ViewModels never receive bearer tokens. Automated tests use fictional sessions,
mock HTTP and fake repositories; none contacts SIS or Resend.

## Interaction and state

Search trims input, debounces for 350 ms, cancels old debounce work and ignores
responses superseded by a newer search/filter. Clear is one labeled action. Search
and category changes reset place pagination; pull-to-refresh retains both values.
Categories come from the backend, with an All places option. Controlled Material
icons support coffee, restaurant and books, with storefront for future keys. The
filter control opens a native root-navigator bottom sheet with the same category
choices; Show places applies the selection.

The backend owns category/place/post order, favorite priority, exact rating ordering
and active-post scheduling. Cards distinguish NEWS from ADVERTISEMENT, hide the
section when there are no posts, and link to their place. More posts and places
append in backend order without duplicate IDs. Separate loading/refresh/load-more
states and explicit pagination end states remain visible. Errors during refresh
retain confirmed successful data; retry is user initiated.

Favorite and rating controls wait for a confirmed response and prevent duplicate
commands while pending. Favorites update from the returned boolean and refresh
place/post ordering. Ratings replace aggregate/count/myRating directly from the
mutation result; removal sets `myRating` to null. Failed writes retain the confirmed
state. A late detail refresh cannot overwrite a confirmed mutation. Safe feedback
uses semantic live regions. No comments or written reviews exist.

Each star has a labeled 48-dp target. No-ratings summaries say Not rated yet.
Opening hours use localized weekday labels through `intl` and display backend
`HH:mm` intervals in the supplied timezone. Missing days are Closed, split intervals
remain separate, and overnight intervals say next day. No open-now calculation
exists. The current application's supported locale remains English; future app
localizations must initialize their normal intl locale data.

## Images and external links

Images prioritize the database URL. Post images fall back to their place cover
when absent. A pending network image shows a local accessible placeholder; errors
fall back locally. Null URLs immediately use the local asset mapping. Local raster
first frames also show the generic image while decoding. No image-caching package,
base64 Dart images or temporary Figma URLs are used.

| Place slug | Local image |
| --- | --- |
| `the-olive-coffee-house` | `assets/marketplace/images/coffee.jpg` |
| `the-garden-table` | `assets/marketplace/images/food.jpg` |
| `paper-and-ink` | `assets/marketplace/images/books.jpg` |
| Any other slug | `assets/marketplace/images/generic.svg` |

The three photographs were downloaded unchanged from the corresponding `/assets/`
paths on the approved Vercel reference. The generic storefront SVG was authored
locally as a neutral fallback. All are declared via the marketplace image directory
in `pubspec.yaml` and used through `MarketplaceImage`/`MarketplaceLocalImage`.

Directions prefer `googleMapsUrl`; otherwise paired coordinates produce a Google
Maps search URL. An address without either remains non-interactive. No geocoding
occurs. Optional HTTPS website/social links and `tel:` phone actions use the same
injected external-launch service. Rejected/failed launches receive safe feedback.
The plugin is invoked directly rather than probing `canLaunchUrl` or custom-tab
support, so its documented Android package-visibility queries are unnecessary.
No Android configuration, SDK or Gradle/Kotlin version was changed.

Dependencies: `url_launcher ^6.3.3` for external actions and the already resolved
`intl 0.20.3` promoted to a direct dependency for localized weekday labels. No
existing package/toolchain version was upgraded.

## Testing and verification

Tests mirror models, service, repository, root/detail ViewModels, widgets and
routing. `test/marketplace_test_support.dart` supplies fictional data and injectable
fake marketplace/external services. Every pre-existing MainApp harness now injects
a fake marketplace dependency and performs no new network requests.

Coverage includes exact response parsing, nullable fields, malformed data, paths,
query encoding, auth headers, empty mutation bodies, rating JSON, status/network
failures, Retry-After, real auth-repository invalidation, debounce/stale responses,
category changes, pagination/deduplication, duplicate command prevention, confirmed
mutations, failure recovery and disposal. Widget tests exercise independent global
and body search, native filters, navigation/back/tab retention, loading/empty/error
states, favorites, stars/removal, directions availability/failure, local/network
image fallback, semantics, tap targets and layout.

Commands used (from repository root):

```text
flutter pub get
dart format <changed Dart files>
flutter analyze --no-pub
flutter test --no-pub test/domain/models/marketplace_models_test.dart
flutter test --no-pub test/data/services/marketplace_api_service_test.dart
flutter test --no-pub test/data/repositories/api_marketplace_repository_test.dart
flutter test --no-pub test/ui/marketplace/view_models
flutter test --no-pub test/ui/marketplace/widgets/marketplace_screen_test.dart
flutter test --no-pub test/routing/marketplace_routing_test.dart
flutter test --no-pub test/ui/marketplace/marketplace_visual_test.dart
flutter test --no-pub
flutter build apk --debug --no-pub --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

Visual tests render root/detail and lower rating sections in light/dark at 390x844,
320x640, 844x390 landscape and 320x640 with 2x text. They check overflow, labeled
controls and Android tap targets. Native screenshots are inspected under ignored
`build/ui-verification/marketplace/`; photo loading is awaited before captures.
The original shell's responsive behavior and semantic labels remain unchanged.
Final verification on the installed Flutter 3.47.5 / Dart 3.13.4 toolchain:

| Check | Result |
| --- | --- |
| `flutter pub get` | Passed; existing package versions preserved. |
| `dart format lib test` | Passed; final pass formatted 151 files with zero changes. |
| `flutter analyze --no-pub` | Passed with no issues. |
| Focused models | 9 passed. |
| Focused HTTP service | 13 passed. |
| Focused repository | 3 passed. |
| Focused ViewModels | 14 passed. |
| Focused widgets | 8 passed. |
| Focused routing | 3 passed. |
| Focused visual/layout/accessibility | 16 passed. |
| Complete `flutter test --no-pub` | 251 passed. |
| Debug APK command above | Passed. |
| Asset declaration/call-site/JPEG/SVG checks and APK asset inventory | Passed. |
| Final formatting, analyzer and changed-file whitespace checks | Passed. |

The first Android build encountered a Java PKIX certificate-chain error while
fetching the plugin's Kotlin artifacts from Maven Central. This JBR has no direct
Windows-ROOT provider. For verification only, the already trusted Windows public
root certificates were exported to an ignored JKS file in `build/`, and that file
was selected through command-scoped Java options with certificate verification
still enabled. No certificates were installed and no persistent system/project
trust or toolchain configuration was changed. The APK built successfully after
dependency resolution, and the ordinary exact build command was checked again
with the cached dependencies. Temporary diagnostics remain in ignored `build/`.

The APK is `build/app/outputs/flutter-apk/app-debug.apk`; its packaged assets include
all three marketplace photographs and the generic SVG. The temporary truststore
is not packaged in the APK. This is a debug build using the existing development
signing configuration. No live authenticated backend/device test was run.

## Deferred work

Administration, uploads, object storage, comments/written reviews, open-now logic,
offline storage/cache, automatic retries and map-provider integration are deferred.
The backend/schema/migrations and the attached migration README were not changed.
No commit or push is part of this work.

## Official references consulted

- [Flutter architecture](https://docs.flutter.dev/app-architecture/guide),
  [ListenableBuilder](https://api.flutter.dev/flutter/widgets/ListenableBuilder-class.html)
  and [RefreshIndicator](https://api.flutter.dev/flutter/material/RefreshIndicator-class.html).
- [Dart JSON validation patterns](https://dart.dev/language/patterns).
- [http AbortableRequest](https://pub.dev/documentation/http/latest/http/AbortableRequest-class.html).
- [StatefulShellRoute](https://pub.dev/documentation/go_router/latest/go_router/StatefulShellRoute-class.html).
- [Flutter accessibility](https://docs.flutter.dev/ui/accessibility) and
  [widget testing](https://docs.flutter.dev/cookbook/testing/widget/introduction).
- [Official url_launcher plugin](https://pub.dev/packages/url_launcher), including
  externalApplication and Android query requirements for capability probing.
- [intl DateFormat](https://pub.dev/documentation/intl/latest/intl/DateFormat-class.html).
- [Flutter Android builds](https://docs.flutter.dev/deployment/android).

## Change inventory

Created:

```text
Docs/marketplace.md
assets/marketplace/README.md
assets/marketplace/images/books.jpg
assets/marketplace/images/coffee.jpg
assets/marketplace/images/food.jpg
assets/marketplace/images/generic.svg
lib/data/repositories/api_marketplace_repository.dart
lib/data/repositories/marketplace_repository.dart
lib/data/services/external_url_service.dart
lib/data/services/marketplace_api_service.dart
lib/domain/models/marketplace_category.dart
lib/domain/models/marketplace_failure.dart
lib/domain/models/marketplace_favorite_result.dart
lib/domain/models/marketplace_json.dart
lib/domain/models/marketplace_models.dart
lib/domain/models/marketplace_opening_hour.dart
lib/domain/models/marketplace_page.dart
lib/domain/models/marketplace_place_detail.dart
lib/domain/models/marketplace_place_image.dart
lib/domain/models/marketplace_place_summary.dart
lib/domain/models/marketplace_post.dart
lib/domain/models/marketplace_rating_result.dart
lib/ui/marketplace/view_models/marketplace_feedback.dart
lib/ui/marketplace/view_models/marketplace_view_model.dart
lib/ui/marketplace/view_models/place_detail_view_model.dart
lib/ui/marketplace/widgets/marketplace_category_chip.dart
lib/ui/marketplace/widgets/marketplace_category_selector.dart
lib/ui/marketplace/widgets/marketplace_contact_actions.dart
lib/ui/marketplace/widgets/marketplace_cover_gallery.dart
lib/ui/marketplace/widgets/marketplace_detail_posts.dart
lib/ui/marketplace/widgets/marketplace_empty_state.dart
lib/ui/marketplace/widgets/marketplace_error_state.dart
lib/ui/marketplace/widgets/marketplace_favorite_button.dart
lib/ui/marketplace/widgets/marketplace_feedback.dart
lib/ui/marketplace/widgets/marketplace_filter_sheet.dart
lib/ui/marketplace/widgets/marketplace_heading.dart
lib/ui/marketplace/widgets/marketplace_image.dart
lib/ui/marketplace/widgets/marketplace_load_more.dart
lib/ui/marketplace/widgets/marketplace_loading_state.dart
lib/ui/marketplace/widgets/marketplace_location_section.dart
lib/ui/marketplace/widgets/marketplace_opening_hours.dart
lib/ui/marketplace/widgets/marketplace_place_card.dart
lib/ui/marketplace/widgets/marketplace_post_card.dart
lib/ui/marketplace/widgets/marketplace_rating_summary.dart
lib/ui/marketplace/widgets/marketplace_screen.dart
lib/ui/marketplace/widgets/marketplace_search_field.dart
lib/ui/marketplace/widgets/marketplace_star_input.dart
lib/ui/marketplace/widgets/marketplace_tokens.dart
lib/ui/marketplace/widgets/place_detail_screen.dart
test/data/repositories/api_marketplace_repository_test.dart
test/data/services/marketplace_api_service_test.dart
test/domain/models/marketplace_models_test.dart
test/marketplace_test_support.dart
test/routing/marketplace_routing_test.dart
test/ui/marketplace/marketplace_visual_test.dart
test/ui/marketplace/marketplace_widget_support.dart
test/ui/marketplace/view_models/marketplace_view_model_test.dart
test/ui/marketplace/view_models/place_detail_view_model_test.dart
test/ui/marketplace/widgets/marketplace_screen_test.dart
```

Modified:

```text
README.md
lib/app.dart
lib/routing/app_router.dart
pubspec.lock
pubspec.yaml
test/routing/app_router_test.dart
test/routing/session_routing_test.dart
test/routing/session_startup_regression_test.dart
test/ui/home/home_shell_test.dart
test/ui/onboarding/splash_test.dart
test/ui/onboarding/tour_test.dart
test/ui/onboarding/universal_splash_test.dart
test/ui/startup_test_support.dart
```

Removed: none. Generated previews, test logs and build diagnostics remain under ignored `build/`.
