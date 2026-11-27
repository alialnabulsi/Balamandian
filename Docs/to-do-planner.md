# Connected To-do Planner

Checkpoint 3 implements `/tools/todo` beneath Tools, retaining the shared app
shell and Home → Tools → Planner back stack. Guest direct links render an access
gate with the existing sign-in prompt. Other institutional roles get an eligibility
explanation. Only profiles containing student or advisor request personal tasks;
profile loading/error remains distinct from guest identity. The backend enforces
the actual authentication, role and ownership policy.

## Implementation

- `lib/domain/models/task_models.dart`: immutable task/page/draft types, actual
  `todo` / `in_progress` / `done` mapping and safe failures.
- `lib/data/services/task_api_service.dart`: `/api/v1/tasks` GET/POST/PATCH/DELETE,
  abortable bounded requests, UTF-8 JSON, no redirects and protected-401 handling.
- `lib/data/repositories/task_repository.dart` / `api_task_repository.dart`:
  injected `AuthRepository.withSession`, stateless CRUD and loading every page at
  50 tasks/page. Incomplete, duplicate or visibly drifting pages require refresh.
- `lib/ui/tasks/view_models/`: access, loading, mutations, one shared collection,
  progress/counts, operation epochs and editor validation.
- `lib/ui/tasks/widgets/`: configurable header/progress/view switch, task cards,
  status menu, Kanban board/column, editor sheet, access panel and delete dialog.
- `lib/app.dart` owns API-client lifetime; `app_router.dart` registers the nested
  destination. The existing Tools shortcut opens it when eligible.

No private task cache or new device storage is introduced. The ViewModel verifies
profile ownership, clears private state on account/session or eligibility changes
and ignores obsolete responses. Editors clear text and close on account changes;
deletion dialogs remove old task text and cannot confirm for an earlier account.
An expired task session uses the existing credential-clearing and sign-in notice
flow; it is not silently treated as a deliberate guest visit.

## Validation and behavior

Titles are required, trimmed, single-line and at most 160 Unicode code points
before trimming. Details allow 2000 code points and LF newlines. Other control
characters and unpaired surrogates are rejected. Null/blank details clear the
stored value. Status defaults to To do. IDs, owner and timestamps come from the
server. These rules match the inspected backend validators.

Failed saves retain typed text and the editor. One pending mutation prevents
duplicate/conflicting saves, status changes, deletes and refresh. Cards move only
after API confirmation. Errors retain the last confirmed status. Progress uses
the full task collection, with 0% for an empty planner, and updates after successful
mutations/refresh. Both views consume the same collection.

Long-press lifts the card and produces exactly one light-impact haptic. Columns
show counts, highlight valid targets and scroll horizontally, including continuous
edge scrolling during dragging. Release uses a fresh hit test so a stationary
finger selects the column currently underneath it after scrolling. Outside drops,
pointer cancellations and same-column releases do nothing. A status menu is the
accessible alternative to dragging.

The editor uses a root modal sheet with safe areas, keyboard insets and scrolling.
It prevents dismissal while saving and provides Cancel otherwise. Components use
the shared pattern, Inter, semantic theme colors and 48 logical-pixel targets.
Text scales, layouts scroll and animations respect reduced-motion preferences.

## Verification and device review

Focused tests cover DTO/status mapping, all-page loading, session expiry, CRUD
and failures, count/progress updates, duplicate suppression, role gates, account
changes and late responses, both views, failed editor input, details clearing,
deletion, drag/drop/cancel/haptics/highlights, stationary edge scrolling and
keyboard visibility. Fixture screenshots are generated in ignored
`build/ui-verification/tools/planner*.png` for phone, narrow/2× text and dark
landscape/2× text layouts.

Final verification: `flutter analyze --no-pub` reported no issues.
The complete `flutter test --no-pub --reporter expanded` run passed all **448**
tests. The focused new/affected run passed 98 tests before the final session-expiry
regression was added; that regression and the updated logout-modal check also
passed independently and in the final full suite. Backend and SIS-API files,
dependency files and the pre-existing staged hub snapshot were preserved.

On Samsung A55, run the existing backend and `./tool/run_phone.ps1`. Open Tools →
To-do Planner using an eligible account. Create/edit a task, clear its details,
exercise all statuses via the menu, switch views, then long-press/drag among the
three columns. Hold at either edge to reach distant columns; cancel/release in the
original column and confirm no change. Check counts/progress, pull-to-refresh,
delete Cancel/confirm, and persistence after app restart. Test failed saves while
offline, reconnect/refresh, then close the editor and test logout/another account.
Automated tests also cover account changes while an editor or dialog is open.
Guests should get sign-in prompts; other roles must not load personal tasks.
Repeat with dark mode, landscape, enlarged text and the keyboard open. Verify
actual haptic feel and edge-scroll speed on the phone.

## Limits

No offline write queue, automatic mutation retry, real-time subscriptions,
manual column ordering or cross-device conflict protocol exists. The backend uses
last-write-wins on the same field. A lost response may follow a committed write:
refresh before retrying. Pagination is not a cross-request database snapshot;
detected drift requires refresh. Backend and SIS-API remain unchanged.

Official guidance consulted:
[MVVM](https://docs.flutter.dev/app-architecture/guide),
[go_router](https://pub.dev/documentation/go_router/latest/topics/Redirection-topic.html),
[LongPressDraggable](https://api.flutter.dev/flutter/widgets/LongPressDraggable-class.html),
[DragTarget](https://api.flutter.dev/flutter/widgets/DragTarget-class.html),
[haptics](https://api.flutter.dev/flutter/services/HapticFeedback/lightImpact.html),
[modal sheets](https://api.flutter.dev/flutter/material/showModalBottomSheet.html),
[hit testing](https://api.flutter.dev/flutter/rendering/RendererBinding/hitTestInView.html)
and [Dart enums](https://dart.dev/language/enums). Installed versions remain Flutter
3.47.5 / Dart 3.13.4; dependencies were not upgraded.
