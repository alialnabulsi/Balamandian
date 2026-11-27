# My Notes implementation checkpoint

## Behavior and architecture

The existing My Notes shortcut opens `/tools/notes`. Student/advisor-containing
accounts qualify; guests get the existing sign-in prompt and other roles a
restricted-access state. Both browser and direct editor navigation wait for the
correct owner's profile, distinguish loading/error from guest identity, and use
existing expiry handling. Roles, ownership and attachment access are independently
enforced on the backend.

The browser reuses the Balamandian shell, pattern, theme/tokens and shared controls.
It provides nested folders, breadcrumbs, hierarchy Back, global case-insensitive
title search with result paths, creation/rename/move/delete, note previews and
modification dates. Playground is permanent/idempotent and receives root/default
notes. New notes inside a folder default to that folder. Deletion confirmation
explains preserved-content rehoming; individual notes require confirmation.

The nested editor is presented on the root navigator, giving it a full screen
without shell floating actions. It has a title, paragraph/heading/bullet/numbered
blocks, bold/italic/underline for the selected whole paragraph, document undo/redo,
an accessible horizontally scrollable toolbar, and explicit Save. Formatting is
block-based, not inline selection-based. Text, drawings and attachments preserve
their order in a validated version-1 document. Title defaults to Untitled note.

MVVM boundaries: immutable document/folder/note models in `note_models.dart`;
authenticated HTTP in `NotesApiService`; repository contract/API implementation;
`NotesSession`, browser/editor/drawing ViewModels; dedicated configurable widgets.
No widget performs HTTP or serialization. Root DI owns clients/session/exit guard.
Existing GPA behavior and pending Tools/To-do/GPA files were preserved.

## Documents, drawings and files

The complete API/schema is in sibling `Balamandian-API/docs/notes.md`. Document
version 1 has ordered unique-ID blocks. Text blocks carry type/text and three
formatting booleans; drawing blocks carry editable strokes; attachment blocks carry
private server attachment IDs. Limits: 160 Unicode title characters, 80 folder-name
characters, 512 KiB JSON, 100 blocks, 50,000 text characters, 200 strokes, 10,000
points and 10 attachment blocks. Accounts have at most 1000 notes and 1000 folders
including Playground.

Drawing is contained in a dedicated editor with a 4:3 paper canvas, five ink
colours, three widths, whole-stroke eraser and undo/redo. Coordinates are normalized
to `[0,1]`, widths are fractions of paper width. Finger/stylus gestures stay inside
the paper; sheet dragging/dismissal is disabled. Checkmark commits the drawing to
the note, Cancel restores its original document. While drawing, periodic local
snapshots (120 ms, also flushed on stroke end) include unfinished strokes for
restart recovery; server autosave waits until the contained editor closes.

Files: JPEG/PNG/WebP/PDF, 5 MiB each, at most 10 stored attachments per note.
Images are fully decoded/re-encoded as metadata-free WebP on the backend with
4096×4096 input/2048×2048 output limits. PDFs have bounded signature/trailer checks,
not full structural parsing, malware scanning or active-content sanitization.
Image previews open enlarged; PDFs open in an installed Android viewer.

Uploads show streamed byte progress, distinguish 100% transmission from server
acknowledgment, retain selected files privately before sending, and support
cancel/retry. An idempotency key prevents retry duplicates. Text edits preserve
references. Removal saves the new document before server-side binary cleanup;
failed saves retain the draft. Unreferenced uploads expire lazily after 24 hours;
retained local files can be retried if an unacknowledged reference has expired.
Note deletion cascades binary rows. No marketplace/public media URL is used.

PDF opening uses a small existing-style Flutter MethodChannel and AndroidX
FileProvider bridge. Only generated PDFs inside `cache/notes-pdf/` are accepted;
the provider is unexported, grants read access only, and exposes only that directory.
Cache copies/read grants are cleared on editor exit or account changes. Opening
in another app intentionally gives that viewer the selected content; a viewer may
retain a copy after reading it. No storage permission or public export path is added.

