# Verification — version 1.1.0

The extracted package was installed and run independently of the original prototype. Its own package lock pins the dependency tree. Runtime code depends only on React, React DOM and GSAP; there is no application context, routing library, mock repository or backend client.

## Completed checks

- Production build and TypeScript checks passed.
- Prettier/TypeScript lint passed.
- All **26 bundled asset files** passed SHA-256 integrity verification.
- Playwright with Microsoft Edge: **37 passed, 15 intentionally skipped**, zero failures. The five interaction journeys run once in the mobile-light project; the other three projects run all eight screen-layout checks.
- All eight screens were captured at 412×915 light, 412×915 dark, 360×800 light and 1280×900 desktop: **32 reference PNGs**.
- The initial handoff received a full light/dark visual review. For version 1.1.0, the new olive was visually checked on splash, campus, assistant, entry and narrow community screens, including light/dark appearances; all 32 reference images were refreshed.
- Additional 320px and 390px checks found no horizontal page overflow across the eight screens.
- Image loading, Inter font selection, lack of external asset requests and absence of browser page errors were checked for every captured screen.
- Required-field errors, focus on the first invalid field, password visibility, password clearing, and callback-only submission were verified.
- Account setup was checked for neutral read-only SIS slots, no editable identity fields, local photo selection/removal, invalid-file feedback and bio submission.
- Guest and sign-in actions emit UI events without navigating into a fabricated Home screen or persisting a session.
- Coin movement and the curved transition were exercised with motion enabled. Rapid repeated taps did not skip a tour screen. Reduced motion disables the coin animation and decorative movement.
- All preceding UI updates are retained in this independent handoff; the latest olive asset change is scoped to this folder. Other applications and prepared backend code are outside this package.

The original branch drawing was removed and replaced with the byte-identical supplied transparent PNG. Every olive placement shares the same component and keeps its existing motion, tint and opacity.

## References

Use `screenshots/mobile-light/` and `screenshots/mobile-dark/` as the main visual reference, `screenshots/narrow/` for smaller-width behavior and `screenshots/desktop/` for the centered review frame. These images contain no sample identity or demo credential data.

## Practical limits

This validates the React UI handoff in Edge on Windows. The Flutter port has not been implemented or validated by this package. Its eventual iOS/Android keyboard behavior, text scaling, safe areas, physical-device rendering and platform photo picker need testing during the Flutter work. The package intentionally does not verify university credentials, retrieve SIS records, upload photos, save a profile or authenticate a session.

## Independent package audit

All relative TypeScript/React imports resolve inside this folder. Runtime dependencies are limited to React, React DOM and GSAP. A runtime-source scan found no storage access, API requests, Supabase client, demo-fill controls, sample SIS records or hardcoded accepted credentials. The supplied olive PNG is byte-identical to the upload. The distributable ZIP excludes installed dependencies, build output, temporary test results and machine-specific files; install dependencies using the supplied lockfile.
