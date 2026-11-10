# Authentication session lifecycle

The [universal animated entry](universal-splash.md) now coordinates full splash
completion with restoration and persists onboarding/re-entry behavior.

The subsequent [startup regression correction](auth-startup-regression.md)
replaces the initial alternate loading view with the existing splash, fixes the
native-overlay handoff, and adds storage deadlines and restart regression tests.

Implemented on `feature/auth-session-lifecycle` after fetching origin and
fast-forward checking the clean `dev` branch. Changes remain uncommitted.

## Ownership and startup

`ApiAuthRepository` is the single source of truth for the issued token, current
`AuthUser`, session state, validation errors and sign-out notices. It extends
the existing repository contract with Flutter `ChangeNotifier`; no packages or
state-management framework were added. `SessionViewModel` exposes presentation
state and commands without copying identity. Credentials and OTP view models
now read the repository's user instead of retaining another account snapshot.

`main.dart` initializes Flutter's binding. `MainApp` constructs dependencies once,
starts restoration once in `initState`, retains one router, and disposes the
objects it owns. Injected repositories remain owned by their caller.

| State/event | Result |
| --- | --- |
| Initializing | `/session` shows branded progress; protected widgets are not built. |
| No secure record | Resume the requested public flow, including the existing splash/onboarding; protected URLs go to Login. |
| Saved record | Make one bearer-authenticated `/me` request. Local token presence/expiry metadata never authorizes UI. |
| `/me` success | Publish the returned account and expiry; open Home. No redundant token write or login-time `/me` request. |
| Confirmed `401 UNAUTHENTICATED` | Hide identity immediately, securely delete the record, go to Login with the expiration notice. |
| Network, timeout, 5xx, 403 or malformed response | Keep saved credentials, show recovery, and block protected content. Retry explicitly revalidates. |
| Secure read failure | Block content and offer retry or explicit device-only cleanup. |
| Secure delete failure | Hide identity, block routes, show a cleanup error. Retry only retries deletion. |

Restoration and logout each share their in-flight future, preventing duplicate
reads/requests. Completed startup restoration is not repeated on rebuilds.
There are no polling, refresh tokens or automatic retries. Native overlay release
is coordinated by mounted destinations, as detailed in the regression report.

## Verified backend contract

Inspected the sibling `Balamandian-API` repository without editing it:
`src/modules/auth/auth.routes.ts`, `auth.controller.ts`, `auth.middleware.ts`,
`auth.service.ts`, `auth.types.ts` and `docs/authentication.md`.

Both requests use the configured origin and `Authorization: Bearer <token>`;
neither sends a request body.

- `GET /api/v1/auth/me`: **200** with
  `{"data":{"user":{"id":"…","sisUserId":"…","institutionalEmail":"…","emailVerifiedAt":"<ISO date>"},"session":{"expiresAt":"<ISO date>"}}}`.
  It neither returns nor renews a token. `ValidatedSession` reuses `AuthUser` and
  parses the returned expiry independently of the login/OTP issued-session model.
- `POST /api/v1/auth/logout`: **204**, empty body. Revokes only the current
  database session. An already invalid/revoked/expired token returns
  **401** with `error.code: UNAUTHENTICATED` and is treated as signed out locally.
- Login remains **200** and OTP verification **201**, with the existing
  `data.user` and `data.session.{token,tokenType,expiresAt}` shape. Persistence
  still completes before authenticated state is published.

The existing HTTP implementation now handles GET and empty 204 responses while
retaining the same 30-second abortable timeout, disabled redirects, base URL
validation, JSON validation, allowlisted messages and Retry-After handling.
`AuthFailure` preserves HTTP status. A 403 remains distinct from an invalid
session, and 5xx responses never cause credential deletion.

## Secure storage and future protected requests

The original `flutter_secure_storage` configuration and single
`balamandian.application_session` record are retained. Read and delete complement
the existing save operation. Restoration does not rewrite the token. Malformed
records are treated as unusable credentials; parsing errors omit sensitive
source text. Passwords, OTPs, secrets and identity are not persisted or logged.

Future protected API operations can use `AuthRepository.withSession` as their
injected request boundary. The callback receives the current token, and its
service should attach it to this backend only and return structured `AuthFailure`
errors. This boundary handles confirmed invalid sessions centrally and rejects
late responses after the active session changes. Concurrent invalid responses
clear credentials once. Public login/registration requests bypass it, so
`SIS_INVALID_CREDENTIALS` never expires an application session. The UI calls
view-model commands; widgets do not make API requests.

## Routing and logout

The existing `StatefulShellRoute.indexedStack`, four tabs, auxiliary routes and
onboarding shell are preserved. A top-level redirect listens to repository
notifications. All shell locations require authenticated state. Public routes
remain accessible before login; authenticated users navigating to auth/startup
routes return to Home. Routing decisions never read storage or call `/me`.

The Material 3 `NavigationDrawer.footer` contains a safe-area-aware divider and
reusable `DrawerLogoutButton`. The main list scrolls independently. The button
uses the existing theme's destructive colors, rounded corners, a left logout
icon, Material press feedback, and at least a 48 dp touch target.

The shell closes the drawer and opens `LogoutDialog` with the requested title,
body, Cancel and destructive Log out actions. Confirmation starts the view-model
command; a progress barrier blocks interaction and duplicate submissions.
Confirmed server success/invalidity is followed by local cleanup. The shell is
removed, including retained tab navigation and any protected history. Once
identity is cleared, the outgoing shell paints no protected content even during
route transitions. Android Back cannot reopen it.

