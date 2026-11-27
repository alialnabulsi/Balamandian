# feature/tools branch audit and SIS recovery

**Historical report.** The direct SIS database exception described in this earlier
recovery audit has been revoked. Current code requires Flutter -> Balamandian-API
-> authenticated SIS-API -> SIS PostgreSQL; Balamandian-API connects only to its
own database. The original direct reader is removed. Current endpoint requirements
and pending coordination with Ali are in Balamandian-API/docs/sis-tools-contract.md.
The historical deployment/readiness claims below do not establish current live
academic endpoint availability.


Audit date: **27 November 2026 (Asia/Beirut)**. This report supersedes earlier
claims that SIS academic API additions or migration 002 were required.

## Outcome

SIS-API is restored to its original `dev` branch at `e830410`, with no staged,
unstaged or untracked source changes. Its local `sis_db` is restored to the
original **25 tables**. The five empty academic tables, tracking table and added
columns/constraints introduced by the previous implementation were removed only
after verifying the exact migration checksum, zero new records and default-only
new columns. All original table row counts were checked before/after. No original
SIS row was updated/deleted. No hosted database was changed.

Balamandian and Balamandian-API remain on `feature/tools`. The accepted Tools/UI
work and private task/note/calendar/report persistence are preserved. The false
academic HTTPS contract has been replaced by an explicitly approved **read-only
SIS database adapter**, using the original tables. The original HTTP adapter
still handles institutional credential verification and member identity.

No commits, pushes, merges, dependency upgrades or branch synchronization were
performed. The SIS branch was switched back to its original dev only after its
worktree was clean and both refs were verified at the same commit. Non-secret
recovery copies of reverted code are in ignored `build/recovery/`, outside SIS.

## Scope and repository state

The review covers the complete Tools working change set relative to each current
HEAD: tracked changes, the 20 pre-existing staged frontend paths, and all untracked
feature code/tests/data/docs. It also reviews shared routing, profile/session,
networking, native integration and source/cache boundaries affected by that work.
The full regression suites cover existing auth/marketplace/profile behavior.
This is a source/behavior audit with local automated verification, not a claim
that every unchanged historical line or physical-device scenario was retested.

| Repository | Current branch | HEAD | Changed paths | Staged paths |
| --- | --- | --- | --- | --- |
| Balamandian | `feature/tools` | `5189dd4` | 152 | 20 |
| Balamandian-API | `feature/tools` | `5062ef2` | 76 | 0 |
| SIS-API | `dev` | `e830410` | 0 | 0 |

Frontend HEAD `5189dd4` is the existing physical-device launcher commit; it was
verified rather than assumed. `tool/run_phone.ps1` is unchanged. Local dev refs
show frontend one commit ahead, zero behind; backend equal to dev; SIS equal to
dev. These comparisons use existing local refs only, without fetching.
All 20 previously staged frontend files remain staged; no new staging was done.
The remaining frontend/backend feature changes are uncommitted. See the complete
file/status inventory below. Ignored configuration, dependencies, generated
builds, logs and recovery copies are excluded from the inventory.

## Findings and release constraints

