# Stage 2 messaging and private groups

26 November 2026. The accepted starting points were Flutter `13a532e` and API `3d2a73b` on `feature/community-messaging`. Both branches contain the Stage 2 changes for review.

| Area | Implementation |
| --- | --- |
| Inbox | Recent conversations, direct and group identity, previews, search, requests, pinned conversations, archives, mute and mark-unread controls. |
| Conversation | Text and emoji, up to six photos, shared posts, story replies, reply jumps, reactions, forwarding, message search, edits, removal and reports. The composer keeps the current draft and uploaded IDs on failure. |
| Private groups | Identity and photo, invitations with consent, owner, administrator and member roles, configurable send, invite, edit and pin permissions, moderation, ownership transfer, leave and close. |
| Community | Profile Message action, member search with compose, internal post sharing alongside external sharing, story replies, access checks on original references, and messaging privacy in Settings. |
| Sync and safety | Durable history and receipts, bounded foreground waits, typing and recent presence, per-conversation unread, confidential reports, and the existing PostgreSQL Activity store. |

## Design and policy

Direct and private groups use the same conversation, membership and message engine. PostgreSQL serializes sends per conversation, which gives sequence-keyed history and durable client-ID retries. The existing PostgreSQL listener wakes conditional HTTP requests. Each request reads committed state and checks the bearer session again before returning. This fits the current process model and the existing Flutter HTTP client. It avoids an additional connection protocol or infrastructure dependency while retaining replay from PostgreSQL. [API and protocol contract](../../Balamandian-API/docs/messaging.md)

`0007_messaging.sql` adds the shared engine, group permissions, private attachments and notification integration. `0008_messaging_receipts.sql` records acknowledgements for specific fetched messages, so receiving a newer page cannot produce delivery badges on history the recipient never fetched. Sending is an attempt in progress. Sent is the server’s committed acknowledgement. Delivered is an eligible recipient’s explicit acknowledgement of fetched message IDs. Read is an acknowledgement from the focused thread. Group receipts identify at least one eligible recipient. Individual direct receipts respect both participants’ preferences.

Existing accepted chats continue after audience changes. A pending request allows one text or story reply. A bilateral block hides direct history and media and filters blocked authors in shared groups. Private group membership starts when an invitation is accepted. It grants history from that point and ends access on removal. These rules also apply to attachment downloads and quoted source messages. Shared posts and story replies remain references and can become unavailable when the original changes.

Use the accepted developer configuration and port 3000. No new environment variables are required. In `Balamandian-API`, run `npm run db:migrate` and `npm start` with the existing `.env`. In the Flutter workspace, run `flutter run --dart-define-from-file=dev-config.json`. The existing fictional demo launcher on port 3101 seeds a photo-walk group, direct threads with images and a shared post, and requests. [Local workflow and roadmap](community-messaging.md)

## Verification

The retained backend tests create separate fictional PostgreSQL databases and keep them after closing connections. The messaging scenarios check uniqueness, policy gating, concurrent retry, attachment access, exact receipts, history and search, conditional waits, typing, presence, session revocation, invitations, administration, ownership transfer, membership removal, reference reauthorization and blocking. The same run includes the accepted Community regression scenarios.

- Flutter passed 404 tests across 47 files with zero skips. Static analysis reported no issues. Dart formatting checked 296 files with zero changes. The Android debug APK built for x86-64 and ARM64. The build emitted a Kotlin Gradle plugin migration warning for existing dependencies.
- The API passed TypeScript, ESLint and Prettier checks, plus 44 unit tests. The retained PostgreSQL runs passed four messaging scenarios and all five Community scenarios, with 11 outcomes including the two parent suites.
- The local PostgreSQL 18 migration ledger accepted `0007` and `0008` in sequence. The retained suite also checked repeated migrations against a fresh schema. The accepted migration files keep their original checksums.
- On the isolated x86-64 Pixel 8 emulator, Aya accepted a request and created a private group. An independent Rami session used the actual loopback API. Android rendered a live message and acknowledged its exact ID as delivered and read. Rami fetched both photos Aya sent and accepted the invitation to the Android-created group. Android recovered a message sent while backgrounded. Rami verified the original references and accompanying text for a story reply and a shared post sent from Android. [Native proof](../build/stage2-verification/native-live.json)
- The local demo SQL plan sampled a seven-item authorized history query at 17.38 ms. Fifteen calls to the existing inbox summary query had a local median of 1.93 ms. These are small-fixture measurements. [Query sample](../build/stage2-verification/query-sample.json)
- The desktop ZIP holds 22 native 1080 × 2400 PNGs covering both themes, inbox and request states, direct and group threads, composition and media, community sharing, group administration and messaging privacy. [Native Android screenshots](../../../community-stage-2-final-screenshots.zip)

## Remaining limits

- App-process drafts survive retries and foreground transitions while the conversation editor stays open. Pending sends have no persisted OS background queue. Background push is deferred.
- Forwarding covers text and currently authorized post references. Photos can be sent as new authorized attachments. Story references stay tied to their original replies.
- The server uses authenticated transport and access checks. End-to-end encryption is outside this stage. Last seen and typing are process-local and expire. Live R2, verified HTTPS App Links, release signing and physical-device verification remain open.
- The database uses indexed sequence paging and word search. The local fixture results represent a university demo workload. Production-scale latency and capacity remain unmeasured.

## Handoff

Stage 3 can add channel and study-room conversation kinds and capability policies to the same membership, sequence, read, media, reporting and synchronization contracts. It should add verified departmental ownership, discoverable membership and student-only room creation as explicit server authorization. Announcement and discussion permissions belong to the relevant conversation capability. Stage 4 audio can authorize invitations and media signaling against conversation membership, block state and an explicit calling capability. Official channels should never receive it.
