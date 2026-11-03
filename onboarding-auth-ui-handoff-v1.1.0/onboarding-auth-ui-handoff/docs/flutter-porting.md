# Flutter implementation guide

## Porting order and boundaries

1. Copy `src/assets/` into the Flutter application's asset directory and register the images, SVGs and font weights in `pubspec.yaml`.
2. Translate `styles/theme.css` and `design-tokens.json` into a theme/token class. Use Inter explicitly on both platforms.
3. Build reusable crest/coin, buttons, progress bars, form fields and decorative artwork.
4. Port the eight screens. Keep forms independent from navigation and services, receiving values and emitting callbacks.
5. Connect the host application's real navigation and identity later. Name, major and faculty are display-only. Only photo and bio can be edited on account setup.

There is no Dart application or backend implementation in this package. React is an executable visual reference. Existing code outside this folder is not needed to run it.

## Assets and fonts

If the supplied `src/assets/` tree is copied to Flutter's `assets/`, use:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/icons/
    - assets/illustrations/
  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
          weight: 400
        - asset: assets/fonts/Inter-Medium.ttf
          weight: 500
        - asset: assets/fonts/Inter-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Inter-Bold.ttf
          weight: 700
```

Keep the font and icon license files in the distribution. Use `Image.asset` for photos and an SVG renderer such as `flutter_svg` for the supplied vectors. Choose a version compatible with the receiving project. The original SVG files let you match the exact Phosphor shapes without substituting Material icons. Tint the vector using the applicable theme color; preserve duotone path opacity `0.2`.

## Layout specification

Primary mobile review size: **412 × 915 logical pixels**. Also inspect 390, 360 and 320 logical-pixel widths. The web UI caps its centered content at 440px on desktop. Flutter should fill the available handset width, respect `SafeArea`, and allow vertical scrolling when text scaling or a keyboard reduces space.

| Element | Approved specification |
| --- | --- |
| Standard screen side gutters | 24px; 20px at widths ≤360px |
| Safe-area top padding | At least 18px; 12px on short tour layouts |
| Primary/secondary buttons | 54px minimum height, 14px radius, 48px horizontal padding, with a right-pinned arrow |
| Input fields | 54px minimum height, 14px radius, 14px padding, 1px border |
| Icon buttons / progress tap areas | At least 48 × 48px |
| Tour heading | clamp(30px, 8.6vw, 38px)/1.12, bold; 32px at heights ≤780px, 30px at widths ≤360px, 29px on very short mobile layouts |
| Tour body | 15px/23px; 14px/22px at widths ≤360px |
| Getting-started heading | clamp(32px, 8.9vw, 38px), line height 1.18, bold, white |
| Authentication heading | 30px/38px bold; 27px/35px at widths ≤360px |
| Form labels | 13px/20px, semibold |
| Form input text | 15px/24px |
| Access crest | 65px; 56px on short layouts; hidden in account-setup heading |
| Splash / entry coin | 132px / clamp(96px, 28vw, 120px); entry 88px at heights ≤700px |
| Profile photo control | 76px circle, 27px overlaid camera badge |
| Bio | Optional, max 240 characters, multiline |

Use the actual values in `src/styles/onboarding.css` and the later `src/styles/startup-refresh.css` when resolving responsive details. Font letter spacing, shadows, gradients, masks, image positions and decorative opacities are specified there. Gradients are used for the approved photo fades rather than as decorative replacements for the actual photos.

## Suggested widget mapping

| React reference | Flutter equivalent |
| --- | --- |
| `OnboardingAuthUI` | Controlled startup view with a screen enum and navigation callback |
| `Brand`, `Crest` | `Row`, `Text`, circular clipped `Image.asset` |
| `Coin` | `AnimationController`, `Transform` with perspective, front/back crest faces |
| `SunRays`, `OliveBranch` | Sun-ray SVG and supplied transparent olive PNG, with per-placement tint/opacity and slow transform animation |
| Campus faded photo | `Stack`, `Image.asset(fit: BoxFit.cover)`, shader/gradient edge fade |
| Community photo | Clipped photo in `Stack`, yellow circle and olive accents |
| Tools artwork | Native card, text, exact SVG tools, and the supplied transparent robot as a separate image |
| `AccessFrame` | Shared safe/scrolled auth layout with header, progress, branding and heading |
| Password field | `TextFormField`, suffix visibility `IconButton`, required validator |
| Read-only identity | Text rows, not disabled editable form fields |
| Selected photo | Local image preview; emit the selected file to the host |

The high-resolution crest alternative has transparent margins. See `assets.md` before using it, otherwise the displayed crest will be too small. Do not stretch a screenshot of a whole screen into a background.

## Motion

| Motion | Specification |
| --- | --- |
| Splash duration | 2350ms before requesting the first tour screen; 250ms with reduced motion |
| Crest coin | 1900ms, 100ms delay; CSS easing cubic-bezier(0.2, 0.7, 0.24, 1) |
| Coin key poses | Start: Y −35°, Z −9°, down 12px, transparent. At 16% visible. At 74%: Y 690°, Z 2°, up 5px. End: Y 720°, Z 0°, no offset |
| Coin faces | Front/back, back-face culling, 3px depth; parent perspective 900px |
| Transition wipe | Same supplied curved SVG path, rise −80% in 360ms, change screen, wait 20ms, rise to −170% in 460ms; GSAP `power2.inOut` (cubic ease-in-out) |
| Olive/ray sway | Olive 10s, rays 14s, ease-in-out loop; rotation −1.5° to +1.5°, vertical offset 0 to −3px |
| Copy entrance | Opacity 0→1, vertical offset 14→0px, 450ms ease-out |
| Reduced motion | Disable decorative movement, coin rotation and wipe; change screens immediately |

Lock repeated taps while a wipe is running. Progress bars remain clickable with 48px hit targets. Support horizontal swipes and keyboard arrows without interfering with vertical scrolling. There are no tour footer back arrows or visible `01 / 03` counters. Keep a screen-reader-only step announcement.

## Form behavior and host events

- Required-field checks test presence only. They do not verify an ID, password or SIS account.
- Clear the password when the form is submitted, switched or exited. Do not store it in preferences or persist it in a global model.
- `pending` disables navigation, inputs, photo actions and submission. A supplied form error is displayed as an announced alert.
- Account setup accepts optional JPG/PNG/WebP photos up to 1,000,000 bytes, verifies the local image can decode, and supports change/remove. These are local UI checks, not uploads.
- The bio is optional and capped at 240 characters. Name, major and faculty come from host inputs; absence shows “Provided by SIS”. There are no sample identity records.
- Sign-up submission, sign-in submission, guest entry and profile submission are events only. Later, the host decides when to enter account setup or leave the startup UI. No fake successful account state or Home view belongs in this package.
- The package has no completion persistence. The receiving application will decide first-run/replay behavior later.

## Visual acceptance

Compare native widgets with `docs/screenshots/mobile-light/` and `mobile-dark/` at 412 × 915, then inspect narrow widths. Retain safe-area spacing, photo crops/fades, exact SVG shapes, type weights and 14px control corners. Also verify form errors, password visibility, photo replacement/removal, text scaling, reduced motion and keyboard avoidance on real target devices. Static screenshots cannot verify coin motion; run the supplied UI to observe it.

## Latest entry and assistant layout

The getting-started screen uses navy #031D32 in light and dark appearance, full-opacity library photo, white wordmark and “Your campus. Your people. / Your place.” The crest begins around 33% of viewport height. Use a 48px yellow login button with 8px corners; signup is a green text link, and guest entry is transparent with an arrow. The third onboarding screen removes the sparkle badge and puts the provided robot to the right of the assistant card. Keep its text clear of the image. Both onboarding eyebrows and every wordmark dot are removed. The card contains fixed feature copy; it does not simulate a backend or AI response.

## Version 1.1.0 olive asset

Use `assets/illustrations/olive-branch.png` for every branch. It is the unchanged 2172×724 upload, aspect ratio 3:1, with each leaf already positioned. Use `Image.asset` with `BoxFit.contain`; apply the screen tint through `colorBlendMode: BlendMode.srcIn`, and keep the existing per-placement opacity and sway. The old `olive-branch.svg` is intentionally absent. Do not reconstruct or reposition leaves. All assets are inside this package.