| Priority | Finding | Disposition / evidence |
| --- | --- | --- |
| High, resolved | GPA/scheduler depended on academic SIS routes/tables added during the prior turn. | Those SIS additions are fully reverted. Production reader uses original SQL tables; real PostgreSQL tests start from original schema 001 only. |
| High, resolved | Refreshing original SIS semester metadata could overwrite trusted app registration windows with absent source fields. | Cache import preserves existing opening/closing instants and produces stable combined versions. Repeated-import integration test passes. |
| High, configuration | Original semester has start/end dates but no registration-opening/closing fields. | Existing trusted app-side semester configuration is required before planning opens. No period is inferred from teaching dates. Actual timetable retrieval works independently. |
| Medium, data/policy | Original enrollment stores final_grade, not official GPA/CGPA summaries or repeat/transfer rules. | Import derives weighted numeric results with the existing app policy and labels them as calculated. Missing, unsupported, conflicting and repeated grades retain manual input instead of producing a fabricated official result. |
| Medium, data | Local SIS currently has zero semesters, program_course rows, sections and enrollments. | Reader connection succeeds in read-only mode; empty states are expected until authoritative data exists. No production/demo academic data was seeded. |
| Medium, external dependency | OSA delivery is not configured. | Submission/withdrawal changes and private pending events are transactional. No university personnel were messaged, and saved reports are not described as delivered notifications. Future OSA UI/worker remains outside this checkpoint. |
| Medium, device validation | Native reminder timing/boot/background behavior and refined screens need physical-device review. | Automated UI/native compilation pass. Android inexact alarms can be delayed; no push service was added. |
| Medium, deployment | Local reader uses existing private development connection credentials. | Session and transaction are read-only; no database role was created/changed. Configure a SELECT-only account and verified TLS for hosted SIS. The existing main app database config separately supports loopback hosts only. |
| Medium, upload boundary | PDFs receive bounded signature/trailer checks, not full parsing or malware scanning. | Private ownership/no-store/download disposition and size checks apply. This is an existing documented limitation; no scanner or delivery guarantee is claimed. |
| Low, maintenance | University numeric equivalence convention exists in Dart predictions and the backend derived import. | Both use the existing floor/table convention; automated numeric tests pass. Future policy changes must update both implementations together. |
| Low, build compatibility | Existing Mapbox/Kotlin/Gradle compatibility warnings and AndroidX selector pins remain. | No dependency was upgraded. The exact cached AndroidX selectors avoid the earlier dynamic Maven version lookup; the audit build uses the offline cache. |

No outstanding compiler, static-analysis or automated-test failure remains in the
validated code. Live hosted academic content, an authoritative registration
window, OSA delivery and physical-device behavior are separate acceptance gates.

## Original SIS capability mapping

| Data/behavior | Original source | Handling in app backend |
| --- | --- | --- |
| Identity and roles | Existing POST /auth/verify and GET /members/:userId | Original service-authenticated HTTPS adapter; no institutional password reads in academic code |
| Student record/status | student joined to active sis_user | Owned SIS ID from the app session; no client owner override |
| Degree course pool | student_program + program_course + course | Active study plan; required/elective course IDs retained; no new verification flags |
| Requirement edges | course_prerequisite.requirement_kind | Listed prerequisite/corequisite edges; no guessed parsing of free-form program.requirements |
| Offered sections | section + course + semester + campus | Real section rows, capacity occupancy and campus timezone |
| Timetable intervals | section_meeting + semester dates | One atomic section with its own meeting types; weekly source interpretation, original campus local time; no fabricated links between separate section rows |
| Actual registration | enrollment + section | Existing non-dropped/non-withdrawn records prove registration. Valid student plus no term enrollment means not_registered; missing student means unknown |
| Holds | student_hold | Currently effective unreleased holds restrict planning |
| GPA/CGPA | Completed/failed enrollment.final_grade + course.credits + semester | Numeric weighted averages; one course per term even with multiple components. Repeated attempts/unsupported grades require manual baseline. No official publication date invented |
| Registration window | Not present in original schema | Already-existing trusted app configuration; preserved across sync |
| Official GPA summaries / personal credit limit | Not present in original schema | No new SIS tables. Derived GPA is labelled accurately. 36 credits is the app input bound, not a claimed student-specific university cap |
| Degree completion denominator | No authoritative numeric total in original program fields | No fabricated completion percentage; structured progress stays unavailable when its denominator is unknown |
| Complex section links / irregular recurrence | No explicit cross-section bundle or alternating-week fields | Ambiguous/incomplete combinations are excluded. The source is not expanded with invented attributes |

The application never writes to these SIS tables. The only SIS database writes
in this recovery were the explicitly requested removal of the previous empty
schema additions, followed by read-only verification.

## Runtime architecture and cache

- Phone -> Balamandian-API only. SIS credentials/service key/connection URL never
  enter Flutter, tracked files or response DTOs.
