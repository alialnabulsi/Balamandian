# Balamandian Android branding

Source: [Final UI Screens (Figma)](https://www.figma.com/design/cnc4fq8HLje1mVolx7kYws/UX-UI?node-id=2566-22), university seal layer `2663:17531`.

The original seal artwork is kept unchanged. The splash and launcher icon use the approved screen colors: navy `#14263B` and the original seal's gold/blue identity.

## Regenerate Android resources

From the Flutter project root, with Flutter installed:

```powershell
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
flutter run
```

This regenerates Android mipmap and splash resources in `android/app/src/main/res/` from the committed source PNG and configuration. Review and commit the generated Android resources plus the updated `pubspec.lock` after running the commands. Native splash is displayed on a cold launch: fully close the app, then tap its icon on the device to test.

Notes:
- The Android app label is `Balamandian`.
- Only Android resources are generated. Adding iOS later requires a separate review of native branding.
- On Android 12+ the native system splash screen has a centered masked icon, not a full-screen custom image.
- The source seal is a 128×128 rendered Figma asset; for production release replace it with a higher-resolution university-approved master asset if one is available.
