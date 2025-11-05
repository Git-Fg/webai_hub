# Contributing to AI Hybrid Hub

Welcome! Please read `AGENTS.md` first — it is the single source of truth for our workflow and standards.

## Quick Rules

- TypeScript in `ts_src/**`:
  - Run `npm run build` after ANY change (outputs `assets/js/bridge.js`).
  - Do NOT edit `assets/js/bridge.js` directly.
- Riverpod/Freezed codegen:
  - Run `flutter pub run build_runner build --delete-conflicting-outputs` after changes to `@riverpod` / `@freezed`.
- Testing:
  - Run `flutter test` locally. Prefer fakes over heavy mocks; keep tests fast and deterministic.
  - VS Code: use "Flutter Tests (Agent)" launch config.
- Code quality:
  - Explain "Why", not "What". Use `// WHY:` and `// TIMING:` when essential.
  - Zero debugging artifacts: no `print/debugPrint`, no `console.log`, no commented-out dead code.
- Architecture:
  - Never use `TabController` for business logic; use `currentTabIndexProvider`.

## Getting Started

1. `flutter pub get`
2. `npm install`
3. Make changes
4. TypeScript? → `npm run build`
5. Generated code? → `flutter pub run build_runner build --delete-conflicting-outputs`
6. `flutter test`

For deeper context (debugging workflow, timing rules, selectors guidance), see `AGENTS.md`.
