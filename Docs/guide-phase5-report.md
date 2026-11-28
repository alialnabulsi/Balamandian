# University Guide - Phase 5 implementation report

Developer: Mohammad Hani Abou Naasse

Review date: 2026-11-28, Asia/Beirut

## Result and repository verification

The functional Flutter Guide is implemented and registered through the existing Guide composition slot. It includes dynamic home/section browsing, lexical search, a Markdown reader, English/Arabic content selection and persistent account-specific bookmarks through all seven approved endpoints. Ask AI remains unavailable pending joint integration. No production knowledge was imported or published.

| Repository      | Branch          | HEAD at inspection                         | Initial tree                                   |
| --------------- | --------------- | ------------------------------------------ | ---------------------------------------------- |
| Balamandian     | `feature/guide` | `55cd2a16d94b3fe98e496b62baa282546b683184` | Clean                                          |
| Balamandian-API | `feature/guide` | `fe967a106c5539353a8b2c129e148e5e0f373281` | Existing uncommitted Phase 2-4 work; preserved |

Inspection covered applicable AGENTS.md, the Flutter documentation skill, README architecture, the complete Guide/AI contract and collaboration protocol, API runbook/report, placeholders/composition slots, session lifecycle, service/repository/ViewModel patterns, themes, tokens, skeletons, feedback, external URLs and existing tests. Work remains uncommitted; no push, merge or deployment was performed.

## Phase 4 section-response resolution

This was a documentation mismatch, not a backend runtime defect. The Phase 4 report placed the captured Library Services response under a Library request heading. The report now contains matching responses for both requests.

| Request UUID                           | Returned section            | Immediate children | Breadcrumb                 |
| -------------------------------------- | --------------------------- | ------------------ | -------------------------- |
| `1321750c-7367-4515-89b5-55a9f701691f` | Library, same UUID          | Library Services   | Library                    |
| `4b38031e-18bc-4008-bca6-868d22a23d84` | Library Services, same UUID | None               | Library / Library Services |

Added explicit UUID/self-section assertions and child checks to the existing integration suite. All 13 Node integration tests passed against fresh disposable database `balamandian_guide_api_test_2a353d0cc42b4a36b41e9825a6bd51bb` on verified loopback PostgreSQL 18, port 5432. The test verified the exact target and an empty public schema before applying the 21 migrations and seed. The database was dropped afterward. Neither application nor recovery database was connected. Backend runtime files, schema and contract required no correction.

## Architecture and composition

The data flow remains View -> ViewModel -> GuideRepository -> GuideApiService -> Balamandian-API. Models compose the existing immutable `GuideArticleRef`, which is final and remains unchanged. Typed immutable lists represent sections, summaries, pages, details and sources. Nullable detail fields and optional excerpts are parsed explicitly.

`GuideApiService` owns UTF-8 envelope decoding, origin checks, bounded timeouts, abortable requests, safe failures and exact endpoint parameters. `ApiGuideRepository` wraps every operation in the existing `AuthRepository.withSession` boundary and rejects responses after cancellation. It does not implement authentication or store article content.

`GuideSession` observes the existing authentication repository, owns the selected content locale and shared `GuideBookmarks`, and clears account state/cancels requests on identity changes or logout. Browse, search, saved-list and reader ViewModels own presentation state. Disposed/request/session generation checks reject late work. No profile-role prerequisite was added to Guide.

`MainApp` creates the Guide dependencies, supplies the existing `guideRoute` slot and disposes owned resources. An optional Guide repository constructor parameter supports controlled tests using the same composition. Explicit caller-provided Guide routes still work. `lib/routing/app_router.dart`, shared link builders, session guards, Home shell, bottom navigation and AI route slot are unchanged.

The approved `/guide`, `/guide/sections/:sectionId` and `/guide/articles/:articleId?rev=...` locations use the existing builders. Search and Saved are feature-local Navigator pages under Guide, with no new shared URL contract. Returning from their article reader preserves the prior list. Full content is requested only when an article opens.

## Screens and behavior

- Home displays University Guide, search and saved entry actions, content language selection and dynamically loaded roots. It handles skeleton loading, empty content, errors and retry without fixed categories or counts.
- Sections display dynamic titles, root-to-current breadcrumbs, immediate subsections and summary pages. Children-only, articles-only, mixed and empty cases work. Pull-to-refresh reloads the selected section and locale.
- Search supports clear, 350 ms debounce, English/Arabic queries, optional excerpts, loading/empty/error states and cursor pagination. Changing query immediately invalidates older results; changing locale resets the page sequence.
- Saved shows eligible saved articles across locales, supports manual pagination and removal, and refreshes after confirmed bookmark mutations.
- Reader displays title/summary, current Markdown, verification, academic year/applicability when supplied, exact source labels/locators/links, bookmark controls and unavailable/retry states. A cited version mismatch displays an update notice while fetching only the current detail. `rev` is never sent to the backend.

