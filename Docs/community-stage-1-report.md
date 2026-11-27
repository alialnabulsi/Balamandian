# Community & Messaging Stage 1 delivery

26 November 2026. Both repositories use `feature/community-messaging` based on their synchronized `dev` heads. Client base `2813517d1efb114921fa12a8e9d184b9d93e358c`. API base `5062ef2c742ace1bbf50e10d099c3de0044763f7`. The changes are left in the working trees for review.

Stage 1 adds the social experience to Home and existing profiles. It uses the application session, real PostgreSQL data and authenticated image access. The local fixture flow uses the same HTTP, ranking, persistence, notification and authorization code as the application server. It substitutes fictional institutional identities and the PostgreSQL media driver.

| Slice | Implemented and exercised |
| --- | --- |
| Home | Personalized For You, chronological Following, conditional pagination, impressions, refresh, error and offline feedback, and feed hiding and muting. Feed ranking and diversity are covered by deterministic fixtures and real multi-user feed queries. |
| Stories | Campus cards, shared composer, gallery/camera entry, image preview and text overlay, per-author viewing, progress and pause, story audiences, views, likes, reports and 24-hour expiry. Story access and expiry were checked through the PostgreSQL fixture API. |
| Posts and profiles | Multi-image selection and ordering, publish/retry, edit, delete, archive/restore, comments, likes, saves, share/copy, authorized post links, public/own grids and counts. Android published a fixture photo using the OS picker. A second member got it in the feed, fetched its WebP and liked it. |
| Relationships and safety | Private accounts, follow requests, approve/decline and cancel, block/unblock, independent post/story mutes, interaction preferences and confidential reports. Multi-user tests cover loss of saved, feed, detail and media access after privacy changes and blocks. |
| Activity | PostgreSQL history, grouping, durable deduplication, unread count, read actions and foreground sync. The Android badge changed from one to two while the app remained open after another member liked its post. |

The master specification covers local commands, demo logins and App Links configuration. The API contract covers routes, constraints, storage settings, notification semantics and the ranking formula. [Master specification](community-messaging.md) · [API contract](../../Balamandian-API/docs/community.md)

