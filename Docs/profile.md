# Profile and social identity implementation

`feature/profile` starts at the local integrated Flutter `dev` commit `92382dd`;
the compatible backend starts at `7cec8b6`. Both include marketplace. Work is
uncommitted and unpushed. SIS-API was inspected as a read-only reference.

## Architecture and screens

The existing `View → ViewModel → Repository → Service → Balamandian-API`
architecture remains. No state-management, routing or dependency-injection
framework was added. `ProfileApiService` uses the existing API origin policy and
`AuthRepository.withSession`; it never communicates with SIS directly.
`ApiProfileRepository` is the current-user identity source, owns bounded
session-scoped profile/avatar memory caches and coalesces owner reads. Auth
changes clear identity and caches, and generation checks reject obsolete results.
Recoverable profile errors do not invalidate valid authentication credentials.

`MainApp` composes profile dependencies and starts one owner load after
authentication. Normal Profile tab selection uses retained state rather than
calling SIS or refetching the whole profile. `CurrentIdentityViewModel` publishes
identity changes immediately to the shell/drawer; tokens never enter widgets.
Confirmed 401 errors use the existing invalid-session flow. Logout clears profile
state, including while secure deletion is finishing.

Routes:

| Route | Screen and behavior |
| --- | --- |
| `/profile` | Own profile in the retained shell; one contextual header |
| `/profile/edit` | Pushed editor with Save and Cancel |
| `/members` | Authenticated member discovery; Home search also opens it |
| `/members/:userId` | Pushed public profile with Back |
| `/members/:userId/followers` | Searchable, paginated followers |
| `/members/:userId/following` | Searchable, paginated following |
| `/welcome/account-setup` | Existing setup screen, now connected to persistence |

All are protected by the existing router/session state. Signup sets optional
personalization only after secure session persistence succeeds. The router opens
setup after OTP; Save, Skip, toolbar Back and Android Back can finish setup.
Normal login/restoration opens the existing destinations and never requires
personalization. A restart can skip unfinished personalization because it is
optional. The existing preview/callback setup mode remains for isolated UI tests.

Feature components in `lib/ui/profile/widgets/` include `ProfileHeader`,
`ProfileIdentitySection`, `ProfileStatistics`/`ProfileStatistic`, `ProfileActions`,
`ProfileBadges`/`InstitutionalBadge`, `AccountInformationSheet`,
`ProfilePostsSection`, `ProfileShareSheet`, `ProfileEditorForm`,
`ProfileBiographyField`, `ProfileLockedIdentity`, `MemberListItem`,
`MemberSearchField` and `ProfileLoadState`. Screens compose these widgets;
presentation logic lives in profile, editor, member-list and identity ViewModels.
They use the existing theme, Inter typography, shared controls and geometry.
Existing `ProfilePhotoControl` and its image-picker ViewModel are reused and
extended for current-image display/removal. Shared `AppAvatar` supports official
initials. `MemberAvatar` accepts a token-free image loader and falls back safely.

The root Profile tab retains the shell, drawer and navigation. Pushed public
profiles/lists/editors have proper Back navigation outside the shell. The root
Profile header opens the existing account drawer; Home retains its branded
toolbar. No second global bar is stacked above the Profile header.

## Identity, privacy and persistence

`PublicUserIdentity` is the shared immutable public model: application UUID,
username, display name, avatar reference, verification and broad role badges.
`UserProfile` adds biography, real social counts and relationship state. Only the
owner endpoint supplies `AccountInformation`; public profiles/list rows never
contain SIS ID, email or detailed academic records. Public rendering cannot
recover owner-only fields from a hidden widget. Institutional roles have no app
administrative meaning. Badge detail sheets explain the source and meaning.

The account sheet distinguishes SIS-managed identity from the app-managed
username and creation date. It displays each actual program/department, campus,
admission year, verified email and real account timestamp when available, with
graceful missing values. No detailed academics appear on public profile pages.

Backend signup validates the SIS verification response and stores a selected
pending snapshot. OTP creates the UUID account, official profile, stable username
and session atomically. Legacy accounts hydrate during a successful SIS login,
or through a service-authenticated member request when a valid existing session
first loads its missing owner profile. SIS failures produce Retry without
logging the user out; normal profile reads are local. Verified application email
is never silently replaced. Old pending registrations without a snapshot require
restarting registration, preserving OTP protections.

