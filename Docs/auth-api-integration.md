# Authentication API integration

Implemented on 2026-11-03 against the sibling `Balamandian-API/docs/authentication.md`,
its controllers, validators and OTP policy. The backend contract is authoritative.

## Behavior and architecture

The dependency chain is View → ViewModel → AuthRepository → AuthApiService →
Balamandian-API. `MainApp` creates and owns the default HTTP service and injects
the repository through the router. Tests can inject a repository. The existing
`CredentialsViewModel` serves both credential screens because their form state
and submission behavior are shared; `OtpViewModel` owns the email challenge.
No state-management framework, DI container, generic repository or use-case layer
was added. API/domain shapes match, so no duplicate DTO layer was introduced.

Only these endpoints are called:

| Endpoint | Expected status | Result |
| --- | --- | --- |
| `POST /api/v1/auth/register` | 202 | Pending registration ID, expiry and resend timestamp |
| `POST /api/v1/auth/register/verify` | 201 | Verified user and newly issued bearer session |
| `POST /api/v1/auth/register/resend` | 202 | Updated challenge timestamps |
| `POST /api/v1/auth/login` | 200 | User and newly issued bearer session |

The service sends JSON, validates response shapes, uses a 30-second abortable
timeout, and disables redirects for credential requests. It maps known backend
codes to local safe messages and never shows raw upstream error text. Network,
timeout, malformed-response and secure-storage failures have distinct handling.
Positive `Retry-After` seconds are bounded to one hour. Requests are never
automatically retried.

Registration accepts SIS ID or institutional email and the unchanged SIS
password. Client validation follows the actual identifier/password constraints.
The original approved labels, themes, assets, layouts and animations are retained.
Submissions show the existing pending indicator and lock navigation/controls.
Failures retain the user's input in the current form; passwords are concealed
when submitted and cleared on success, switching forms or disposal. Passwords
are never persisted or logged.

Registration success uses the existing curved transition to the new
`/welcome/verify-email` route. Its in-memory route extra contains only the
pending ID and timestamps. Direct access without a challenge offers restarting
registration; it does not submit an invented handle.

The OTP screen composes the existing authentication frame, heading, input,
button and feedback components. Dedicated `OtpCodeField` and `OtpDeliveryStatus`
widgets provide a six-digit numeric field, leading-zero preservation, paste and
one-time-code autofill hints, keyboard submission, invalid-code focus, expiry,
resend progress and delivery feedback. The OS may not provide email-code autofill;
manual entry and paste work independently.

Countdowns use backend `otpExpiresAt` and `resendAvailableAt`, recalculated from
the current time rather than decrementing a local counter. Resend replaces the
challenge timestamps and clears the old input. Expired or attempt-locked codes
cannot be verified until resend succeeds. Invalid/replaced/window-expired handles
offer restarting. Delivery cooldown/budget errors do not prevent verification of
an otherwise valid current code. Resend errors honor `Retry-After`; the backend
remains responsible for the one-hour delivery budget. Unknown network outcomes
remain subject to backend challenge validation.

Login and successful OTP verification save the issued session before navigating
directly to the existing Home at `/`. No authentication path opens account setup.
Storage failure stays on the current screen. Because successful verification
consumes the OTP, its storage-failure recovery offers login rather than replaying
the consumed challenge.

## Session storage and configuration

Added direct dependencies: `http ^1.6.0` and `flutter_secure_storage ^11.2.0`.
`http` was previously transitive. `pubspec.lock` records plugin dependencies.

`SessionCredentialStore` exposes only `save`; `SecureSessionCredentialStore`
writes/replaces one protected record containing `token`, `tokenType: Bearer` and
`expiresAt`. Android uses the plugin's default RSA OAEP/AES-GCM protected storage.
Auto backup is disabled and the plugin's data/key preference files are explicitly
excluded from legacy backup and Android device transfer. There are no session
reads, restoration decisions, refreshes, `/me` calls or logout operations.

The API origin is set using `--dart-define=API_BASE_URL=...`:

```sh
# Emulator: default in debug mode
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000

# Physical Android phone, backend running on the development machine
adb reverse tcp:3000 tcp:3000
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3000

# Production configuration example; production signing is still separate work
flutter build apk --dart-define=API_BASE_URL=https://api.example.com
```

The URL must be an origin without a path, query, fragment or embedded credentials.
Only debug builds accept HTTP, limited to `10.0.2.2`, `127.0.0.1` or `localhost`.
Profile/release require an explicit HTTPS origin. Android Internet permission is
in the main manifest, and local cleartext rules exist only in the debug source
set. No backend secrets are embedded, and no backend networking was changed.

## Verification

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: **115 passed**. HTTP calls are mocked.
- Tests cover request/status/response contracts, pending parsing, registration
  success/failure, login, invalid SIS credentials, API outage/timeout/malformed
  data, OTP verification/resend, expiry/cooldown, duplicate submissions, secure
  writes/replacement/failure, and waiting for persistence before Home navigation.
- OTP widget checks cover keyboard/paste/focus, disabled/loading states,
  inaccessible/expired challenge recovery, both themes, Android accessibility
  guidelines, 320×640 with 2× text and a 280-pixel keyboard inset. Native Flutter
  captures were inspected in `build/ui-verification/auth/`.