Screens compose dedicated reusable feature widgets and existing shared skeleton, ContentState and AsyncActionButton components. Typography, surfaces, colors and spacing use the existing application theme/tokens. No Home, Tools, Map or bottom-navigation redesign was performed.

## Endpoint integration

All paths below use `/api/v1/guide`, the existing bearer session, and no client-supplied owner ID.

| Endpoint                       | Flutter integration                                  | Verified handling                                                          |
| ------------------------------ | ---------------------------------------------------- | -------------------------------------------------------------------------- |
| GET `/sections`                | Home roots                                           | `locale`; typed root summaries                                             |
| GET `/sections/:sectionId`     | Section ViewModel                                    | `locale`, optional `articleCursor`; hierarchy and lightweight summary page |
| GET `/articles/:articleId`     | Reader ViewModel                                     | No query; Markdown, exact sources, nullable applicability and verification |
| GET `/search`                  | Search ViewModel                                     | `q`, `locale`, optional `cursor`; summaries with optional excerpt          |
| GET `/bookmarks`               | Saved ViewModel and shared membership reconciliation | Optional `cursor`; both locales; no locale/status field added              |
| PUT `/bookmarks/:articleId`    | Confirmed save action                                | Empty body/request, 204 success without JSON decoding                      |
| DELETE `/bookmarks/:articleId` | Confirmed removal action                             | Empty body/request, idempotent 204 handling                                |

HTTP tests verify the complete method/path/query sequence, UTF-8 Arabic parsing, bearer headers and no redirect following. Errors are allowlisted; raw server/proxy messages are never displayed. A 401 becomes the existing AuthFailure and drives the existing session invalidation flow. Article/section 404 produce unavailable states. Network/timeout/server/invalid-response failures offer safe retry feedback.

## Loading, pagination and lifecycle

Only root sections load at Guide entry. Section/search/bookmark responses supply summaries; complete Markdown is fetched on explicit opening. Opaque cursor strings are forwarded unchanged and never decoded. There is no unsupported page-size query field: the current backend supplies 20-item pages, below its 50-item cap.

One pagination request runs per list at a time. Appended items deduplicate by article UUID, and a null cursor terminates pagination. Repeated cursor responses are rejected instead of creating loops. A 400 for an existing cursor retains a controlled reload state; the user explicitly reloads from the beginning. There is no infinite automatic restart/retry loop.

The client introduces no persistent HTTP article cache or local knowledge database. Opening an article again constructs a new reader and fetches the current detail. Lists can retain navigation state within the live route stack; session changes invalidate results and clear account-specific state, including search input, bookmarks and pending actions. Reader/source actions reject late results after disposal or owner changes.

## Bookmark reconciliation

There is no invented `isBookmarked` field or bookmark-status endpoint. Shared in-memory state distinguishes unknown, loading, saved and unsaved, with separate mutation-pending/error state. Finding an article in a bookmark page confirms saved status. Absence from the first page does not establish unsaved status; the relevant listing must be exhausted.

An article open or explicit status check scans at most three pages per action. If the answer remains unknown, the UI offers continuing the check or explicitly saving the article through idempotent PUT. A test places the target on page four: the first bounded batch leaves it unknown and the next check finds it saved. Exhausting the listing confirms absence.

Confirmed mutations update shared state and invalidate the saved-list traversal. Duplicate concurrent mutations for an article are blocked. Failures preserve confirmed state and expose retry feedback. A failed/incompatible reconciliation cursor resets traversal without falsely declaring the article unsaved. All state is session-only and discarded on logout/account changes. Mutation tests use isolated fakes/HTTP fixtures, never real device bookmarks.

## Markdown, links and Arabic

After the dependency proposal and the user's CONTINUE go-ahead, `pubspec.yaml` added exactly `flutter_markdown_plus: 1.0.12`. The lockfile added that package and transitive `markdown 7.3.1`. Existing `meta`, `path` and all other dependency versions stayed unchanged. These versions compiled with installed Flutter 3.47.5 / Dart 3.13.4.