Focused dependencies: `file_selector` 1.1.0 for native image/PDF selection;
`path_provider` 2.1.6 (already installed transitively, now direct) for app-private
draft/cache directories. Existing dependency versions are unchanged. PDF opening
reuses existing AndroidX; no extra PDF-opening package is retained.

## Saving, recovery and conflicts

Changes are immediately queued to an owner/note-scoped app-private draft file,
using serialized writes, flush and same-directory temporary-file rename. Pending
binary files and metadata live alongside that draft; another account never lists
or renders them. Android backup remains disabled. The browser exposes local
recovery drafts even when collection loading fails. Opening a note reads its local
draft and the server: recovered content is labelled **not server-saved**. Recovered
drafts await explicit Save/edit; no silent overwrite occurs.

Server autosave is debounced 900 ms, with Saving / Saved / Unsaved changes status.
Saved requires backend acknowledgment. Saves serialize; edits made while a request
is pending remain in the editor and are saved with the acknowledged next revision.
Late responses cannot replace newer text. Undo/redo is bounded to 50 unsaved
document snapshots; history that would restore expired/deleted attachment files
is pruned after a successful save.

A 409 revision conflict preserves local content and stops automatic resubmission.
An explicit confirmation can rebase the local draft onto the latest revision for
a subsequent Save; it warns that this replaces the latest server content. A new
concurrent change still conflicts. Deleted notes are never recreated by autosave.

Back and direct route changes invoke the same guard. Choices are Save & leave,
Keep local draft & leave, or Stay. Failed server/local persistence does not silently
discard work. Successful saves remove recovery files. Failed saves retain them.
No full offline collection synchronization is implemented. A process killed before
an asynchronous draft write completes can lose the very latest unflushed input;
completed local writes survive restart and remain distinct from server saves.

Logout/account/eligibility changes cancel requests and timers, clear visible notes,
drawings and image caches, dismiss/hide private modals, and invalidate old responses.
Old-owner draft writes may finish only in that owner's private namespace. The
existing session boundary handles unauthorized responses. Inaccessible/deleted
notes retain recoverable local work and never issue a new-note create as fallback.

## Schema, migration and checks

Backend migration `0005_notes.sql` adds private `note_folder`, `personal_note` and
`note_attachment` tables with UUIDs, timestamps, revision and binary storage.
Per-owner transaction locking protects hierarchy cycles/concurrent moves and
atomic preserved-content deletion; composite foreign keys prevent cross-owner
references. Previous applied SQL/checksums remain unchanged. Normal migration
workflow applied only 0005 to confirmed local `127.0.0.1:5432 / balamandian`,
PostgreSQL 18.0. No database reset or SIS-API change occurred.

Backend checks: `npm run check`; `npm test` (50 pass); `npm run test:integration`
(58 pass). The integration script now runs test files serially because simultaneous
fixtures produced repeatable loopback timeouts on the shared local PostgreSQL
instance. Per-feature concurrency tests remain concurrent and pass. Test databases
still use validated random names and cleanup only their own data.

`flutter analyze --no-pub` reports no issues. The full
`flutter test --no-pub --reporter expanded` run passes **518 tests**, including
38 new Notes tests. Focused tests cover draft filesystem
restart/owner isolation, versioned formatting/ink, unfinished drawing recovery,
autosave ordering, failure/retry, revisions, deletion during a save, stale account
responses, role/direct-route gates, guarded navigation, handwriting gestures,
keyboard/dark/narrow/landscape/enlarged layouts and accessibility. The routing
rebuild test preloads the established fonts to avoid a cold-asset startup timeout.
Phone browser/editor screenshots are in ignored `build/ui-verification/tools/`.