- `sis.academics.ts` is the single dedicated original-schema reader. It uses the
  existing pg dependency, a two-connection pool, deadlines, sanitized errors,
  default_transaction_read_only=on and REPEATABLE READ READ ONLY transactions.
- `sis.schedule.ts` is a thin gateway for the existing scheduler service. The
  authentication SisAdapter/SisGateway no longer contains academic endpoint calls.
- GET `/profile/me/academics` reads the private profile cache. POST
  `/profile/me/academics/sync` explicitly refreshes supported source grades and
  stores the owner result. Failed imports preserve the previous cache/input.
- Scheduler semester metadata has a five-minute cache; owner/term snapshots are
  imported on first use, then read locally. Explicit Sync and proposal mutations
  revalidate source enrollment/offerings. Source versions and optimistic revisions
  protect saved proposals. Account changes invalidate private frontend state and
  late responses. Conflicts reload the current cached registration state.
- Applied app migration `0009_academic_profile_cache.sql` is retained unchanged
  because its private profile cache/date/sync fields are reused. App history
  0001-0009 is immutable; this recovery adds no new migration.
- Existing app routes, envelopes and authenticated session-expiry handling remain.
  No nonexistent SIS academic HTTP route is called.

## Feature and access review

| Feature | Verified implementation and boundaries |
| --- | --- |
| Tools hub | Both existing navigation entries converge on Tools; six compact shortcuts; SIS/Moodle/iMail use existing external-link service; unverified contacts do not dial dummy numbers |
| Access | Students have all six tools; advisors have all except GPA; mixed roles containing an eligible role qualify. Guests see the hub and academic calendar; protected actions use existing sign-in. Profile loading/error is distinct from guest identity. Direct routes and APIs enforce access |
| To-do | Private account CRUD, optional details clearing, actual status values, deterministic listing, loading/retry/refresh, progress with empty 0%, List/Kanban shared data, long-press/haptic/drop/edge scroll, server-confirmed mutations and title-only cards |
| GPA | Temporary numeric predictions, compact manual inputs and explicit source import; exact weighted totals retained. Derived imported values are labelled. Failed/missing source data preserves typed entries |
| Notes | Private hierarchical folders, rich document blocks, drawing, private image/PDF files, revisions/autosave/local recovery. New note opens a writable blank body; explicit successful Save returns to browser; failed Save retains editor content |
| Lost & Found | Blue/yellow/green choices, private owner reports/uploads/history, idempotent title-only creation, confirmed withdrawal, durable pending OSA events. No public feed or student-to-student contact exposure |
| Calendar | Structured official academic events, protected published university and personal categories, month/day agenda, adjacent scrolling filters, distinct calendar surface, simple keyboard-safe editor, all-day inclusive UI/exclusive API end dates, Asia/Beirut handling and native reminder queue |
| Scheduler | One automatic workflow per selected term: actual timetable after registration/outside planning, eligible builder during configured registration, generated alternatives, selected proposed timetable, guarded deletion and explicit SIS registration link. Proposal never creates an official enrollment |
| Shared UI/native | Existing theme/tokens/pattern/shell reused; balanced button-label space, narrow/landscape/enlarged text and keyboard checks. Root Notes editor intentionally has dedicated space. Private PDF provider is non-exported and backup is disabled |

Private APIs derive owner UUID from authenticated sessions. Task/note/report/event
queries and mutations scope to that UUID. Wrong-owner IDs use unavailable/404
behavior; role checks use persisted authoritative identity roles. OSA/super-admin
operations require explicit server allowlists, not arbitrary staff/advisor roles.
Shared upload validation bounds bytes/pixels, normalizes images and strips metadata.
No real recipient was contacted. Review and test scope does not establish malware
safety or remote notification delivery beyond those implemented boundaries.

## Verification performed for this recovery