Usernames use NFKD accent removal, lowercase ASCII name parts, punctuation and
whitespace removal, and a first.last base up to 24 characters. Invalid/non-Latin
ASCII bases use a deterministic name-hash fallback. Duplicate names receive
`2`, `3`, etc.; the database enforces case-insensitive uniqueness and concurrency.
The maximum is 30 characters and the username remains stable. Exact policy,
privacy projection, error contracts and endpoint details are documented in the
backend `docs/profile.md`.

Biography is at most 250 Unicode code points, enforced in the editor, backend and
PostgreSQL. Selecting a picture previews it locally. Cancel makes no persistence
requests. Save uses real endpoints and immediately updates profile/shared
identity state. Avatar and biography are separate operations: if the picture
saves and biography fails, the editor reports that partial success and allows
retry. This avoids claiming rollback across independent endpoints.

Avatars use a separate bounded PostgreSQL table, never ordinary profile JSON or
base64 in app_user. Explicit upload/retrieval/removal operations re-encode decoded
JPEG/PNG/WebP to metadata-free WebP, bound input to 1,000,000 bytes/4096 pixels per
side, reject unsupported/malformed/animated images and rotate the version on
replacement. The app accepts only the fixed relative avatar route and fetches
through its authenticated API service. Arbitrary external image URLs cannot
receive session headers. Avatar failures show real initials. No uploaded user
photos are committed.

Follow/unfollow persists in `user_follow` with UUID foreign keys, composite
uniqueness, a self-follow prohibition and both-direction indexes. Operations are
idempotent, rate limited and return authoritative target counts; the owner count
refreshes after success. Lists support literal search, loading/error/empty states,
20-member pages, and explicit Load more. Search is debounced and late responses
cannot replace newer queries. Disabled accounts do not appear.

Sharing opens a sheet with the actual username and copies it with feedback.
Members can paste it, including `@`, into discovery. No public URL, native share
plugin or working deep-link claim is invented. There is no Message action.

## Backend API inventory

All require the existing bearer session and `/api/v1` prefix:

```text
GET    /profile/me
PATCH  /profile/me                 JSON {biography: string}
PUT    /profile/me/avatar          Raw JPEG/PNG/WebP, approved image content type
DELETE /profile/me/avatar
GET    /users                     search, page, limit
GET    /users/:userId/profile
GET    /users/:userId/avatar       versioned reference supplied by API
GET    /users/:userId/followers    search, page, limit
GET    /users/:userId/following    search, page, limit
PUT    /users/:userId/follow
DELETE /users/:userId/follow
```

Mutations never take an owner ID. JSON uses `{data: ...}`; errors use the existing
`{error:{code,message}}` envelope. Public profile fields are id, username,
displayName, avatarPath, biography, verified, roles, postsCount, followersCount,
followingCount, isFollowing and isSelf. Only `/profile/me` adds `account`.
Member pages are `{items,page,limit,total,hasMore}`; pages start at 1, default
limit 20, max 50, ordered by username/UUID. See the backend contract for exact
owner academic fields, validation and error codes.

## Database synchronization

The existing backend runner owns `0003_user_profile.sql` and checksum tracking;
no applied migration was edited. It adds profile, avatar and follow tables and
the pending identity snapshot. Both clean installs and upgrades are supported.
No reset, schema copy or new migration framework is necessary.

After the reviewed feature is available to the other developer, each uses their
own ignored backend environment and Node 24.22.2:

```powershell
fnm env --shell powershell | Out-String | Invoke-Expression
fnm use 24.22.2
npm ci
npm run db:migrate
```

Coordinate the next migration number before integrating parallel changes. Never
rewrite an applied checksum. No new seed is needed: real identities hydrate from
verified SIS rather than fictional university data. Existing accounts, UUIDs,
sessions, favorites and ratings are preserved. Local 0003 execution on
`127.0.0.1:5433/balamandian` preserved 2 users, 11 sessions, 0 favorites and 0
ratings; repeat execution was a no-op. Hosted SIS was not touched.

## Community handoff

Consume `PublicUserIdentity` for authors, comments, notifications or other
presentations. Reuse `MemberAvatar` with a ViewModel's authenticated loader and
the existing role badges; do not reimplement usernames or SIS retrieval. Extend
the public profile DTO only after privacy review. `ProfilePostsSection` accepts
a real grid/count when community exists. The current backend returns zero and
the current UI truthfully shows no posts. No post, messaging, notification or
achievement database was added. Follow UUID relationships are ready for future
community queries.