The native MarkdownBody renderer handles headings, lists, emphasis, blockquotes, code, tables and links with theme-derived text styles and selectable text. HTML blocks are not rendered; inline HTML is inert text, with no HTML/WebView/script builders. Images are explicit text/image links and never automatically fetch embedded files or remote content. Every link uses the reader's HTTPS/no-user-info validation and the existing external URL service; unsafe/relative schemes produce safe inline feedback.

English content uses LTR and Arabic uses RTL, including summaries, reader paragraphs, lists and breadcrumbs. Existing application controls remain English with an Arabic content-language option; this phase does not translate the entire application. The English citation notice explicitly uses LTR within an Arabic reader. Text scaling remains enabled and Arabic widgets were tested at 1.5x.

Widget-test captures do not inherit Android system fonts. The Arabic capture uses a locally installed Arial fallback loaded only by the test harness; no font asset or production theme was changed. The optional `GUIDE_ARABIC_TEST_FONT` environment variable supports another installed test font. Arabic screenshot generation is skipped if no suitable test fallback is configured. Actual Android system-font rendering still needs device acceptance.

## Automated verification and build

| Check                                                                            | Result                                                                                                       |
| -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Selected Flutter service/model/repository/ViewModel/widget/routing/session tests | 44 passed, no failures or skips                                                                              |
| Backend section/current-publication integration regression                       | 13 passed, no failures or skips; isolated database removed                                                   |
| Scoped Dart formatting                                                           | 34 Dart files passed with no formatting changes                                                              |
| Flutter analysis                                                                 | Only accepted existing `calendar_reminder_service.dart:57` curly-braces info; aggregate exit remains nonzero |
| Modified backend feature report/test formatting                                  | Passed                                                                                                       |
| Tracked and new-file whitespace checks                                           | Passed                                                                                                       |
| Android debug APK using existing private configuration                           | Built successfully: `build/app/outputs/flutter-apk/app-debug.apk`                                            |

Coverage includes exact requests/204/UTF-8, nullable models, real repository session invalidation, stale responses, hierarchy and mixed/empty sections, explicit detail fetch, Markdown structures/HTML/image handling, RTL/scaling, debounce, pagination/deduplication/cursor recovery, bookmark page-four membership, failures/concurrent actions, different-account replacement/logout, source URL guards, revision notices, default Guide route composition and existing startup/logout/session regressions.

The existing KGP migration warning from Mapbox/WebRTC plugins appeared during the successful Android build. Those unrelated dependencies/configurations were left unchanged. The APK was not installed on or removed from any device.

Commands from the Flutter repository:

```powershell
flutter test --no-pub test/data/services/guide_api_service_test.dart test/ui/guide test/routing/guide_routing_test.dart test/routing/app_router_test.dart test/routing/session_routing_test.dart test/routing/session_startup_regression_test.dart --reporter expanded
flutter analyze --no-pub
flutter build apk --debug --dart-define-from-file=dev-config.json
git diff --check
```

To regenerate the fixture screenshots:

```powershell
flutter test --no-pub test/ui/guide/guide_widgets_test.dart --reporter expanded --dart-define=GUIDE_SCREENSHOTS=true
```

## Physical-device status and manual acceptance

`adb devices` returned no connected device. A read-only health request to the existing configured loopback backend was unavailable. Therefore no physical-device launch or authenticated runtime acceptance was claimed. No device authentication/storage reset, app uninstall or physical bookmark mutation occurred.

When a device is connected, preserve the existing private configuration and retained app authentication:

1. From Balamandian-API, run `npm run dev`; verify `/health` returns `ok`.
2. From Flutter, run `adb devices` and `.\tool\run_phone.ps1 -CheckOnly` to verify the actual authorized phone, backend and USB forwarding.
3. Run `.\tool\run_phone.ps1` using the existing launch workflow. Do not uninstall, clear storage or reset authentication.
4. Open Guide from the existing Home entry; verify dynamic roots and English/Arabic content selection against the authorized eight starter articles.
5. Open Library, then Library Services; verify the two UUIDs/hierarchy above and the article summaries. Open an article and check Markdown, verification, official source launching, back navigation and preserved bottom navigation.
6. Search `calendar` in English and `التقويم` in Arabic; check clear, loading/empty/retry, keyboard and RTL rendering at large device text sizes.
7. Open an article through its cited-version location and check the update notice. Reopen it to confirm current-detail fetching. Read the existing Saved list across locales without changing real bookmarks.
8. Verify light/dark appearance, scrolling, touch targets, source links and returning to Home. Save device screenshots if authorized.