Android build attempts retain TLS verification. Online artifact resolution hit
the environment's Java certificate-chain error (`PKIX path building failed`) for
existing AndroidX test metadata. No certificates, global trust settings, SDKs or
dependency versions were changed to bypass that error. Cached-artifact compilation
then succeeded with `android/gradlew.bat --offline assembleDebug`: **BUILD
SUCCESSFUL**, 394 tasks (131 executed, 263 up-to-date), 4m 39s. This compiled the
new Kotlin/PDF provider and Flutter code without network trust changes. The
final incremental build with `--offline --max-workers=2 assembleDebug` also passed
in 33 seconds (24 tasks executed, 370 up-to-date), including the final source.
The
diagnostic APK is `build/app/outputs/apk/debug/app-debug.apk`; use the existing
configured phone launcher for API-connected acceptance, since this compile check
does not supply private device API configuration. Physical PDF-viewer and stylus
acceptance still requires the Samsung device. Existing plugins emit the Flutter
Built-in Kotlin migration warning; no unrelated plugin upgrade was made.

## Samsung A55 acceptance

1. Open Tools from drawer and floating actions, then My Notes. Check student,
   advisor and mixed-role accounts; guest sign-in prompt; other-role denial,
   including direct browser/editor navigation.
2. Verify one Playground across repeated openings; its actions are protected.
   Create parent/child/grandchild folders, rename and move them, and try a cycle.
   Check breadcrumbs/Android Back and new-note default destinations.
3. Create unnamed/named notes; search a title using different case and verify its
   full folder path. Delete a parent after confirming: direct notes/children must
   rehome correctly and nested contents must remain intact.
4. Edit headings, bold/italic/underline, bullets/numbered blocks and undo/redo.
   Save/reopen. Draw with finger/stylus, change colour/width, erase, undo/redo,
   insert, reopen and continue. Rotate and confirm stroke alignment.
5. Select an image and PDF; check progress, previews/opening, cancel, offline
   failure and retry. Edit text without losing references; remove/save and verify
   the file is unavailable. Another account must not read/upload/delete it.
6. Edit offline, leave with a local draft, restart and log in as the same owner:
   verify recovered text, ink and selected files, with the not-server-saved label.
   A different account must see none of them. Check disk/save errors preserve work.
7. Edit one note on two sessions: the stale save must conflict and preserve its
   draft. Confirm explicit rebase before replacement. Delete during a pending save
   and verify the note never reappears.
8. Check keyboard, dark mode, largest practical text, narrow/landscape layouts,
   toolbar horizontal scrolling, editor absence of shell floating actions, Back/
   direct-route leave prompts, logout while editing/drawing and expired sessions.

## Exact commit preparation

Both repositories remain on `feature/tools`, uncommitted. The earlier Tools index
and uncommitted To-do/GPA work were preserved. Record those reviewed baselines
first: the shared root wiring/test files contain multiple checkpoints. Do not run
the Notes commit against the current mixed index before recording that baseline.
The commands below stage only file-specific Notes paths after that preparation.

In Balamandian-API:

```powershell
$notesBackendFiles = @(
  'README.md'
  'docs/notes.md'
  'docs/architecture.md'
  'database/migrations/README.md'
  'database/migrations/0005_notes.sql'
  'package.json'
  'src/app.ts'
  'src/server.ts'
  'src/modules/notes/notes.composition.ts'
  'src/modules/notes/notes.controller.ts'
  'src/modules/notes/notes.repository.ts'
  'src/modules/notes/notes.routes.ts'
  'src/modules/notes/notes.service.ts'
  'src/modules/notes/notes.validators.ts'
  'test/notes.test.js'
  'test/integration/notes.test.js'
  'test/integration/auth.test.js'
  'test/integration/marketplace.test.js'
  'test/integration/profile.test.js'
  'test/integration/tasks.test.js'
)
git add -- $notesBackendFiles
git diff --cached --stat
git commit -m "feat(notes): add private notes folders and attachments"
```