## Verification and manual device procedure

Local commands:

```powershell
dart format lib test
flutter analyze --no-pub
flutter test --no-pub
```

Profile tests cover DTO parsing, protected request behavior, origin validation,
session generation/401 handling, caching, ViewModels, editing, shared identity,
search pagination, routing/back, signup Skip and account privacy. Light/dark
narrow renders with enlarged text are generated under ignored
`build/profile-verification/`. Existing authentication, universal splash, shell
and marketplace tests run with an injected fictional profile repository, keeping
their scope independent of profile networking. Backend tests use isolated
databases and mocked SIS/email; physical/provider behavior is not implied by
these tests.

For a USB Android phone:

1. In the backend branch, use Node 24.22.2, run `npm ci`, `npm run db:migrate`
   and `npm run dev`. Keep its existing private SIS/Resend configuration.
2. From Flutter, run `adb reverse tcp:3000 tcp:3000`, then
   `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3000`. For an emulator
   use `http://10.0.2.2:3000` instead. Local HTTP is debug-only.
3. Restore an existing saved session. Home should open normally and the drawer
   should acquire the official name/username. Open Profile; verify no second
   global toolbar, real account information, zero posts and avatar initials.
4. Edit the biography and select an ordinary supported phone photo, including
   a valid original above 1 MB; verify the prepared preview and saved result. Cancel once and confirm persisted data stays unchanged. Save, inspect
   the profile, Home header avatar and drawer, then force-stop/reopen and verify
   persistence. Test replacement/removal and an unsupported/corrupt/oversized
   photo. Verify fallback after an unavailable avatar.
5. Using two registered development members, open Discover (Profile or Home
   search), search name/username, open the other profile, follow twice and
   unfollow. Verify both counts/lists on refresh and after restart. Test list
   search/Load more when enough registered members exist. Open the other account
   sheet and confirm it contains no SIS ID, email or detailed academics.
6. Tap Share profile, copy the username, and paste into discovery. No native
   profile link is expected.
7. With an unregistered approved demo member, complete real SIS registration and
   Resend OTP manually. Setup should open after verification; test Skip/Back.
   Test Save on a second run/member. Login and restoration must open their
   normal destinations rather than forcing setup.
8. For a still-unhydrated legacy member, temporarily make SIS unavailable in
   the local test environment without changing hosted records. Verify Retry and
   a valid retained session; restore connectivity and Retry. Never remove real
   profile rows to simulate this; use an isolated local test fixture.
9. Switch light/dark theme, larger accessibility text and narrow/landscape
   layouts. Exercise Android Back, pull-to-refresh, logout, login as the other
   account, shell tab retention, marketplace favorites/ratings and splash.

Real SIS/Resend delivery, physical photo picking and clipboard behavior still
need manual device/provider verification. Native profile links and community
posts are deferred. Profile lists use stable offset pagination, so concurrent
membership changes may shift pages. Offline persistence and real-time social
updates are not introduced; Retry and pull-to-refresh handle recovery.

Verification on 2026-11-20: the full Flutter suite passed 265 tests. A final cache
regression was then added and all 10 focused profile/ViewModel/cache tests passed
after the cache fix. `flutter analyze --no-pub` reported no issues, Dart formatting
and `git diff --check` passed, and an Android debug APK compiled successfully.
The backend passed 39 unit/HTTP tests and 40 isolated integration tests (including
parent scenarios); typechecking, ESLint and Prettier checks passed. The final
upgrade test also preserved nonempty fictional marketplace favorites/ratings.
Light/dark narrow renders were inspected. No physical-device/provider result is
claimed by these automated checks.

Suggested commits (not created):

- Flutter: `feat(profile): add university profiles and social identity experience`
- Backend: `feat(profile): persist SIS identities, avatars and follow relationships`