Bookmark mutation/account-switch/cursor-expiry acceptance is already covered by controlled automated fixtures. Physical bookmark operations require the developer's separate explicit authorization. Multi-page real-device testing needs an approved isolated fixture corpus; do not publish production drafts to manufacture pages.

## Screenshots

These are 390 x 844 **controlled widget-fixture captures**, not connected-device evidence or the actual published corpus. They demonstrate the implemented components; fixture article placement/text is synthetic. The actual eight starter articles are retrieved only through the API at runtime.

| View                                         | Capture                                                     |
| -------------------------------------------- | ----------------------------------------------------------- |
| Guide home                                   | [guide-home.png](Images/guide-home.png)                     |
| Section with breadcrumb and summary          | [guide-section.png](Images/guide-section.png)               |
| Search results                               | [guide-search.png](Images/guide-search.png)                 |
| English Markdown reader and sources          | [guide-article.png](Images/guide-article.png)               |
| Arabic reader, 1.5x text and revision notice | [guide-article-arabic.png](Images/guide-article-arabic.png) |

## Preservation and coordination with Ali

The pre-work hash baseline included 588 Flutter files and 294 backend files, including private configuration hashes without exposing their contents. In Flutter, only four pre-existing files changed: `lib/app.dart`, `pubspec.yaml`, `pubspec.lock` and the existing route regression test. The other 584 are byte-identical. In the backend, only the feature-owned Phase 4 report and Guide integration test changed; the other 292 baseline files are byte-identical.

Original starter content, all production directives, Phase 2 dataset, Phase 3 importer, backend runtime implementation, migrations 0001-0021, schema/contract, shared GuideArticleRef/link helpers, authentication/session implementation, private `.env`/`dev-config.json`, themes, shared navigation, AI files and Scheduler are preserved. No application/recovery data was modified. There is no migration 0022, new backend dependency, production import/publication or deployment.

Shared edits requiring synchronization are the approved Flutter Markdown manifest/lock additions and the assigned MainApp Guide composition. Ali should synchronize these changes and reuse the selected renderer rather than adding another Markdown dependency. His AI slot and feature files are unchanged. Ask AI/cross-feature actions remain unavailable until joint approval and integration tests; native cold-start deep links are outside this phase. Follow the contract's Guide-first integration order, with no merge performed here.

## Remaining limitations

- Physical Android runtime, retained-session behavior and actual system-font rendering remain manual acceptance because no phone/backend was available.
- Existing calendar analysis and backend shared-contract formatting baselines remain unchanged.
- Backend cursors are process-local and lists are live; invalid cursors require controlled first-page reload. The client does not promise an edit-stable snapshot.
- Long bookmark collections can need additional explicit bounded checks; partial absence remains unknown.
- Widget captures use controlled fixtures and a test-only Arabic font fallback, not real device data or exact Android typography.
- Production source/editorial/publication review and final Guide/AI lifecycle integration remain separate approved work.

No implementation defect remains identified by the focused verification. The feature is ready for architectural review, with device acceptance and joint Guide/AI integration still pending.

## Official references consulted