| Command/check | Result |
| --- | --- |
| Flutter analysis (`flutter_tools.snapshot analyze --no-pub`) | No issues found |
| Full Flutter suite (`flutter_tools.snapshot test --no-pub`) | **549 passed, 0 failed** |
| App backend `npm run check` | TypeScript, ESLint zero warnings and Prettier passed |
| App backend `npm test` | **60 passed, 0 failed** |
| App backend `npm run test:integration` | **79 passed, 0 failed**, serial isolated PostgreSQL databases |
| Original-schema academic integration | Included above: exact 25-table schema, read-only write rejection, owned numeric grades, real sections/alternatives/actual timetable, stable preserved app registration windows |
| App backend `npm run db:migrate` | **0 applied**, existing checksums preserved |
| Restored SIS `npm test` | **25 passed, 0 failed** |
| Restored SIS `npm run db:check` | **25/25 tables**, sis_db, PostgreSQL 18.0 |
| Configured SIS reader probe | Connection succeeds, default_transaction_read_only=on; zero real academic rows, zero returned semesters |
| Final Android offline debug build | **BUILD SUCCESSFUL**, 2m 15s; 394 tasks (93 executed, 301 up-to-date) |
| Git diff whitespace checks | Clean; original staged frontend work preserved |

The fixture used by the app integration test is an exact copy of original SIS
schema 001 (test-only, never run against the configured live SIS). SHA-256:
`f90e0f8c2e64b18cefbfdc7e9d266753432a569ad9a908c80e67df8fe46c03da`.
Tests create/remove strictly named random scratch databases; development databases
are never reset. The recovery files and logs are ignored artifacts. Private
configuration was used through the normal runtime loader and was not printed.
No manual phone run or live hosted enrollment/grade verification is claimed.

## Deployment and physical acceptance

1. Superseded: configure only SIS_BASE_URL, SIS_SERVICE_API_KEY and SIS_TIMEOUT_MS
   for authenticated SIS HTTP access. Do not configure or use a direct SIS database
   reader. Coordinate missing academic endpoints and any shared deployment with Ali.
2. Run the existing app migration command for a fresh app deployment (through
   0009); do not apply the removed SIS migration 002. Existing local app history
   already reports zero pending migrations.
3. Populate original SIS records through the university's own process when
   available. Verify one student's numeric grades and timetable against SIS.
   Unsupported or repeated grade data must retain manual GPA entry.
4. Configure real registration instants using the existing trusted semester CLI
   and the numeric SIS semester ID. Test closed/open/already-registered states,
   multiple non-conflicting alternatives, selection/reload and guarded deletion.
5. Run the existing phone launcher, then check all six tools with student,
   advisor/mixed and guest accounts. Test logout/account switches with pending
   requests and private dialogs, dark mode, enlarged text, landscape and keyboard.
6. Verify native reminders with permission denied/granted, foreground/background,
   terminated process, notification tap and reboot. Check private PDF opening,
   handwriting and Save returning to Notes. Do not send test reports to real OSA.

## Official documentation consulted

