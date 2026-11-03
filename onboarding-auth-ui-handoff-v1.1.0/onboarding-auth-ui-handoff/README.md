# Balamandian — onboarding and authentication UI handoff

Version **1.1.0** · Independent frontend package.

This is a self-contained **React/TypeScript UI reference for a later Flutter implementation**. It extracts the approved startup screens from the current `balamandian-onboarding-v3` prototype. It is not a Flutter application. All preceding screen updates are included. This independent version also replaces the decorative olive drawing with the latest supplied branch asset.

For sharing, use the adjacent `onboarding-auth-ui-handoff-v1.1.0.zip`. It contains this folder's source, documentation, assets and screenshots, excluding generated dependencies, build output and temporary test results. Extract it, then follow the commands below.

## Included screens

| Screen key | Screen | Included interactions |
| --- | --- | --- |
| `splash` | Blue university splash | Capital Balamandian wordmark, crest coin flip, slow decorative motion, timed advance |
| `campus` | Find your way / Feel at home | Actual main-campus photo fading into the canvas, yellow Continue, Skip, progress navigation |
| `community` | Your people / Your campus | Actual club-fair photo, olive decoration, green Continue |
| `assistant` | Your Campus Assistant | Supplied robot beside the native assistant card, Schedule / Notes / GPA tiles, blue Get started |
| `getting-started` | Entry choices | Navy library-photo backdrop, animated crest, yellow login action, green signup link and guest entry |
| `sign-up` | Create your account | SIS ID, password visibility, required-field errors, switch to sign-in |
| `sign-in` | Welcome back | Email or SIS ID, password visibility, required-field errors, switch to sign-up |
| `account-setup` | A little about you | Optional photo and bio; display-only name, major and faculty supplied by the host |

Every screen supports light and dark appearances. The approved rounded controls, university colors, Inter typography, original photos, Phosphor vector icons, slow olive/ray movement and coin animation are retained. Onboarding has progress bars, with no visible numeric counters or footer back arrows. The splash has no Skip button.

## Run it

Use Node.js 22 or newer and npm. Open a terminal **in this folder**:

```sh
npm ci
npm run dev
```