- [Flutter architecture guide](https://docs.flutter.dev/app-architecture/guide) and [data-layer case study](https://docs.flutter.dev/app-architecture/case-study/data-layer): existing services, repositories and MVVM boundaries.
- [Flutter widget testing](https://docs.flutter.dev/cookbook/testing/widget/introduction) and [accessibility](https://docs.flutter.dev/ui/accessibility): controlled widget state, semantics and text scaling.
- [Directionality](https://api.flutter.dev/flutter/widgets/Directionality-class.html), [font fallback](https://api.flutter.dev/flutter/painting/TextStyle/fontFamilyFallback.html) and [FontLoader](https://api.flutter.dev/flutter/services/FontLoader-class.html): content direction and test-only font loading.
- [Dart async programming](https://dart.dev/libraries/async/async-await), [Timer](https://api.dart.dev/dart-async/Timer-class.html) and [dart fix](https://dart.dev/tools/dart-fix): async/disposal guards, debounce and scoped lint fixes.
- [Flutter Android builds](https://docs.flutter.dev/deployment/android): existing debug build workflow.
- [flutter_markdown_plus](https://pub.dev/packages/flutter_markdown_plus) and [MarkdownBody API](https://pub.dev/documentation/flutter_markdown_plus/latest/flutter_markdown_plus/MarkdownBody-class.html): package compatibility, supported structures and native renderer callbacks. Installed package/parser source was also inspected for HTML and image behavior.

The repository's skill was applied from [flutter-docs-first](../.agents/skills/flutter-docs-first/SKILL.md). Input bounds, three-page membership batches and explicit cursor recovery are project choices, not Flutter requirements.

## Complete Phase 5 file inventory

The inventory below includes this report and all feature screenshots; regenerated ignored build/cache output is excluded.

| Repository      | Change   | File                                                     |
| --------------- | -------- | -------------------------------------------------------- |
| Balamandian     | Modified | `lib/app.dart`                                           |
| Balamandian     | Modified | `pubspec.lock`                                           |
| Balamandian     | Modified | `pubspec.yaml`                                           |
| Balamandian     | Modified | `test/routing/app_router_test.dart`                      |
| Balamandian     | Created  | `Docs/Images/guide-article-arabic.png`                   |
| Balamandian     | Created  | `Docs/Images/guide-article.png`                          |
| Balamandian     | Created  | `Docs/Images/guide-home.png`                             |
| Balamandian     | Created  | `Docs/Images/guide-search.png`                           |
| Balamandian     | Created  | `Docs/Images/guide-section.png`                          |
| Balamandian     | Created  | `Docs/guide-phase5-report.md`                            |
| Balamandian     | Created  | `lib/data/repositories/api_guide_repository.dart`        |
| Balamandian     | Created  | `lib/data/repositories/guide_repository.dart`            |
| Balamandian     | Created  | `lib/data/services/guide_api_service.dart`               |
| Balamandian     | Created  | `lib/domain/models/guide_models.dart`                    |
| Balamandian     | Created  | `lib/ui/guide/guide_routes.dart`                         |
| Balamandian     | Created  | `lib/ui/guide/view_models/guide_article_view_model.dart` |
| Balamandian     | Created  | `lib/ui/guide/view_models/guide_bookmarks.dart`          |
| Balamandian     | Created  | `lib/ui/guide/view_models/guide_browse_view_models.dart` |
| Balamandian     | Created  | `lib/ui/guide/view_models/guide_session.dart`            |
| Balamandian     | Created  | `lib/ui/guide/widgets/guide_article_metadata.dart`       |
| Balamandian     | Created  | `lib/ui/guide/widgets/guide_article_screen.dart`         |
| Balamandian     | Created  | `lib/ui/guide/widgets/guide_article_tile.dart`           |
| Balamandian     | Created  | `lib/ui/guide/widgets/guide_bookmark_button.dart`        |
| Balamandian     | Created  | `lib/ui/guide/widgets/guide_breadcrumbs.dart`            |
| Balamandian     | Created  | `lib/ui/guide/widgets/guide_frame.dart`                  |
| Balamandian     | Created  | `lib/ui/guide/widgets/guide_home_screen.dart`            |
| Balamandian     | Created  | `lib/ui/guide/widgets/guide_loading.dart`                |
| Balamandian     | Created  | `lib/ui/guide/widgets/guide_locale_picker.dart`          |
| Balamandian     | Created  | `lib/ui/guide/widgets/guide_markdown_body.dart`          |
| Balamandian     | Created  | `lib/ui/guide/widgets/guide_pagination_footer.dart`      |
| Balamandian     | Created  | `lib/ui/guide/widgets/guide_saved_screen.dart`           |
| Balamandian     | Created  | `lib/ui/guide/widgets/guide_search_input.dart`           |
| Balamandian     | Created  | `lib/ui/guide/widgets/guide_search_screen.dart`          |
| Balamandian     | Created  | `lib/ui/guide/widgets/guide_section_screen.dart`         |
| Balamandian     | Created  | `lib/ui/guide/widgets/guide_section_tile.dart`           |
| Balamandian     | Created  | `lib/ui/guide/widgets/guide_sources.dart`                |
| Balamandian     | Created  | `test/data/services/guide_api_service_test.dart`         |
| Balamandian     | Created  | `test/guide_test_support.dart`                           |
| Balamandian     | Created  | `test/routing/guide_routing_test.dart`                   |
| Balamandian     | Created  | `test/ui/guide/guide_markdown_test.dart`                 |
| Balamandian     | Created  | `test/ui/guide/guide_view_models_test.dart`              |
| Balamandian     | Created  | `test/ui/guide/guide_widgets_test.dart`                  |
| Balamandian-API | Modified | `docs/guide-api-phase4-report.md`                        |
| Balamandian-API | Modified | `test/integration/guide-api.test.js`                     |

Totals: Flutter **38 new files and four modified files**; backend **two modified feature-owned files and no new files**. All prior uncommitted backend files remain present.