Project choices follow the existing MVVM/modular-monolith conventions. Current
official references consulted during the recovery:
[Flutter architecture](https://docs.flutter.dev/app-architecture/guide),
[Node 24 file operations](https://nodejs.org/docs/latest-v24.x/api/fs.html),
[PostgreSQL read-only transactions](https://www.postgresql.org/docs/18/sql-set-transaction.html),
[node-postgres transactions](https://node-postgres.com/features/transactions),
[pool lifecycle](https://node-postgres.com/apis/pool),
[TLS configuration](https://node-postgres.com/features/ssl),
[Express 5 API](https://expressjs.com/en/5x/api/).
The direct SIS read exception was explicitly approved by the user in this session;
it is not presented as a framework requirement or the original architecture rule.

## Complete changed-file inventory

Git status columns are preserved: `M ` staged modification, ` M` unstaged,
`MM` both, `A ` staged addition, `AM` staged addition with further edits,
`??` untracked. This inventory records work for review; it stages nothing.

### Balamandian

```text
MM README.md
 M android/app/src/main/AndroidManifest.xml
 M android/app/src/main/kotlin/com/example/balamandian/MainActivity.kt
 M android/build.gradle.kts
MM lib/app.dart
 M lib/data/services/profile_api_service.dart
 M lib/domain/models/profile_models.dart
MM lib/routing/app_router.dart
A  lib/ui/auth/widgets/sign_in_prompt.dart
 M lib/ui/core/ui/buttons/async_action_button.dart
M  lib/ui/core/ui/navigation/app_account_drawer.dart
M  lib/ui/core/ui/navigation/app_navigation_item.dart
MM lib/ui/home/widgets/app_shell.dart
 M lib/ui/profile/widgets/account_information_sheet.dart
 M lib/ui/profile/widgets/profile_screen.dart
A  lib/ui/tools/view_models/tools_hub_view_model.dart
A  lib/ui/tools/widgets/campus_contact_item.dart
A  lib/ui/tools/widgets/shortcut_grid.dart
A  lib/ui/tools/widgets/tool_feedback_dialog.dart
A  lib/ui/tools/widgets/tool_shortcut.dart
AM lib/ui/tools/widgets/tools_screen.dart
A  lib/ui/tools/widgets/tools_section.dart
 M pubspec.lock
 M pubspec.yaml
 M test/routing/app_router_test.dart
M  test/routing/session_routing_test.dart
A  test/routing/tools_routing_test.dart
M  test/ui/auth/credentials_test.dart
M  test/ui/home/home_shell_test.dart
A  test/ui/tools/tools_hub_view_model_test.dart
AM test/ui/tools/tools_screen_test.dart
?? Docs/feature-tools-audit.md
?? Docs/gpa-calculator.md
?? Docs/my-notes.md
?? Docs/remaining-tools.md
?? Docs/to-do-planner.md
?? android/app/src/main/kotlin/com/example/balamandian/CalendarReminders.kt
?? android/app/src/main/kotlin/com/example/balamandian/NotesFileProvider.kt
?? android/app/src/main/kotlin/com/example/balamandian/NotesPdfOpener.kt
?? android/app/src/main/res/drawable/ic_calendar_notification.xml
?? android/app/src/main/res/xml/notes_file_paths.xml
?? lib/data/repositories/academic_repository.dart
?? lib/data/repositories/api_academic_repository.dart
?? lib/data/repositories/api_notes_repository.dart
?? lib/data/repositories/api_task_repository.dart
?? lib/data/repositories/calendar_repository.dart
?? lib/data/repositories/lost_found_repository.dart
?? lib/data/repositories/notes_repository.dart
?? lib/data/repositories/scheduler_repository.dart
?? lib/data/repositories/task_repository.dart
?? lib/data/services/calendar_reminder_service.dart
?? lib/data/services/note_draft_store.dart
?? lib/data/services/note_file_service.dart
?? lib/data/services/notes_api_service.dart
?? lib/data/services/task_api_service.dart
?? lib/data/services/tools_api_service.dart
?? lib/domain/models/academic_profile.dart
?? lib/domain/models/calendar_models.dart
?? lib/domain/models/gpa_calculation.dart
?? lib/domain/models/lost_found_models.dart
?? lib/domain/models/note_models.dart
?? lib/domain/models/schedule_models.dart
?? lib/domain/models/task_models.dart
?? lib/domain/models/tool_failure.dart
?? lib/ui/calendar/view_models/calendar_reminder_coordinator.dart
?? lib/ui/calendar/view_models/calendar_view_model.dart
?? lib/ui/calendar/view_models/event_editor_view_model.dart
?? lib/ui/calendar/widgets/calendar_category_filter.dart
?? lib/ui/calendar/widgets/calendar_event_details.dart
?? lib/ui/calendar/widgets/calendar_event_tile.dart
?? lib/ui/calendar/widgets/campus_calendar_screen.dart
?? lib/ui/calendar/widgets/campus_month_calendar.dart
?? lib/ui/calendar/widgets/event_date_range_fields.dart
?? lib/ui/calendar/widgets/event_editor.dart
?? lib/ui/gpa/view_models/academic_profile_view_model.dart
?? lib/ui/gpa/view_models/gpa_calculator_view_model.dart
?? lib/ui/gpa/widgets/gpa_baseline_section.dart
?? lib/ui/gpa/widgets/gpa_calculator_screen.dart
?? lib/ui/gpa/widgets/gpa_course_card.dart
?? lib/ui/gpa/widgets/gpa_estimate_banner.dart
?? lib/ui/gpa/widgets/gpa_header.dart
?? lib/ui/gpa/widgets/gpa_input.dart
?? lib/ui/gpa/widgets/student_access_panel.dart
?? lib/ui/lost_found/view_models/lost_found_view_model.dart
?? lib/ui/lost_found/view_models/report_composer_view_model.dart
?? lib/ui/lost_found/view_models/report_details_view_model.dart
?? lib/ui/lost_found/widgets/lost_found_screen.dart
?? lib/ui/lost_found/widgets/report_choice_button.dart
?? lib/ui/lost_found/widgets/report_details.dart
?? lib/ui/lost_found/widgets/report_form.dart
?? lib/ui/lost_found/widgets/report_tile.dart
?? lib/ui/notes/view_models/drawing_view_model.dart
?? lib/ui/notes/view_models/note_editor_view_model.dart
?? lib/ui/notes/view_models/notes_browser_view_model.dart
?? lib/ui/notes/view_models/notes_exit_guard.dart
?? lib/ui/notes/view_models/notes_session.dart
?? lib/ui/notes/widgets/note_attachment_tile.dart
?? lib/ui/notes/widgets/note_drawing_canvas.dart
?? lib/ui/notes/widgets/note_drawing_editor.dart
?? lib/ui/notes/widgets/note_editor_screen.dart
?? lib/ui/notes/widgets/note_formatting_toolbar.dart
?? lib/ui/notes/widgets/note_text_block.dart
?? lib/ui/notes/widgets/notes_access_panel.dart
?? lib/ui/notes/widgets/notes_breadcrumbs.dart
?? lib/ui/notes/widgets/notes_browser_screen.dart
?? lib/ui/notes/widgets/notes_dialogs.dart
?? lib/ui/notes/widgets/notes_header.dart
?? lib/ui/notes/widgets/notes_item_tile.dart
?? lib/ui/notes/widgets/notes_scoped_dialog.dart
?? lib/ui/profile/widgets/academic_results_section.dart
?? lib/ui/scheduler/view_models/scheduler_view_model.dart
?? lib/ui/scheduler/widgets/course_pool_selector.dart
?? lib/ui/scheduler/widgets/schedule_option_tile.dart
?? lib/ui/scheduler/widgets/schedule_preview_dialog.dart
?? lib/ui/scheduler/widgets/schedule_timetable.dart
?? lib/ui/scheduler/widgets/schedule_week_grid.dart
?? lib/ui/scheduler/widgets/scheduler_screen.dart
?? lib/ui/tasks/view_models/task_editor_view_model.dart
?? lib/ui/tasks/view_models/task_planner_view_model.dart
?? lib/ui/tasks/widgets/task_access_panel.dart
?? lib/ui/tasks/widgets/task_card.dart
?? lib/ui/tasks/widgets/task_delete_dialog.dart
?? lib/ui/tasks/widgets/task_editor_sheet.dart
?? lib/ui/tasks/widgets/task_kanban_board.dart
?? lib/ui/tasks/widgets/task_kanban_card.dart
?? lib/ui/tasks/widgets/task_kanban_column.dart
?? lib/ui/tasks/widgets/task_planner_header.dart
?? lib/ui/tasks/widgets/task_planner_screen.dart
?? lib/ui/tasks/widgets/task_progress_summary.dart
?? lib/ui/tasks/widgets/task_status_menu.dart
?? lib/ui/tasks/widgets/task_view_switch.dart
?? lib/ui/tools/view_models/tool_session.dart
?? lib/ui/tools/widgets/tool_access_panel.dart
?? lib/ui/tools/widgets/tool_scoped_dialog.dart
?? test/academic_test_support.dart
?? test/data/services/academic_api_test.dart
?? test/data/services/notes_storage_api_test.dart
?? test/data/services/task_api_service_test.dart
?? test/domain/models/gpa_calculation_test.dart
?? test/notes_test_support.dart
?? test/routing/remaining_tools_routing_test.dart
?? test/task_test_support.dart
?? test/ui/calendar/calendar_test.dart
?? test/ui/gpa/gpa_calculator_screen_test.dart
?? test/ui/gpa/gpa_calculator_view_model_test.dart
?? test/ui/lost_found/lost_found_test.dart
?? test/ui/notes/note_editor_view_model_test.dart
?? test/ui/notes/notes_screens_test.dart
?? test/ui/remaining_tools_layout_test.dart
?? test/ui/scheduler/scheduler_test.dart
?? test/ui/tasks/task_planner_screen_test.dart
?? test/ui/tasks/task_planner_view_model_test.dart
```

### Balamandian-API

```text
 M README.md
 M database/migrations/README.md
 M docs/architecture.md
 M package.json
 M src/app.ts
 M src/modules/profile/profile.composition.ts
 M src/modules/profile/profile.controller.ts
 M src/modules/profile/profile.repository.ts
 M src/modules/profile/profile.routes.ts
 M src/modules/profile/profile.service.ts
 M src/server.ts
 M test/integration/auth.test.js
 M test/integration/marketplace.test.js
 M test/integration/profile.test.js
?? data/calendar/academic-2026-2027.json
?? database/migrations/0004_tasks.sql
?? database/migrations/0005_notes.sql
?? database/migrations/0006_lost_found.sql
?? database/migrations/0007_calendar.sql
?? database/migrations/0008_scheduler.sql
?? database/migrations/0009_academic_profile_cache.sql
?? docs/academics.md
?? docs/calendar.md
?? docs/lost-found.md
?? docs/notes.md
?? docs/scheduler.md
?? docs/tasks.md
?? src/integrations/sis/sis.academics.ts
?? src/integrations/sis/sis.schedule.ts
?? src/modules/calendar/calendar.admin.ts
?? src/modules/calendar/calendar.repository.ts
?? src/modules/calendar/calendar.routes.ts
?? src/modules/calendar/calendar.service.ts
?? src/modules/calendar/calendar.time.ts
?? src/modules/calendar/calendar.validators.ts
?? src/modules/lost-found/lost-found.repository.ts
?? src/modules/lost-found/lost-found.routes.ts
?? src/modules/lost-found/lost-found.service.ts
?? src/modules/lost-found/lost-found.validators.ts
?? src/modules/notes/notes.composition.ts
?? src/modules/notes/notes.controller.ts
?? src/modules/notes/notes.repository.ts
?? src/modules/notes/notes.routes.ts
?? src/modules/notes/notes.service.ts
?? src/modules/notes/notes.validators.ts
?? src/modules/profile/profile.academics.ts
?? src/modules/scheduler/scheduler.admin.ts
?? src/modules/scheduler/scheduler.generator.ts
?? src/modules/scheduler/scheduler.repository.ts
?? src/modules/scheduler/scheduler.routes.ts
?? src/modules/scheduler/scheduler.service.ts
?? src/modules/scheduler/scheduler.types.ts
?? src/modules/scheduler/scheduler.validators.ts
?? src/modules/tasks/tasks.composition.ts
?? src/modules/tasks/tasks.controller.ts
?? src/modules/tasks/tasks.middleware.ts
?? src/modules/tasks/tasks.repository.ts
?? src/modules/tasks/tasks.routes.ts
?? src/modules/tasks/tasks.service.ts
?? src/modules/tasks/tasks.types.ts
?? src/modules/tasks/tasks.validators.ts
?? src/scripts/tools-admin.ts
?? src/shared/private-upload.ts
?? src/shared/tool-validation.ts
?? src/shared/tools-access.ts
?? test/academics.test.js
?? test/fixtures/sis-original.sql
?? test/integration/calendar.test.js
?? test/integration/lost-found.test.js
?? test/integration/notes.test.js
?? test/integration/scheduler.test.js
?? test/integration/sis-academics.test.js
?? test/integration/tasks.test.js
?? test/notes.test.js
?? test/scheduler.test.js
?? test/tasks.test.js
```

### SIS-API

Clean worktree, no changed files.