Open [the local UI preview](http://127.0.0.1:5176). The review controls above the UI let you open any screen, switch theme and inspect the disabled/pending state. These controls are not part of the application design.

For an uncluttered screen, use a URL such as:

```text
http://127.0.0.1:5176/?canvas&screen=campus&theme=light
http://127.0.0.1:5176/?canvas&screen=account-setup&theme=dark
http://127.0.0.1:5176/?canvas&screen=splash&hold
http://127.0.0.1:5176/?canvas&screen=sign-in&error
http://127.0.0.1:5176/?canvas&screen=sign-in&pending
```

The `hold` option stops automatic splash navigation for visual review. Without it, the splash advances normally. The error URL displays generic UI copy, not a response from a service.

```sh
npm run build          # TypeScript and production build
npm run preview        # Serve the production build on port 4176
npm run lint           # TypeScript and formatting checks
npm run assets:verify  # Check bundled files against their SHA-256 manifest
npm test               # UI checks and screenshots; Microsoft Edge required
```

Playwright starts port 5176 automatically when needed. Tests require installed Microsoft Edge; another browser can be configured in `playwright.config.ts`. Dependency installation needs internet, but **the running UI loads its images, fonts and icons locally**. Build output is in `dist/`; it is generated and is not the source to port.

## Folder map

```text
src/
  index.ts                    Public component/types and stylesheet imports
  types.ts                    UI inputs and event contracts
  OnboardingAuthUI.tsx         Controlled screen flow, artwork and transitions
  screens/Access.tsx           Sign-up, sign-in and account-setup forms
  components/OliveBranch.tsx   Supplied branch silhouette with theme tint and slow motion
  components/Brand.tsx         Crest, wordmark and coin
  components/IconButton.tsx    Accessible 48px icon control
  components/Icons.tsx         Exact local Phosphor SVG paths as React components
  styles/                     Fonts, scoped reset, light/dark tokens and screen CSS
  assets/
    images/                   Campus, fair, library, university branding and robot
    fonts/                    Four Inter weights and SIL Open Font License
    icons/                    Twelve portable original Phosphor SVGs and MIT license
    illustrations/            Supplied olive PNG and sun-ray SVG for the Flutter port
preview/                      Standalone UI review host; no sample identities
docs/
  flutter-porting.md          Widget mapping, dimensions, motion and event boundaries
  assets.md                  Asset usage, cropping and attribution
  design-tokens.json          Portable color, typography, layout and motion values
  asset-manifest.json        Asset filenames, sizes and integrity hashes
  verification.md            Verification results and practical limits
  screenshots/               Generated visual references by viewport/theme
tests/                        UI journeys, layouts and asset checks
scripts/verify-assets.mjs     Asset integrity check
```

## Use the UI from React

Import `OnboardingAuthUI` and its types from `src/index.ts`. That entry also loads the required styles and local fonts. Vite resolves the relative image imports; there are no absolute asset URLs or references to the original repository. Theme tokens are scoped to `.onboarding`, so they do not change the host application's theme.

`screen` and `onNavigate` are controlled by the consuming application. The tour itself requests normal UI navigation. Sign-up, sign-in, guest entry and profile submission emit callbacks; they do not claim success or change an account. The public contract is in `src/types.ts`:

| Input / event | Meaning |
| --- | --- |
| `screen`, `onNavigate(screen)` | Current screen and requested local UI navigation |
| `appearance` | `light` or `dark`; defaults to light |
| `onSignUp({identifier, password})` | Valid nonempty form submitted; host decides what happens next |
| `onSignIn({identifier, password})` | Valid nonempty form submitted; host decides what happens next |
| `onGuest()` | Guest entry requested |
| `onSetupSubmit({bio, photo})` | Bio string and selected `File` or `null`; no upload or saving |
| `identity` | Optional display-only `{name, major, faculty}`; absent values show “Provided by SIS” |
| `pending` | Host-controlled waiting state; disables form controls and navigation |
| `formError` | Optional host-supplied form message, announced as an alert |
| `holdSplash` | Review-only option, false by default |

After the host accepts sign-up, it can select `account-setup`. After accepted sign-in or completed setup, the host can leave this UI and navigate into its own application. **No Home screen is included.** The review host deliberately stays on a submitted form and reports that no service is connected; select `account-setup` in its review control to inspect it directly.

Passwords exist only in the mounted form, are passed once to the supplied callback and are cleared after submission or leaving the form. This package does not log, persist or transmit them. Do not record callback payloads in analytics. Photo previews and bio edits are held only in component memory and reset when the screen unmounts.

## Scope for the Flutter handoff

Start with [the Flutter porting guide](docs/flutter-porting.md), then [asset usage](docs/assets.md). The source CSS is the exact visual specification when a table cannot express a responsive detail. Screenshots are visual references, not screen-sized image assets to use in place of widgets.

This handoff includes no mock accounts, sample people, demo passwords, mock SIS records, simulated sign-in, fake assistant responses, database clients, API routes, Supabase setup, storage layer, session persistence, Home UI or other application sections. Static onboarding headlines and descriptions are product copy. The approved campus/fair photos naturally contain people and are preserved as photographs.

Compared with the review prototype, the three stock portrait avatars and fabricated assistant conversation were removed. The tools illustration uses descriptive feature copy, and account setup has neutral empty SIS slots. These are the intentional content changes needed to make this a UI-only handoff without mock data.

## Latest visual revision

The library entry now follows the supplied navy reference in both appearances. Log in with SIS is the yellow primary action; signup is an inline green link, with guest entry underneath. Wordmarks have no trailing yellow dot. The second and third onboarding captions were removed. The third illustration uses the supplied transparent robot, with no sparkle icon or fabricated live assistant output. `styles/startup-refresh.css` contains these layout rules and loads after the base screen stylesheet.

## Supplied olive branch

Every olive decoration in this package now uses `src/assets/illustrations/olive-branch.png`, copied unchanged from the latest upload. `OliveBranch.tsx` uses its transparent silhouette as an alpha mask, preserving every leaf while applying the existing color and opacity for each screen. Its natural aspect ratio is 3:1; it is fitted without stretching. The old drawn branch SVG is removed. For Flutter, use the same PNG with `Image.asset`, `BoxFit.contain` and `BlendMode.srcIn` when tinting. See `docs/assets.md`.

This folder runs independently after `npm ci`. Authentication and profile actions are callbacks only, with no mock account, hardcoded accepted credential, API client, server, database, session persistence or other application screen.
