---
name: flutter-docs-first
description: Use for every Balamandian Flutter/Dart mobile-app task, including app architecture, folder organization, UI widgets, Figma implementation, theming, assets, accessibility, responsiveness, state, navigation, networking, plugins, Android integration, testing, performance, and APK builds. Check relevant current official Flutter/Dart documentation before making decisions or editing code. Not for backend-only work.
---

# Balamandian: Flutter docs first

Apply this skill to proposals, reviews, code changes and bug fixes in the Flutter client. The purpose is to **ground decisions in documented Flutter/Dart APIs and practices**, not to add process or speculative scaffolding.

## Before deciding or editing

1. Read the task and inspect only relevant existing code, `pubspec.yaml`, Android configuration and package versions. Preserve the current working app and follow existing conventions unless a documented improvement is necessary.
2. Open the relevant topic links in [references/official-docs.md](references/official-docs.md), then read the **specific current official page(s)** for the task:
   - `docs.flutter.dev` for workflows, app architecture, UI, testing and platform guidance.
   - `api.flutter.dev` for exact widget/class/API behavior.
   - `dart.dev` for language, tooling and Effective Dart.
   - `pub.dev` plus the package publisher's official docs for third-party packages; vendor docs for SDK integration details (such as Mapbox).
3. Check that the approach and APIs are compatible with the project's Flutter/Dart SDK constraints. If current docs cannot be accessed, say so. Do not claim to have verified the latest guidance or guess unsupported API names.

## Architecture and code

- Prefer Flutter's documented **separation of UI and data concerns**. Use Views + ViewModels and repositories + services when the feature needs them. Keep UI widgets focused on rendering and input; maintain data/business logic outside widgets.
- Follow Flutter's [architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations) and [case study](https://docs.flutter.dev/app-architecture/case-study) when organizing code. An optional domain/use-case layer should be added only for demonstrated complexity, not by default.
- Use dependency injection, explicit data flow, immutable models where appropriate, and testable boundaries as supported by Flutter's recommendations. Avoid pointless abstractions, premature packages, or empty feature scaffolding.
- Use [Effective Dart](https://dart.dev/effective-dart) naming/style and the repository's lint rules. Prefer Flutter SDK capabilities unless a dependency solves a real requirement. Explain new packages before introducing them.
- The Flutter app is a client. Keep secret credentials, privileged operations, database access and server authentication logic in the separate backend. Use Flutter services to call Balamandian-API when implemented.
- Android is the only active deployment target. Do not add other platform implementations without an explicit request.

## UI, UX and Figma

- Treat the approved [Final UI Screens](https://www.figma.com/design/cnc4fq8HLje1mVolx7kYws/UX-UI?node-id=2566-22) and repository assets as the **source of truth for visual design**; use Flutter official guidance for widgets, composition, theming, layout, interaction, assets and navigation.
- Check the relevant UI documentation before choosing custom widgets or layouts. Prefer composable Flutter widgets over hand-built workarounds when the SDK covers the need.
- Consider safe areas, available width, orientation, text scaling, touch targets, semantics, contrast, and navigation accessibility. Match the Figma design without sacrificing basic usability; identify any conflict instead of silently redesigning.
- Do not invent colors, spacing, typography, assets, screen flows or design requirements and present them as approved or as Flutter mandates.

## Verify and hand off

- Make the **smallest change requested**. For relevant code changes use `dart format`, `flutter analyze`, `flutter test`, and `flutter build apk` where the task and available environment justify them. Docs-only tasks need no fabricated build evidence.
- Report succinctly: the decision/change, the **official documentation links actually consulted**, any project-specific tradeoff, and validation results or blockers.
- Flutter docs contain both strong recommendations and context-dependent guidance. **Do not claim the documentation requires a specific package or folder layout when it does not.** If official docs are silent, label the solution a reasoned project choice.
