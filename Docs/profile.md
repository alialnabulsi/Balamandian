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
4. Edit the biography and select a supported image under 1 MB/4096 pixels per
   side. Cancel once and confirm persisted data stays unchanged. Save, inspect
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
