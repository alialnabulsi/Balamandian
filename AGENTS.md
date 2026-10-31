# Flutter documentation first

Whenever working on anything related to Flutter or Dart in this repository, **consult the relevant, current official documentation before proposing, writing, reviewing, or changing code**.

- Flutter guides and best practices: https://docs.flutter.dev/
- Flutter API reference: https://api.flutter.dev/
- Dart documentation: https://dart.dev/

Use the official documented approach for the task. Do not assume that an undocumented preference is a Flutter requirement. If the documentation cannot be accessed, state that clearly instead of claiming it was checked.

For relevant tasks, read `.agents/skills/flutter-docs-first/SKILL.md`.

## Component-first UI development

- Build screens by composing dedicated, reusable Flutter widget classes rather than hardcoding complete UI elements inside screens.
- Extract meaningful UI elements into separate widget classes and files, even if initially used by one screen (buttons, floating action buttons, cards, inputs, dialogs, headers, list items, etc.).
- Always inspect existing components before creating new ones. Reuse or extend suitable components instead of duplicating code.
- Make components configurable using constructor parameters, callbacks, and child widgets where appropriate.
- Place shared components in `lib/ui/core/ui/` and feature-specific components in `lib/ui/<feature>/widgets/`.
- Centralize shared styling in Flutter's theme system and approved design tokens. Avoid repeated hardcoded styling.
- Keep screens focused on composing components. Keep business logic outside widgets according to our MVVM architecture.
- Prefer widget classes over UI-building helper functions. Avoid unnecessary wrappers around trivial structural widgets.
- Follow the official Flutter documentation and the architecture conventions in `README.md`.