Official documentation consulted before implementation:
[Flutter architecture](https://docs.flutter.dev/app-architecture/guide),
[image behavior](https://api.flutter.dev/flutter/widgets/Image/Image.network.html),
[bottom sheets](https://api.flutter.dev/flutter/material/showModalBottomSheet.html),
[post-frame scheduling](https://api.flutter.dev/flutter/scheduler/SchedulerBinding/addPostFrameCallback.html),
[clipboard](https://api.flutter.dev/flutter/services/Clipboard/setData.html),
[testing](https://docs.flutter.dev/testing/overview) and
[Effective Dart](https://dart.dev/effective-dart/design).


## Premium profile and global visual refinement — 2026-11-20

This refinement is frontend-only on the existing feature/profile branch. It
retains MVVM, constructor injection, ChangeNotifier, the 11 existing endpoints,
session protection and the community grid integration point. No API, database,
SIS, dependency or toolchain change was needed. Existing user data was not read
for screenshots, reset, seeded or modified.

### Research and applied decisions

| Reference consulted | Decision applied |
| --- | --- |
| [Flutter architecture](https://docs.flutter.dev/app-architecture/guide) and [recommendations](https://docs.flutter.dev/app-architecture/recommendations) | Keep screens as compositions, with operation state in ViewModels and authenticated data/cache policy in the repository. |
| [Shimmer recipe](https://docs.flutter.dev/cookbook/effects/shimmer-loading) and [NN/g skeleton guidance](https://www.nngroup.com/articles/skeleton-screens/) | Represent real geometry with decorative shapes; one ShaderMask/controller per loading composition; preserve populated content during refresh. |
| [Optimistic state](https://docs.flutter.dev/app-architecture/design-patterns/optimistic-state) and [commands](https://docs.flutter.dev/app-architecture/design-patterns/command) | Evaluate optimistic following, but retain confirmed writes to preserve existing cross-profile/count consistency. Running, error and completion remain independent for each action. |
| [Implicit motion](https://docs.flutter.dev/ui/animations/implicit-animations), [Hero](https://docs.flutter.dev/ui/animations/hero-animations) and [animation widgets](https://docs.flutter.dev/ui/widgets/animation) | Use restrained entrance, avatar, number and button-label transitions. Hero was considered; the photo preview uses ordinary navigation to avoid tag collisions across retained profile surfaces. |
| [Flutter accessibility](https://docs.flutter.dev/ui/accessibility), [responsive layouts](https://docs.flutter.dev/ui/adaptive-responsive), [reduced motion](https://api.flutter.dev/flutter/widgets/MediaQuery/disableAnimationsOf.html) and [Android accessibility](https://developer.android.com/design/ui/mobile/guides/foundations/accessibility) | Keep 48px controls, switch layouts at larger text sizes, provide actionable semantics and stop decorative motion when disabled or hidden. |
| [Performance guidance](https://docs.flutter.dev/perf/best-practices) | Static repeated artwork, bounded avatar decoding, lazy member rows, request coalescing, const loading shapes and focused listeners. |
| [Discord profiles](https://support.discord.com/hc/en-us/articles/4403147417623-Custom-Profiles) | Put avatar, official name, roles and biography into a cohesive identity hierarchy; make photo selection and preview explicit. |
| [LinkedIn verification](https://www.linkedin.com/help/linkedin/answer/a1357903) | Place a verification mark beside the official name; explain roles and keep underlying institutional identifiers private. |
| [Instagram profile-card reporting](https://techcrunch.com/2024/10/15/instagrams-latest-feature-is-a-digital-business-card-for-your-profile/) | Use a compact branded sharing card with a discoverable handle. Balamandian shares its actual username; it has no configured external profile link. |
| [NN/g progress indicators](https://www.nngroup.com/articles/progress-indicators/) | Show truthful indeterminate progress for saves/uploads instead of invented percentages. |

The Mobbin catalog was reachable, but its screen library was not available through
the research reader. Instagram Help and the online PopScope reference could not
be read reliably. No gated-screen inspection is claimed. PopScope behavior was
checked against the installed official Flutter source. Relevant image_picker
documentation and installed Android resizing/EXIF code were also inspected.
Implementation uses installed Flutter 3.47.5 / Dart 3.13.4 APIs.

The initial pasted attachment contained the brief without device screenshot files.
Existing generated narrow profile renders supplied that baseline. The subsequently
approved reference drives the final flat layout documented below. The
before screen had wrapping stats, oversized actions, a plain editor and
text-heavy sheets. The result has compact identity composition, a distinct
blue/gold hierarchy, stationary illustrated canvas and stronger async feedback.

### Global artwork and future-feature usage

The real original image embedded as image0_2592_411 in
assets/UI Refrences/01 · Home.svg is extracted unchanged to
assets/branding/campus-pattern.jpg (360 × 778; 33,562 bytes). It includes the
original olive branches, caps, crests, books and campus illustrations. The former
approximate CustomPainter tile is removed.

MainApp installs AppBrandedBackground inside the retained entry overlay and
above the router. Scaffold backgrounds inherit transparency; app bars and
readable content surfaces use the shared theme. Repeating the natural tile
preserves its aspect ratio on narrow, wide and landscape layouts. Dark appearance
inverts the same artwork at restrained opacity. The artwork does not animate or
scroll with content.

Coverage includes Home, own/public profiles, Marketplace and place details,
editing and signup personalization, discovery, both connection tabs, session
recovery, Guide, AI, Tools, Settings and Map's existing placeholder. AccessFrame
inherits the canvas; the welcome entry also includes the original artwork below
its campus image. Native and animated splash implementations are retained.
Future full-screen maps/media can deliberately use a solid content surface.

New feature developers should:

- Compose normal Scaffold routes using the inherited theme and canvas. Do not
  add an opaque white page background.
- Use flat sections and separators for profiles. Use AppSurface when a feature
  needs a bounded readable surface; keep the illustration visible around it.
- Keep the canvas outside scrollable content. Existing feature wrappers are
  deduplicated by an inherited background scope.
- Use AppBackgroundVariant.architecture for the approved light profile language,
  or AppBackgroundVariant.card for a tiled branded compact surface; standalone widget previews can install the normal background.
- Read colorScheme/textTheme and AppTokens rather than copying feature colors.

Example:

~~~dart
Scaffold(
  appBar: AppBar(title: const Text('Feature')),
  body: SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(AppTokens.gutter),
      children: [AppSurface(child: FeatureContent())],
    ),
  ),
)
~~~

AppTokens centralizes surface/control geometry, avatar dimensions, touch targets,
the 200ms loading presentation threshold and 140/220/300ms motion conventions.
ThemeData supplies semantic surfaces, Inter type hierarchy, fields, buttons,
sheets and feedback. Existing startup and shell tokens remain for their
established responsibilities.

Shared additions under lib/ui/core/ui/ include AppSurface, AsyncActionButton,
StableActionLabel, ContentState, DelayedLoading, SkeletonGroup, SkeletonBox,
SkeletonText, SkeletonAvatar, SkeletonImage, SkeletonMemberRow and ProfileAvatar.
AppAvatar remains the single first-and-last-initial policy; ProfilePhotoControl
now uses it too.

### Screen and interaction changes

- Own/public profile: one contextual header, a flat official identity composition, subtle
  avatar frame, owner edit affordance, photo preview, verification beside the
  name, an explained inline role label, adaptive social statistics, compact actions and
  truthful zero-post state. Root shell navigation remains persistent; pushed
  profiles have Back. The original shell floating quick-action button remains at its bottom-right anchor.
- Editor: centered local/persisted photo presentation, change/remove controls,
  biography counter, locked official identity, pinned save control, keyboard
  dismissal, draft protection and an explicit discard dialog. Signup retains
  its optional Save/Skip path.
- Account sheet: bounded scroll area, safe area, close control, avatar/verified
  header and grouped account, university and academic information. Owner-only
  fields require isSelf as well as account data. Actual dates/values are used.
- Connections: swipeable Followers/Following tabs with counts/context, independent
  ViewModels, search text, pagination and scroll state. Discovery reuses the same
  lazy member-row component. Clear search appears only for a nonempty query.
- Member rows: long identity text is constrained, verification is compact, and
  Follow/Following reserves the longer label using the real font/text scaler.
  Larger accessibility text moves the action below the identity.
- Share: university crest, original artwork, public avatar/name/handle and
  verification. Copying has local running/success/error feedback. No private
  identifiers, fake QR codes, external URLs or native deep links are introduced.
- Marketplace adopts the shared skeleton primitives. Existing categories,
  favorites, ratings, navigation and content contracts are retained.

### Loading, mutations, caching and failure recovery

Initial structured content uses delayed skeletons after 200ms. Requests start
immediately, and completed content is shown immediately; the threshold delays
feedback only. Placeholders contain no invented names or counts. One semantic
announcement represents the group. Reduced-motion placeholders are static, and
hidden/offstage groups stop their controller.

Cached profiles remain visible during refresh. Member refresh preserves rows;
new searches are debounced by 300ms and reject obsolete responses. Pagination
loads independently and retries its failed page without discarding earlier rows.
Pending/error/empty states are distinct, including first-frame loading.

Follow writes remain authoritative and block conflicting requests per member.
The pending indicator stays in the affected control. Confirmed server results
update public caches; owner counts revalidate. If that count refresh fails, the
last owner data remains visible with the repository's retryable error instead of
turning a successful follow into a failed mutation.

Saving prevents duplicate writes and preserves the draft on failure. Photo
upload/removal and biography remain separate existing endpoints. After a confirmed
photo change, the local photo operation is cleared before the biography request.
A failed biography then reports partial success; Retry does not repeat the upload.
Success feedback appears after backend confirmation and updates shell identity.

The picker requests at most 1024 × 1024 at quality 82 while preserving metadata
needed for orientation. ProfilePhotoService validates supported still images
and bounds preparation memory. Valid residual oversized images are downsampled
through Flutter's codec and losslessly encoded at up to 768px, with a 384px
fallback for noisy PNGs. Preview and upload use prepared bytes. Backend format,
size and dimension validation remains in force; corrupt/animated/abnormal images
remain errors. Cancelled selection retains the prior preview; permission errors
include an actionable Android-settings message.

The repository coalesces concurrent own/public profile, avatar and identical
member-page GETs. Public/profile mutation revisions prevent an older read from
overwriting a newer confirmed mutation. Versioned avatar paths invalidate on
replacement/removal, and small surfaces bound decode width to 512 physical
pixels. Session changes clear caches/pending-request registries and reject late
responses. ViewModels clear retained lists/private owner fallbacks when the
session changes. Private profiles are not persisted outside the existing session
boundary.

### Test-only network simulation and verification

test/profile_network_support.dart injects http.MockClient into the actual
ProfileApiService/ApiProfileRepository. Its delay, offline/failure switches and
per-request completers are test-only. They are outside lib, disabled by default,
and cannot be enabled in release by a build flag.

For a new feature, inject its service's HTTP client, gate responses with a
Completer and advance widget-test virtual time. Do not add production request
delays or call pumpAndSettle while a continuous loading animation is active.
Use bounded pump calls until the controlled response completes.

Automated cases include immediate, 500ms, 1.5s, 3s and 8s responses; the 200ms
feedback threshold; cached refresh; offline/failure/recovery; service timeout;
navigation during pending loads; obsolete search results; failed follow/upload;
partial save; duplicate prevention; avatar cache invalidation; session logout
during requests; direct account switches; and stale read/mutation races.

Final validation for this refinement:

- dart format lib test completed; flutter analyze --no-pub reported no issues.
- flutter test --no-pub passed all 308 tests, including authentication/session,
  splash/re-entry, routing/shell, marketplace and profile regressions.
- Responsive tests cover 320px phones, 384px device geometry, 430px larger phones,
  landscape, long names/handles, multiple roles, large counts and text up to 2×.
- Controls tests verify stable follow-button dimensions, save locking, modal
  scrolling, tab/search retention, draft protection, permission feedback, large
  valid photo preparation, single loading semantics and reduced-motion inactivity.
- The connected phone reported 1080 × 2340 at density 450: 384 × 832 logical
  pixels, with font scale 1.15. Those dimensions drive the principal UI renders.
- Reviewed fictional-data renders: build/profile-verification/own.png,
  public.png, editor.png, followers.png, following.png, discover.png, share.png,
  account.png and dark.png. Existing narrow light/dark artifacts are also updated.
- Final Android debug APK: build/app/outputs/flutter-apk/app-debug.apk, built
  with API_BASE_URL=http://127.0.0.1:3000 for the existing USB development setup.
  Build succeeded: assembleDebug completed in 39.5 seconds.

These are widget renders and automated transport tests, not physical-device
screenshots or a measured frame-time benchmark. Native picker/provider behavior,
EXIF camera samples and clipboard interactions still deserve physical-device
review. Real-time relationships, persistent offline storage, posts and native
profile links remain deferred. No backend tests were rerun because backend code,
dependencies, migrations and data were untouched. All changes remain uncommitted
and unpushed.


## Approved flat profile direction — 2026-11-20

The user's final reference supersedes the enclosing-card composition described
in the earlier visual exploration. Current profiles have no enclosing identity
card, boxed statistics or separate posts card. The avatar sits beside the
statistics at ordinary phone/text sizes, with thin separators. Name and refined
verification follow underneath; SIS roles use a lightweight inline label with
a 48px interaction area and their existing institutional explanation.

Edit profile and Share profile have equal dimensions and matching subtle blue
tints. Discover Members is preserved as a clearly labelled header action. Public
profiles share the same hierarchy, with the existing confirmed follow action.
Large-text/narrow layouts adapt without shrinking labels. Posts remain a truthful
zero-count integration point, now drawn directly into the page with original
campus line art and the existing future grid/count API.

The original ExpandableQuickActions source is restored unchanged. Its blue
circular control is owned by AppShell at the same bottom-right position above
the navigation bar on Home, Profile, Marketplace and the other shell
destinations. It is absent from the ProfileHeader. Fan actions, route dismissal,
haptics/motion behavior and reduced motion are retained. Profile reserves 108 logical pixels of total clearance, split between an
80px protected viewport inset and 28px of trailing scroll padding.

AppBackgroundVariant.architecture is a deliberate variation of the central
AppBrandedBackground system. It uses the shared canvas plus a stationary,
faint architectural vignette and the existing olive-branch asset, with a static
fade to keep text clear. The foreground empty state uses the complete artwork.
The original campus-pattern.jpg remains the global default. Editors, public
profiles, connection/discovery screens and profile sheets use the lighter
architectural language; editor/account groups are flat sections with dividers.
A sharing card remains an intentional share artifact, rather than a screen
enclosure. Startup/splash and other features retain their existing behavior.

The new transparent assets/branding/campus-stories.png was created with the
built-in image generation tool using the approved image as style/composition
guidance and onboarding-main-campus.png as existing campus context. The reference
screenshot was never cropped, extracted, bundled or used as a production image.
See assets/branding/README.md for the complete generation prompt. The architecture
is an illustration, not a surveyed building diagram.

ProfileSkeleton now matches the unboxed avatar/social row, identity lines and
equal action row. ProfileEditorSkeleton matches the flat photo/biography editor.
The shared shimmer, presentation threshold, cached refresh behavior, mutation
states, photo processing, persistence, relationships and session boundaries
remain in place.

Visual review compared the supplied reference with phone-sized light/dark,
own/public, editor, connections and sheet renders under
build/profile-verification/. The new profile_direction_test.dart checks flat
composition, equal tinted actions, avatar/stat alignment, institutional
explanations, original FAB dimensions/position/fan behavior, loading geometry,
stationary architecture and scroll clearance. The existing slow-network,
privacy, caching and session regressions remain part of the final suite.

Final direction validation: all 312 tests passed. Flutter analysis reported no
issues; formatting and git diff --check passed. The final Android debug APK built
successfully in 37.5 seconds at build/app/outputs/flutter-apk/app-debug.apk, with
the existing USB localhost API definition. The backend, database, dependencies,
toolchain and original floating-action implementation were not changed. All
work remains uncommitted and unpushed. Physical-device picker/EXIF/clipboard
verification and frame-time benchmarking retain the limitations stated above.


### Targeted visual polish

The approved flat composition and artwork are retained. The architecture now
uses safe-area-aware framing with restrained light/dark ink, keeping the tower
visible below the toolbar. Display-name type is 22px with an 18px verification
mark; identity, biography, actions and empty-state gaps are slightly tighter.
Role details retain their 48px touch target.

On the shell profile, 80px is reserved outside the clipped scroll viewport and
28px remains as trailing scroll padding. This preserves the original floating
button's position/size while keeping the posts description out of its area.
Pushed public profiles keep their full viewport. Skeleton spacing follows the
same identity tokens.

Validation used 40 focused profile tests, with the nine geometry checks also
rerun using bundled Inter fonts. Cases include native status/navigation insets,
320/384/430px widths, landscape and text scaling through 2x. Light/dark and public
renders were reviewed under build/profile-verification/. Flutter analysis and
formatting checks passed. No full-suite run, APK rebuild, backend or database
change was part of this polishing pass. A new physical-device screenshot was
not available in the turn; the review used the existing device dimensions and
renders with simulated native insets.