Failed server logout preserves the session and presents Retry, Cancel, and
explicit device-only sign-out. The message states that server sign-out could
not be confirmed. Device-only sign-out makes no revocation claim and deletes
local credentials and identity. A deletion failure redirects to recovery instead
of reporting successful cleanup. Successful login clears sign-out/expiry notices.

## Files

New application files:

- `lib/ui/auth/view_models/session_view_model.dart`
- `lib/ui/auth/widgets/session_gate_screen.dart`
- `lib/ui/auth/widgets/logout_dialog.dart`
- `lib/ui/core/ui/buttons/drawer_logout_button.dart`

Modified application files:

- `lib/main.dart`, `lib/app.dart`, `lib/routing/app_router.dart`
- `lib/data/repositories/auth_repository.dart`, `api_auth_repository.dart`
- `lib/data/services/auth_api_service.dart`, `session_credential_store.dart`
- `lib/domain/models/auth_session.dart`, `auth_failure.dart`
- `lib/ui/auth/view_models/credentials_view_model.dart`, `otp_view_model.dart`
- `lib/ui/auth/widgets/credentials_screen.dart`
- `lib/ui/home/widgets/app_shell.dart`
- `lib/ui/core/ui/navigation/app_account_drawer.dart`
- `lib/ui/core/themes/shell_tokens.dart`

New tests: `test/data/repositories/session_lifecycle_test.dart`,
`test/data/services/session_api_service_test.dart`,
`test/routing/session_routing_test.dart`, `test/ui/home/drawer_logout_test.dart`.
Existing secure-storage, router, shell and onboarding fixtures/tests were updated
to supply explicit session dependencies. `README.md` and `Docs/home-shell.md`
link to this report.

## Validation

Focused verification uses mocked HTTP and an in-memory secure-store fake, plus
platform-channel tests for the real storage adapter. Coverage includes startup,
authoritative identity, login/OTP, invalid sessions, all recovery paths,
deduplication, late responses, routing guards, logout/Back, signing into a new
account, and footer accessibility/scrolling at 390×844, 320×640 with doubled text,
and 640×320 in both themes. Light/dark stress-test drawer PNGs were rendered and
visually inspected under ignored `build/ui-verification/auth-session/`.

Results: all 125 targeted tests passed; focused analysis reported no issues
across 30 changed Dart files; all changed Dart files were formatted; Git's
whitespace check passed. The routing tests also exercise a pushed protected
route and expiration while a confirmation dialog is open.

Commands used (with the installed SDK binaries where not on PATH):

```sh
dart format <changed Dart files>
flutter analyze --no-pub <changed Dart files>
flutter test --no-pub test/data test/routing test/ui/auth test/ui/home test/ui/onboarding/splash_test.dart test/ui/onboarding/tour_test.dart
git diff --check
```

## Manual Android checks

Start the existing API on port 3000, connect the phone, then run:

```sh
adb reverse tcp:3000 tcp:3000
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

1. On a fresh installation, confirm the existing splash/onboarding and public
   login/signup/OTP flows. Log in and check the drawer email and SIS ID.
2. Force-stop and relaunch without clearing app data. Confirm a single `/me`
   request, direct Home restoration and matching account identity.
3. Force-stop, make the API unreachable, and relaunch. Confirm recovery with no
   Home or Login flicker. Restore connectivity and tap Retry; check Home opens.
4. Repeat offline startup and select Sign out on this device. Confirm Login
   and no automatic restoration on another launch.
5. With the app stopped, revoke or expire only the test session using your
   existing backend test/admin workflow. Relaunch; confirm the expiration
   notice and Login, then verify successful login still works.
6. Visit several tabs and an auxiliary screen, open the drawer, cancel logout,
   then confirm it. Check one logout request, Login, and Android Back never
   reopening protected UI. Relaunch to confirm the token was removed.
7. Disconnect the API while logged in and confirm logout. Verify the explicit
   revocation warning, Retry, Cancel, and device-only sign-out. Reconnect and
   repeat with successful server logout.
8. Check the drawer with large text, landscape, gesture navigation and both
   themes. Scroll its menu and verify Log out remains above the safe area.

No backend defect requiring changes was found. No backend code, dependencies,
encryption settings, database schema, guest behavior or deferred product features
were changed. Verification is mocked/widget based; a live Android/backend session
has not been exercised in this task. Expiration is confirmed by startup `/me` or
a future protected request; there is no background polling or refresh mechanism.
Native app-link configuration remains outside this task.

## Official documentation consulted

- [Flutter architecture and repository-owned session state](https://docs.flutter.dev/app-architecture/guide)
- [Authenticated requests](https://docs.flutter.dev/cookbook/networking/authenticated-requests)
- [go_router](https://pub.dev/packages/go_router), [redirects](https://pub.dev/documentation/go_router/latest/topics/Redirection-topic.html), [router lifecycle and notifications](https://pub.dev/documentation/go_router/latest/go_router/GoRouter-class.html)
- [Secure storage](https://pub.dev/packages/flutter_secure_storage)
- [Abortable HTTP requests](https://pub.dev/documentation/http/latest/http/AbortableRequest-class.html)
- [ChangeNotifier](https://api.flutter.dev/flutter/foundation/ChangeNotifier-class.html), [Material dialogs](https://api.flutter.dev/flutter/material/showDialog.html), [NavigationDrawer](https://api.flutter.dev/flutter/material/NavigationDrawer-class.html)
- [Dart asynchronous programming](https://dart.dev/libraries/async/async-await), [formatting](https://dart.dev/tools/dart-format), [mocking dependencies](https://docs.flutter.dev/cookbook/testing/unit/mocking)
