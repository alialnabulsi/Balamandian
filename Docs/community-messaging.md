# Community & Messaging

Stage 1 establishes the social feed, stories, content creation, community privacy and durable activity notifications. The Flutter and API changes live on `feature/community-messaging`, based on client `2813517` and API `5062ef2`.

Stage 2 adds direct chats and private groups to the same branches. The accepted Stage 1 commits are `13a532e` on Flutter and `3d2a73b` on the API. [Stage 2 implementation and verification](community-stage-2-report.md) · [Messaging API](../../Balamandian-API/docs/messaging.md)

Stage 3 adds official university channels and course-linked study rooms to the same conversation engine. The accepted Stage 2 commits are `3c826a9` (Flutter) and `3a28d49` (API). [Academic spaces and operator setup](../../Balamandian-API/docs/academic-spaces.md)

| Stage | Product scope | Foundation and boundaries |
| --- | --- | --- |
| 1. Community | For You and Following, image posts, 24-hour stories, comments and one level of replies, saved posts, external sharing, follows and approvals, blocking, muting, reporting and in-app activity. | Community endpoints reuse application UUIDs, opaque bearer sessions and the approved public profile projection. PostgreSQL supplies access rules, durable activity, media metadata and reporting. Private object storage is behind an authenticated API. |
| 2. Messaging and groups | One conversation engine for direct threads and private groups. Message requests, groups with an owner and multiple administrators, invites, configurable permissions, delivery/read state, typing, presence, internal post sharing and story replies. | Use the existing block gate and policy ownership. A shared post or story carries its application UUID and is checked again when opened. Conversation roles and membership are separate from SIS identity. |
| 3. Channels and study rooms | Verified departments publish announcements and control discussion. Course-linked rooms provide study collaboration, notes and resources. Authenticated members may discover and join both without enrollment. Only verified students may create study rooms. | Extend the conversation model through membership and policy. Reuse private media authorization for documents once their MIME, limits and retention are defined. Establish separately authenticated moderator/administrator identities and a review workflow. Web administration follows the demo. |
| 4. Calls and demo readiness | Direct, group and study-room audio, integration, performance and native QA. Official channels never accept calls. | Gate calling by verified conversation type, membership, block state and consent. Evaluate transport and OS delivery in that stage. |

Institutional roles carry equal base access. Verified student status gates study-room creation. Joining academic spaces is independent of department, course enrollment and institutional role. Platform operators and conversation administrators have distinct authorization.

Stage 2 stores direct and private group conversations, member roles, ordered history, pending requests and exact receipt acknowledgements in PostgreSQL. It reuses the Community media upload and authorized download routes. A client retries a failed send with the same UUID and keeps unsent text and attachments in the current composer. The inbox and active conversation synchronize using bounded authenticated HTTP waits and the existing PostgreSQL notification listener. Typing and recent online status use short in-memory leases.

An approved direct chat continues after new-contact preferences change. Blocking hides its history and media until unblocked. Shared group history filters blocked authors and removed members lose all access. Joining a group exposes messages from acceptance onward. Shared posts and story replies carry references and are checked against current Community access.

For development, keep the existing `dev-config.json` and default API port 3000. Run `npm run db:migrate` before starting the updated API, then launch Flutter with `flutter run --dart-define-from-file=dev-config.json`. The isolated demo on port 3101 also seeds a photo-walk group, incoming requests and direct threads with photos, a shared post and reactions.

## Stage 3 academic spaces

- Open **Discover** from Messages to find official department channels or study rooms. The inbox type filter separates direct messages, private groups, channels and rooms. A current SIS course is required to create a room. Members can join existing rooms without course enrollment.
- Academic spaces have separate announcements and discussion. Administrators publish, edit, remove and pin announcements. Discussion can be open, administrators-only or locked. Joined members can browse existing content. Leaving or removal revokes access to history and files.
- Study tools organize resources, notes, questions and sessions. Rooms support pinned resources and notes, accepted answers, and opt-in in-app session reminders. Files have protected previews and an Android download or share action.
- The SIS service supplies the department and course catalog. Run `npm run academic:sync` after migrating and after catalog updates. The isolated demo seeds fictional channels and study rooms without SIS access. Stage 4 can authorize calls through `allowsAudio`, active membership, block checks and consent. Official channels are excluded by the conversation kind.

The Stage 3 Android review includes six native light and dark captures of discovery, announcements, course selection, a PDF preview and a resolved question. [Desktop screenshot ZIP](../../../community-stage-3-final-screenshots.zip)

## Stage 4 voice and release readiness

Direct chats, private groups and study rooms can carry audio-only calls. Members choose to answer or join. The client uses WebRTC for real audio and the existing authenticated API for call state and signaling. Calls can be minimized and include audio routing, participant indicators and durable history. Incoming ringing requires the app in the foreground. [Voice calling setup](../../Balamandian-API/docs/voice-calls.md)