For You scores at most 240 eligible posts from the last 30 days using recency, follows, viewing history, capped engagement and recent author affinity. At each position it looks up to 12 candidates ahead to avoid repeating recent authors and rechecks eligibility on every page. The deterministic ranking fixture verifies the effects of follows, affinity and viewing history as well as author diversity. The HTTP fixture exercises eligibility and pagination against PostgreSQL. Following uses a chronological database cursor. [Ranking algorithm and evaluation](../../Balamandian-API/docs/community.md#feed-ranking)

## Implementation decisions

- Native image selection and a shared composer support both creation paths. Draft media remains in memory for the open composer. A timed-out publish can retry with the same entry and uploaded IDs.
- Private media has two bounded WebP derivatives. PostgreSQL stores metadata in both storage modes and provides a local `bytea` driver. R2 is available via a private S3-compatible bucket. Each download is authorized by the API, including requests made from saved posts and shared links.
- The access revision is durable and rotates on relevant policy changes. PostgreSQL signals are transient. Bounded foreground long polling reads committed rows and checks sessions again before delivery.
- The Flutter session repository rejects responses superseded by logout and bounds pending storage writes. Logout waits for the old write before deleting the credential record. Shared post navigation carries a validated post path through the authentication routes so repeated router refreshes retain the same destination.
- Stage 1 uses one level of comment replies. Post comments and story likes can be controlled per account. Story preview editing includes image replacement and text overlay. Reports retain text and reference evidence for future review with separate administrative identities.

## Final product refinement

- Home uses shorter asymmetric Campus Moments cards, a single unseen marker, compact tabs and a quick-actions menu beside the story rail. This clears the scroll area while retaining the shell's bottom navigation and top-bar actions.
- Feed and post detail share a media-first layout with action counts, a distinct bookmark position, expandable captions and double-tap likes. Detail and Activity use solid reading surfaces. Opening a swiped carousel now retains the selected photo. Post and comment controls expose their action and count together in accessibility labels.
- The post composer uses a single main preview with a selectable, reorderable image strip and persistent publishing controls. The shared story editor and viewer use the same portrait framing and text placement. Story timing begins when Flutter decodes the first image frame. Returning to the first story respects reduced motion, and request generations prevent an old view from replacing the current one.
- Comments open at a shorter snap point and expand for typing. The thread includes timestamps, a parent excerpt and separate entry points for replying or reading replies. Comment and reply drafts now stay attached to the correct conversation.
- Activity separates Today, Yesterday and Earlier. Event icons and optional post or story thumbnails give each row context alongside its unread state. The authenticated inbox includes a preview identifier only for currently visible content. Image requests pass through the existing media access check.
- The existing profile identity and actions lead into a tighter grid with multi-photo markers and visible Saved and Archive shortcuts. Privacy and follow-request views use the same solid surface as Activity.

## Verification and artifacts

- Applied `0004_community.sql`, `0005_community_visibility.sql` and `0006_community_notification_dedup.sql` in sequence to the configured local PostgreSQL 18 database. The retained integration suite migrated a new isolated database from `0001` and checked repeat migration behavior.
- Final Flutter verification passed 402 tests in 46 files, with zero failures or skips. Static analysis found no issues. Dart formatting checked 282 files with zero changes. New regressions cover carousel position, separate comment drafts on a narrow screen with a simulated keyboard, and offline recovery. The suite retains both story entry points and session concurrency and storage timeout coverage.
- The API passed type checking, linting, formatting and compilation. All 42 unit tests and all six retained PostgreSQL integration results passed. The integration runner counts one parent and five cases. It covers pagination across changes, privacy transitions, blocks, cross-account cursor rejection, authorized media and inbox previews, report confidentiality, story cleanup and notification synchronization. The refinement used the existing schema.
- The final Android debug build succeeded for x86-64 and ARM64. Native captures used the same isolated Pixel 8 x86-64 emulator data image under `build/community-verification/android-sandbox/`. The loopback demo returned 26 posts from six fictional authors over two ranked pages. The Android picker supplied three photos for an ordered post and one photo for an illustrated story. A second account then fetched and saved the post, and the API confirmed deduplicated activity, edit and reorder, archive and restore, and deletion of the temporary fixture post. A pending follower received a denial when fetching its media. [Native and HTTP proof](../build/community-verification/refinement-native-api.json)
- The earlier native smoke confirmed live unread updates and continuation of a cold shared link through sign-in. The final Android build confirmed the spoken comment label and count, story pause and resume, previous and next controls, timed completion and a peer story like. Activity opened populated follow requests. Declining a request updated the API, and the fictional requester could submit it again. [Native interaction proof](../build/community-verification/refinement-native-controls.json)
- Verification logs are under `build/community-verification/` with the `refinement-` prefix. The final PNGs are in `build/community-verification/final-screenshots/`. [Desktop screenshot ZIP](../../../community-stage-1-final-screenshots.zip)

| Area | Final native screenshots |
| --- | --- |
| Home and Campus Moments | [Light](../build/community-verification/final-screenshots/01-home-light.png), [dark](../build/community-verification/final-screenshots/02-home-dark.png) |
| Stories | [Own-story menu](../build/community-verification/final-screenshots/03-own-story-menu-dark.png), [viewer](../build/community-verification/final-screenshots/04-story-viewer-dark.png), [composer](../build/community-verification/final-screenshots/07-story-composer-light.png) |
| Posts | [Create menu](../build/community-verification/final-screenshots/05-create-menu-light.png), [multi-image composer](../build/community-verification/final-screenshots/06-post-composer-light.png), [detail](../build/community-verification/final-screenshots/08-post-detail-dark.png) |
| Discussion and activity | [Replies](../build/community-verification/final-screenshots/09-comments-replies-dark.png), [inbox](../build/community-verification/final-screenshots/10-activity-light.png) |
| Profile and privacy | [Profile grid](../build/community-verification/final-screenshots/11-profile-grid-dark.png), [Saved](../build/community-verification/final-screenshots/12-saved-posts-dark.png), [settings](../build/community-verification/final-screenshots/13-privacy-settings-light.png), [follow requests](../build/community-verification/final-screenshots/14-follow-requests-light.png) |

## Remaining configuration and limits

- Live R2 credentials and a private bucket were unavailable. Local upload, normalization, authorization and cleanup were exercised. Live R2 signing, connectivity and storage behavior still need validation against the configured bucket. This work provisioned no external infrastructure.
- Verified HTTPS App Links require the final domain association, application ID and signing certificate. Release build, real SIS/email delivery, physical phones, camera capture and OS push remain outside the verified fixture coverage.
- The retained integration workflow leaves its fixture databases intact. The preexisting database integration suites use destructive teardown and were excluded under the data preservation requirement. Ranking quality and capacity at campus scale need representative usage and query plans. Ranking snapshots and request budgets are per process.
- Drafts last for the current composer. Story editing covers image replacement and text overlays. The report queue has persistent state and confidential evidence for the future admin workflow. Social sharing to other Balamandian members and story replies belong to Stage 2.

Stage 2 can build conversation membership and permissions around the existing application UUIDs and bilateral block rule. Reuse the media metadata boundary with conversation-specific permission checks and the durable notification transaction model for conversation events. Shared post and story references must reauthorize on open. The Stage 1 schema contains no conversation, presence, calling or later-stage role records.

## References

- Flutter separates widget composition, view state and data access. Lazy slivers limit feed work, and a draggable sheet keeps comment scrolling attached to sheet movement. The first decoded image frame controls story playback timing. [Flutter architecture](https://docs.flutter.dev/app-architecture/guide) · [DraggableScrollableSheet](https://api.flutter.dev/flutter/widgets/DraggableScrollableSheet-class.html) · [Image.frameBuilder](https://api.flutter.dev/flutter/widgets/Image/frameBuilder.html) · [App Links](https://docs.flutter.dev/cookbook/navigation/set-up-app-links)
- The API applies Express resource limits and error boundaries. Notifications rely on PostgreSQL commit semantics. Sharp normalizes images before the private storage adapter receives them. [Express 5 API](https://expressjs.com/en/5x/api/) · [Node 24 API](https://nodejs.org/docs/latest-v24.x/api/) · [PostgreSQL NOTIFY](https://www.postgresql.org/docs/18/sql-notify.html) · [Sharp input options](https://sharp.pixelplumbing.com/api-constructor/) · [Cloudflare R2 S3 SDK](https://developers.cloudflare.com/r2/examples/aws/aws-sdk-js-v3/)