- One pre-existing onboarding assertion expected combined assistant text, while
  the approved implementation already split it into two text widgets. Only the
  stale assertion was aligned with the existing copy; onboarding UI was unchanged.
- `flutter build apk --debug --no-pub --dart-define=API_BASE_URL=http://127.0.0.1:3000`:
  passed. APK: `build/app/outputs/flutter-apk/app-debug.apk`. A stalled automatic
  SDK download was interrupted; the required official Android 35 platform archive
  was installed locally before the successful build. No repository build
  configuration changes were needed for that environment repair.
- Installed and launched on the connected Samsung SM-A546E running Android 16.
  Native smoke checks covered startup/onboarding, opening login, required-field
  validation/focus, dummy credential entry, loading, and unavailable-service
  feedback through USB ADB reverse. Identifier/password input remained present
  after failure, with the password concealed. No Flutter/Android fatal or
  unhandled exceptions matched the app-process runtime log. Temporary forwarding
  and device screenshot files were removed, and the dummy form was closed.
  No real session was issued or saved during this native check.

Ignored evidence files: `build/auth-analysis.log`, `build/auth-tests.log`,
`build/auth-android-build.log`, `build/auth-android-runtime.log`, and
`build/ui-verification/auth/android/login-unavailable.png`.

Local Balamandian-API was not listening on port 3000, and no authorized SIS test
credentials were supplied. Real SIS authentication, email delivery and a real
issued session have therefore not been verified end to end. No passwords, OTPs,
tokens or keys were printed. Backend repositories were read only.

Onboarding still appears on each launch. Account setup, guest mode, session
restoration, route guards, logout, refresh, deployment and unrelated features
remain outside this integration. Existing Home implementation is unchanged.

## Files and Git

All changes remain unstaged and uncommitted on `dev`. No commit, push or deployment
was performed: **19 modified files, 21 new files and 5 removed empty placeholders**.
Five `.gitkeep` files were removed from directories now containing
implementations/tests. The file inventory below includes all source, configuration,
test and documentation changes; generated logs, captures and APKs are ignored.

### Created

```text
Docs/auth-api-integration.md
android/app/src/debug/res/xml/debug_network_security_config.xml
android/app/src/main/res/xml/backup_rules.xml
android/app/src/main/res/xml/data_extraction_rules.xml
lib/data/repositories/auth_repository.dart
lib/data/repositories/api_auth_repository.dart
lib/data/services/auth_api_service.dart
lib/data/services/session_credential_store.dart
lib/domain/models/auth_failure.dart
lib/domain/models/auth_session.dart
lib/domain/models/pending_registration.dart
lib/ui/auth/view_models/otp_view_model.dart
lib/ui/auth/widgets/otp_screen.dart
lib/ui/auth/widgets/otp_code_field.dart
lib/ui/auth/widgets/otp_delivery_status.dart
test/auth_test_support.dart
test/data/repositories/api_auth_repository_test.dart
test/data/services/auth_api_service_test.dart
test/data/services/session_credential_store_test.dart
test/ui/auth/auth_view_models_test.dart
test/ui/auth/otp_screen_test.dart
```

### Modified

```text
README.md
android/app/src/debug/AndroidManifest.xml
android/app/src/main/AndroidManifest.xml
lib/app.dart
lib/routing/app_router.dart
lib/routing/startup_destination.dart
lib/ui/auth/view_models/auth_ui_controller.dart
lib/ui/auth/view_models/credentials_view_model.dart
lib/ui/auth/widgets/auth_field.dart
lib/ui/auth/widgets/credentials_screen.dart
lib/ui/onboarding/widgets/startup_flow.dart
pubspec.yaml
pubspec.lock
test/ui/auth/credentials_test.dart
test/ui/auth/profile_test.dart
test/ui/onboarding/splash_test.dart
test/ui/onboarding/tour_test.dart
test/ui/startup_test_support.dart
test/ui/startup_visual_test.dart
```

### Removed empty placeholders

```text
lib/data/repositories/.gitkeep
lib/data/services/.gitkeep
lib/domain/models/.gitkeep
test/data/repositories/.gitkeep
test/data/services/.gitkeep
```

## Documentation consulted

- [Flutter architecture](https://docs.flutter.dev/app-architecture/guide)
- [Flutter networking](https://docs.flutter.dev/cookbook/networking/send-data)
- [Flutter validation](https://docs.flutter.dev/cookbook/forms/validation)
- [Flutter testing](https://docs.flutter.dev/testing/overview)
- [Dart build-time configuration](https://dart.dev/libraries/core/environment-declarations)
- [Dart private named initializing formals](https://dart.dev/language/constructors)
- [ChangeNotifier](https://api.flutter.dev/flutter/foundation/ChangeNotifier-class.html)
- [OTP autofill hints](https://api.flutter.dev/flutter/services/AutofillHints/oneTimeCode-constant.html)
- [Digit input filtering](https://api.flutter.dev/flutter/services/FilteringTextInputFormatter/digitsOnly.html)
- [HTTP package](https://pub.dev/packages/http)
- [Secure-storage package and Android configuration](https://pub.dev/packages/flutter_secure_storage)
- [Android network security](https://developer.android.com/privacy-and-security/security-config)
- [Android backup rules](https://developer.android.com/identity/data/autobackup)