Apply `0011_voice_calls.sql` through `npm run db:migrate` and continue with the existing API port 3000 and Flutter `dev-config.json`. Keep the private R2 reader configured for previously uploaded R2 objects even when new uploads use PostgreSQL. [Media and release configuration](../../Balamandian-API/docs/community.md)

Android uses the release keystore configured in the ignored `android/key.properties`. Verified HTTPS App Links still need a controlled host and an association file for the final package and signing certificate. The installed custom-scheme fallback retains the existing authenticated post lookup. [Android release setup](https://docs.flutter.dev/deployment/android) · [App Links setup](https://docs.flutter.dev/cookbook/navigation/set-up-app-links)

## Stage 1 client

- Home uses a lazy sliver feed, bounded thumbnail decodes, near-end pagination and pull-to-refresh. Changing feed mode preserves the story rail. Loading, empty, connection and retry states are distinct. Feed cards include the shared member identity and links to profiles.
- The story rail uses asymmetric campus cards with an accessible unseen state. It shows the current member and eligible followed accounts, or the current member alone. Own entry opens Add story or a choice of View and Add. Profile stories honor the same audience checks. The viewer supports previous/next, progress, pause, loading, author viewer lists, like and delete/report actions.
- The shell’s central Create opens the shared photo composer. A post supports one to six images, ordered preview, gallery and camera, caption and `@username` mentions. A story uses one image with an editable text overlay. Drafts and uploaded image IDs are retained while the composer is open. The composer confirms accidental discards and reuses successful uploads on retry. Drafts are kept in memory for the lifetime of the route.
- The post detail opens a zoomable image viewer, handles own edit, archive, restore and deletion, and opens a draggable comments sheet. Comments expose a thread, author navigation, reporting and optimistic likes. Reports have a category and optional note. Notification mentions resolve exact generated usernames server-side.
- The profile keeps its existing identity header, account sheet and social controls. It displays the live post count and an authorized image grid, plus Saved and Archive for the owner. Follow requests use the existing Follow action and an inbox under Settings. Profile safety actions offer block, mute and report.
- Activity shows an unread badge, durable history, pagination, per-item and bulk read actions, and content navigation. Foreground long polling reconnects with backoff. An access revision also makes the app discard old visible community reads on remote policy changes. The app uses ephemeral memory for private community image loading. A recipient who already saved a screenshot can retain that external copy.

The `CommunityRepository` owns session-bound API access and read invalidation. Feature ViewModels own loading and mutations. Dedicated widgets compose the Inter theme, shell, avatar, loading and feedback components. The app retains the approved navigation and Map branch. URLs are passed through the router and retrieved with the same bearer authorization as an ordinary post view.

## Run locally

For the regular backend use the existing ignored `.env`, configure a loopback PostgreSQL 18 connection and existing SIS/email integration, then run `npm run db:migrate` and `npm start`. Leave `COMMUNITY_MEDIA_DRIVER=postgres` for credential-free local media, or use the private R2 setup in the API contract. The default Flutter debug origin is `http://10.0.2.2:3000`. For a USB device use `adb reverse tcp:3000 tcp:3000` and `--dart-define=API_BASE_URL=http://127.0.0.1:3000`.

For a standalone demo with fictional data, use a local database role that can create an isolated database. Configure the API `.env` with development PostgreSQL credentials, set `COMMUNITY_DEMO=1` in the API shell, run `npm run build`, then start `node --env-file=.env test/demo/community-demo.js`. It creates or reuses its marked `balamandian_community_demo` database, binds only to loopback port `3101`, and seeds illustrated community content from client assets. It uses fictional login fixtures and leaves the normal API entry point and development accounts separate. Start Flutter with `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3101`. The fictional accounts are `demo.aya`, `demo.rami`, `demo.nour`, `demo.mira`, `demo.sami` and `demo.lina`. Their fixture password is `Campus-demo-2026`. Aya starts with an illustrated feed, an active story, saved content, activity history and pending follow requests.

For verified Android App Links, choose an HTTPS domain you control. Set Gradle property `communityLinksHost` to its host and Flutter `COMMUNITY_LINK_ORIGIN` to its HTTPS origin. Serve `/.well-known/assetlinks.json` with the final application ID and signing certificate SHA-256 fingerprint. Configure `/posts/{uuid}` on that domain to guide browser users to the app without displaying private content. The packaged fallback is `balamandian://post/posts/{uuid}`. The API always rechecks authorization. Domain association and final signing require deployment configuration. [Flutter App Links setup](https://docs.flutter.dev/cookbook/navigation/set-up-app-links)

Run `flutter analyze --no-pub` and `flutter test --no-pub`. The tests generate light and dark widget captures under `build/community-verification/`. The local API tests and the retained integration workflow are described in `Balamandian-API/docs/community.md`.

See the [Stage 1 implementation and verification report](community-stage-1-report.md) for results, remaining configuration and the Stage 2 handoff.
