# Contributing to AI Hybrid Hub

Welcome! Please read `AGENTS.md` first — it is the single source of truth for our workflow and standards.

## Quick Rules

- TypeScript in `packages/bridge/**`:
  - Run `pnpm run validate:ts` after ANY change (outputs `assets/js/bridge.js`).
  - Do NOT edit `assets/js/bridge.js` directly.
- Riverpod/Freezed codegen:
  - Run `flutter pub run build_runner build --delete-conflicting-outputs` after changes to `@riverpod` / `@freezed`.
- Testing:
  - Run `flutter test` locally. Prefer fakes over heavy mocks; keep tests fast and deterministic.
  - Run `pnpm run test:e2e` when selector coverage changes or UI flows need validation.
  - VS Code: use "Flutter Tests (Agent)" launch config.
- Code quality:
  - Explain "Why", not "What". Use `// WHY:` and `// TIMING:` when essential.
  - Zero debugging artifacts: no `print/debugPrint`, no `console.log`, no commented-out dead code.
- Architecture:
  - Never use `TabController` for business logic; use `currentTabIndexProvider`.

## Getting Started

1. `flutter pub get`
2. `pnpm install`
3. Make changes.
4. Run `pnpm run test:ci` to ensure all code is clean, generated assets are up-to-date, and tests pass.
5. (Optional during development) Run targeted commands such as `pnpm run validate:ts`, `pnpm run test:e2e`, or `flutter test` if you need faster feedback.

For deeper context (debugging workflow, timing rules, selectors guidance), see `AGENTS.md`.

## Manual tools: AI Studio selector validator

This script is intended for manual use by humans to sanity-check and iterate CSS selectors for Google AI Studio.

- Purpose: Quickly validate selector strategies before updating TypeScript in `packages/bridge/**`.
- Scope: Manual only; not automated, not part of CI.
- Environment: Run in the browser console of a Chromium-derived browser (Chrome, Edge, Brave).

How to use:

1. Open Google AI Studio in a Chromium browser and navigate to the relevant page/state you want to validate.
2. Open DevTools (Cmd+Opt+I on macOS) and switch to the Console tab.
3. Open `packages/manual_validation/aistudio_selector_validator.js` and paste the needed snippet(s) into the Console, or save it as a DevTools Snippet and run it.
4. Observe outputs in the Console, adjust selectors, and re-run until stable.

Notes:

- Prefer semantic, stable anchors (IDs, data-* attributes, accessible labels) over volatile class names.
- Avoid relying on timing; prefer explicit readiness checks and DOM observation.
- Do not commit console outputs.
- After updating selectors in TypeScript, run `pnpm run validate:ts` to regenerate `assets/js/bridge.js`.
