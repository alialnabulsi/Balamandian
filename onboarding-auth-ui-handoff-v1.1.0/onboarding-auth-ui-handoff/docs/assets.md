# Bundled assets

All runtime visual assets are local. Paths below are relative to `src/assets/`. SHA-256 hashes and byte sizes are in `asset-manifest.json`.

| File | Usage / handling |
| --- | --- |
| `images/onboarding-main-campus.png` | Approved 597×335 campus walkway/fountain photo, first tour screen. Cover crop, 48% horizontal position, top/bottom and edge fades. Do not replace with the older aerial photo. |
| `images/onboarding-community-fair.png` | Approved 596×335 club-fair photo, second tour screen. Keep the native photo crop; no white information cards or stock portrait overlay. |
| `images/onboarding-library-evening.png` | Approved 680×451 library photo, getting-started upper backdrop. Cover crop, horizontal position 55%, height 44dvh, full photo opacity in both appearances, fading into the navy #031D32 canvas. |
| `images/campus-assistant-robot.png` | Supplied 1145×1374 transparent waving robot. Original pixels retained; placed beside the third-screen card with `object-fit: contain`, never used as a complete-screen screenshot. |
| `images/uob-logo.png` | Original 317×100 university logo used by this React UI. Circular crest is at the left. The `Crest` component clips the first square at the desired size; image height is 100%, width auto. Do not fit the entire horizontal logo inside a circle. |
| `images/university-crest-high-resolution.png` | Additional 1152×1152 transparent crest source for a sharper Flutter port. Visible emblem occupies approximately the central 600px square. Center-crop that square or clip to an oval and scale the image by approximately 1.92. The React preview deliberately retains its original crop. |
| `illustrations/olive-branch.png` | Latest user-supplied 2172×724 transparent branch, copied byte-for-byte. Used by every olive decoration as a CSS alpha mask with `contain` fitting. Leaf positions and original transparency are preserved; the screen supplies its tint, opacity and slow sway. In Flutter, use `Image.asset` with `color`, `colorBlendMode: BlendMode.srcIn`, and `fit: BoxFit.contain`. |
| `illustrations/sun-rays.svg` | Exact original decorative ray paths. Use an SVG/color filter or native paths; preserve subtle opacity and scale. |

## Fonts

Inter Regular 400, Medium 500, SemiBold 600 and Bold 700 are included as TTFs with their SIL Open Font License (`fonts/OFL.txt`). They are static instances from the official Google Fonts Inter variable family, optical size 14. The web reference uses local `@font-face`; no Google Fonts network request is needed. Use the provided weights rather than synthesized bold.

Official source: [Google Fonts — Inter](https://github.com/google/fonts/tree/main/ofl/inter).

## Icons

The twelve exact Phosphor assets are included as SVG files, with the MIT license (`icons/LICENSE.txt`). `components/Icons.tsx` uses their original path geometry as editable inline SVGs. Assets are named using the original Phosphor names:

- Regular: `arrow-left`, `arrow-right`, `camera`, `check`, `eye`, `eye-slash`, `graduation-cap`.
- Duotone: `users`, `sparkle`, `calendar-dots`, `note-pencil`, `calculator`.

SVG viewBox is 256×256. Most UI glyphs display at 21–24px. Duotone paths retain opacity 0.2; tint with the appropriate foreground token. No icon font or runtime icon download is required.

Official source: [Phosphor core](https://github.com/phosphor-icons/core). The icon named `CalendarDays` in React maps to `calendar-dots.svg`; `NotebookPen` maps to `note-pencil.svg`; `Sparkles` maps to `sparkle.svg`; `EyeOff` maps to `eye-slash.svg`.

## Ownership

University branding and campus photography are existing project/user-supplied assets. Their original rights remain with their owners; this handoff does not grant a new stock-photo or university trademark license. The robot artwork is supplied by the user; no replacement branding has been introduced. The olive PNG is the latest user-supplied artwork. The sun-ray SVG reproduces the existing prototype paths. Font and icon licenses are bundled alongside those assets.