In Balamandian:

```powershell
$notesFrontendFiles = @(
  'README.md'
  'Docs/my-notes.md'
  'pubspec.yaml'
  'pubspec.lock'
  'lib/app.dart'
  'lib/routing/app_router.dart'
  'lib/ui/home/widgets/app_shell.dart'
  'lib/ui/tools/widgets/tools_screen.dart'
  'lib/domain/models/note_models.dart'
  'lib/data/repositories/notes_repository.dart'
  'lib/data/repositories/api_notes_repository.dart'
  'lib/data/services/notes_api_service.dart'
  'lib/data/services/note_draft_store.dart'
  'lib/data/services/note_file_service.dart'
  'lib/ui/notes/view_models/notes_session.dart'
  'lib/ui/notes/view_models/notes_browser_view_model.dart'
  'lib/ui/notes/view_models/note_editor_view_model.dart'
  'lib/ui/notes/view_models/drawing_view_model.dart'
  'lib/ui/notes/view_models/notes_exit_guard.dart'
  'lib/ui/notes/widgets/notes_browser_screen.dart'
  'lib/ui/notes/widgets/notes_header.dart'
  'lib/ui/notes/widgets/notes_breadcrumbs.dart'
  'lib/ui/notes/widgets/notes_item_tile.dart'
  'lib/ui/notes/widgets/notes_access_panel.dart'
  'lib/ui/notes/widgets/notes_dialogs.dart'
  'lib/ui/notes/widgets/notes_scoped_dialog.dart'
  'lib/ui/notes/widgets/note_editor_screen.dart'
  'lib/ui/notes/widgets/note_text_block.dart'
  'lib/ui/notes/widgets/note_formatting_toolbar.dart'
  'lib/ui/notes/widgets/note_drawing_canvas.dart'
  'lib/ui/notes/widgets/note_drawing_editor.dart'
  'lib/ui/notes/widgets/note_attachment_tile.dart'
  'android/app/src/main/AndroidManifest.xml'
  'android/app/src/main/kotlin/com/example/balamandian/MainActivity.kt'
  'android/app/src/main/kotlin/com/example/balamandian/NotesFileProvider.kt'
  'android/app/src/main/kotlin/com/example/balamandian/NotesPdfOpener.kt'
  'android/app/src/main/res/xml/notes_file_paths.xml'
  'test/notes_test_support.dart'
  'test/data/services/notes_storage_api_test.dart'
  'test/ui/notes/note_editor_view_model_test.dart'
  'test/ui/notes/notes_screens_test.dart'
  'test/ui/tools/tools_screen_test.dart'
  'test/routing/app_router_test.dart'
)
git add -- $notesFrontendFiles
git diff --cached --stat
git commit -m "feat(notes): add notes editor folders and handwriting"
```

No commit/staging action above has been performed automatically.

References consulted: [Flutter MVVM](https://docs.flutter.dev/app-architecture/guide),
[EditableText](https://api.flutter.dev/flutter/widgets/EditableText-class.html),
[CustomPainter](https://api.flutter.dev/flutter/rendering/CustomPainter-class.html),
[PopScope](https://api.flutter.dev/flutter/widgets/PopScope-class.html),
[Dart file rename](https://api.dart.dev/dart-io/File/rename.html),
[file_selector](https://pub.dev/packages/file_selector),
[path_provider](https://pub.dev/packages/path_provider),
[platform channels](https://docs.flutter.dev/platform-integration/platform-channels),
and [Android FileProvider](https://developer.android.com/reference/androidx/core/content/FileProvider).

## Compact editor follow-up

A new empty note creates an initial blank body locally, focuses it and accepts writing immediately. Existing documents and attachments are preserved. Explicit Save persists the note and returns to My Notes; a failed save keeps the editor and typed content. Shared action-button labels now reserve balanced space and remain centered while saving.
