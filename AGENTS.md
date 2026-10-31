# Balamandian — Codex repository instructions

This repository contains the **Flutter Android client**, not the Balamandian main backend or the SIS API.

- **Before any Flutter, Dart, UI, asset, dependency, Android, testing, or build task**, read and use [`flutter-docs-first`](.agents/skills/flutter-docs-first/SKILL.md). Use its [official documentation index](.agents/skills/flutter-docs-first/references/official-docs.md) to find task-specific references, then consult the relevant current official documentation.
- Match approved screens and branding in [Balamandian Final UI Screens (Figma)](https://www.figma.com/design/cnc4fq8HLje1mVolx7kYws/UX-UI?node-id=2566-22) for visual requirements. Use Flutter documentation for *how* to implement them. Do not invent or silently change the product design.
- Prefer maintainable, focused changes. Preserve the working Android app, native branding and APK build. Do not add iOS/web/desktop targets, packages, scaffolding, or a backend inside Flutter without a task-specific reason.
- Distinguish **official Flutter guidance** from project decisions, and cite relevant documentation URLs when presenting implementation choices.
- For code changes, run appropriate formatting, analysis and tests, and an Android build when relevant and possible. Report what ran and what could not run; never claim a check passed without executing it.
