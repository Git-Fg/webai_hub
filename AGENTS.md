# AI Hybrid Hub - Agent Manifesto

Your primary mission is to assist in the development of the AI Hybrid Hub, a Flutter application bridging a native UI with web-based AI providers.

**Core Philosophy:** Prioritize simplicity, robustness, and maintainability. The code is the single source of truth; your contributions must be clear and self-documenting.

---

### 1. The Two Core Workflows

Your work on this project is divided into two distinct, high-level workflows. Always identify which workflow you are in.

#### **Workflow A: Code Development & Modification**

This workflow applies when you are writing or changing feature code (e.g., adding a new setting, refactoring a provider).

1. **Understand:** Consult `@blueprint_full` for architecture and `@conversation_provider` or `@automation_engine` for existing patterns.
2. **Modify:** Write clean, self-documenting code. Adhere to best practices in Section 3.
3. **Verify:** Before committing, you are responsible for ensuring all static analysis and code generation checks pass by running a single command:
    * Run `npm run validate` to check both Dart and TypeScript code and run code generation.
    * See [Available Commands Reference](#2-available-commands-reference) for detailed command information.
4. **Commit:** After verification succeeds, you MUST commit changes to local repository. This creates an atomic checkpoint. Follow **Version Control Protocol** defined below.

---

##### Version Control Protocol (VCP)

**Goal:** To create an atomic, traceable history of changes, allowing for easy rollbacks and clear understanding of development process.

**1. When to Commit:**

You MUST commit after every logical, self-contained unit of work is completed and validated. Examples include:

* After successfully fixing a bug during autonomous validation.
* After implementing a new feature or method.
* After a significant refactoring.
* After updating documentation files.

**2. How to Commit:**

Use structured, conventional commit messages. This is not optional.

First, stage all changes:

```bash
git add .
```

Then, commit with a message following this exact format: `type(scope): summary`

* **`type`**: `feat`, `fix`, `refactor`, `docs`, `chore`, `style`, `test`.
* **`scope`**: The part of app affected (e.g., `hub`, `webview`, `aistudio`, `bridge`, `docs`, `ci` ...).
* **`summary`**: A concise, present-tense description of change.

**Examples:**

```bash
git commit -m "fix(webview): Correct bridge timeout handling on Android"

git commit -m "feat(hub): Implement ephemeral error messages via new provider"

git commit -m "refactor(aistudio): Consolidate settings logic into applyAllSettings"

git commit -m "docs(agents): Add Version Control Protocol with never-push rule"
```

**3. 🛑 ABSOLUTE CONSTRAINT: NEVER PUSH**

You MUST NEVER run `git push`. Your role is to build a clean, logical commit history on the local branch. The human user is solely responsible for reviewing, squashing (if necessary), and pushing changes to the remote repository. This is a critical safety boundary.

---

##### Sub-Workflow: TypeScript Modification Protocol

When modifying any file in `ts_src/**`, you MUST follow this strict, four-step protocol.

**Step 1: Analyze Types First**

Before writing code, read the relevant type definitions (`ts_src/types/**`) to understand the existing contracts.

**Step 2: Modify Types Before Logic**

If a change is required, update the type definition file (`.ts` or `.d.ts`) **FIRST**.

**Step 3: Implement Logic Changes**

Modify the implementation logic, adhering to the standards in Section 3.4.

**Step 4: Verify and Build**

This is a mandatory verification process, now consolidated into a single command.

```bash
npm run validate:ts
```

This single command will automatically handle linting, static type checking, and building the asset bundle. You MUST resolve all errors it reports.
    * See [Available Commands Reference](#2-available-commands-reference) for detailed command information.

#### **Workflow B: Autonomous Feature Validation**

This workflow applies when you need to perform a full, end-to-end "manual" test of a provider's integration. This is a fully automated process.

1. **Initiate:** Invoke the autonomous validation protocol by tagging the rule with the target provider ID.
    * **Example:** `@autonomous-validator aistudio`
2. **Execute:** The `@autonomous-validator` rule is the **single source of truth** for this entire process. It will guide you through:
    * Analyzing the codebase to generate a test plan.
    * Using the `run_and_log.sh` and `terminate_run.sh` scripts to manage the test environment.
    * Executing the test plan.
    * Diagnosing and attempting to fix any failures by analyzing `reports/run.log`.
    * Generating a final report with results and suggestions.
3. **Do Not Deviate:** You must follow the `@autonomous-validator` protocol exactly. It has superseded all previous manual debugging instructions.

---

### 2. Available Commands Reference

This section provides a comprehensive reference of all available commands in the project, when to use them, and how they fit into the development workflow.

#### 2.1. Command Overview

| Command | Purpose | When to Use | Prerequisites |
|---------|---------|-------------|--------------|
| `npm run build` | Build TypeScript to JavaScript bundle | After TypeScript changes when you only need to rebuild | `npm install` |
| `npm run lint` | Run ESLint on TypeScript files | To check code style and potential issues | `npm install` |
| `npm run validate:ts` | Full TypeScript validation (lint + type check + build) | After any TypeScript changes | `npm install` |
| `npm run validate` | Complete validation for both TypeScript and Dart | Before committing any changes | `npm install`, `flutter pub get` |
| `npm run test:ci` | Full CI pipeline (validation + Flutter tests) | Before creating PR or for final validation | `npm install`, `flutter pub get` |
| `flutter analyze` | Dart static analysis | To check Dart code for issues | `flutter pub get` |
| `flutter test` | Run Flutter unit tests | To verify test suite passes | `flutter pub get` |
| `flutter pub run build_runner build --delete-conflicting-outputs` | Generate Dart code | After modifying Riverpod providers or Freezed models | `flutter pub get` |

#### 2.2. Command Usage Flowchart

```
Start
 │
 ├─ Did you modify TypeScript files?
 │   ├─ Yes → Run `npm run validate:ts`
 │   │   ├─ Need to run tests? → Run `npm run test:ci`
 │   │   └─ Done
 │   └─ No → Continue
 │
 ├─ Did you modify Dart files?
 │   ├─ Yes → Run `flutter analyze`
 │   │   ├─ Modified providers/models? → Run `flutter pub run build_runner build --delete-conflicting-outputs`
 │   │   ├─ Need to run tests? → Run `flutter test`
 │   │   └─ Done
 │   └─ No → Continue
 │
 ├─ Are you committing changes?
 │   ├─ Yes → Run `npm run validate`
 │   └─ No → Done
 │
 └─ Are you creating a PR?
     ├─ Yes → Run `npm run test:ci`
     └─ No → Done
```

#### 2.3. Command Details

##### TypeScript Commands

**`npm run build`**

* Compiles TypeScript in `ts_src/` to `assets/js/bridge.js`
* Use when you only need to rebuild without linting or type checking
* Faster than full validation but skips important checks

**`npm run lint`**

* Runs ESLint on all TypeScript files
* Checks for code style issues and potential problems
* Use for quick style checks without full validation

**`npm run validate:ts`**

* Runs TypeScript linting, type checking, and building in sequence
* The recommended command after any TypeScript changes
* Ensures code quality before committing

##### Combined Commands

**`npm run validate`**

* Runs complete validation for both TypeScript and Dart
* Includes: `npm run validate:ts`, `flutter analyze`, and code generation
* The primary command to run before committing any changes
* Ensures consistency across the entire codebase

**`npm run test:ci`**

* Runs full CI pipeline: validation + Flutter tests
* Use before creating pull requests or for final validation
* Ensures all tests pass and code is properly validated

##### Dart Commands

**`flutter analyze`**

* Runs static analysis on Dart code
* Checks for potential issues and style violations
* Use after Dart changes when not running full validation

**`flutter test`**

* Runs the Flutter test suite
* Verifies all unit and widget tests pass
* Use after making changes that might affect test behavior

**`flutter pub run build_runner build --delete-conflicting-outputs`**

* Generates Dart code for Riverpod providers and Freezed models
* Required after modifying any files with `@riverpod` or `@freezed` annotations
* Use with `--delete-conflicting-outputs` to avoid conflicts

---

### 3. Technical Best Practices & Anti-Patterns (The Unchanging Rules)

These are the fundamental principles of quality code in this project. They apply to all development work.

#### 3.1. Code Quality & Commenting

* **Guiding Principle:** Comments must explain **"Why,"** not "What." Use `// WHY:` for strategic decisions and `// TIMING:` for justifying non-obvious delays.
* **Zero-Tolerance for Debugging Artifacts:** Before any commit, remove all `print()`, `debugPrint()`, `console.log()`, and commented-out code blocks.

#### 3.1.1. Color Opacity Best Practices (Flutter 3.27+)

**Context:** The `withOpacity()` method is **deprecated** as of Flutter 3.27.0 due to a loss of precision during its internal float-to-integer conversion.

* ❌ **NEVER:** Use the deprecated `withOpacity()` method.
  * `myColor.withOpacity(0.5); // Deprecated & lossy`

* ✅ **ALWAYS:** Use the recommended `withValues(alpha: ...)` method for adjusting color transparency. It works directly with floating-point alpha values, ensuring maximum precision and compatibility with modern color systems.
  * `myColor.withValues(alpha: 0.5); // Correct & precise`

* **Note on `withAlpha(int)`:** The `withAlpha(int alpha)` method remains valid and is not deprecated. Use it only for specific cases that require direct 8-bit integer manipulation (0-255).

#### 3.2. State Management (Riverpod 3.0+)

* **Use Modern Notifiers:** **ALWAYS** use code-generated `@riverpod` notifiers. **NEVER** use legacy `StateNotifier` or `ChangeNotifier`.
* **Check `ref.mounted` After `await`:** **ALWAYS** add `if (!ref.mounted) return;` after any `await` call in a provider method to prevent "use after dispose" errors.
* **Critical Anti-Pattern: `TabController` for Business Logic:**
  * ❌ **NEVER:** `ref.read(tabControllerProvider)?.animateTo(1);`
  * ✅ **ALWAYS:** `ref.read(currentTabIndexProvider.notifier).changeTo(index);`
  * **Why:** `TabController` is a UI concern. `currentTabIndexProvider` is the single source of truth for navigation state.

#### 3.3. Hybrid Development (Timing & Delays)

* **Diagnose First:** Before adding a `Future.delayed`, always investigate alternatives (callbacks, `Promise`, `MutationObserver`).
* **Justify and Document:** Delays are a last resort. If one is necessary, it **MUST** be documented with a `// TIMING:` comment explaining the justification and the date.

**Critical Anti-Pattern: `setInterval` for DOM Polling**

* ❌ **NEVER:** Use `setInterval` or recursive `setTimeout` loops to poll for existence or state of a DOM element.

  * `// ANTI-PATTERN: Inefficient and causes silent crashes on mobile`

  * `setInterval(() => { if (document.querySelector('#foo')) { ... } }, 100);`

* ✅ **ALWAYS:** Use correct, modern, event-driven API for specific wait condition. This is a non-negotiable performance and stability requirement.

  * **Use `MutationObserver` (`waitForElement`)** for waiting on elements to be added, removed, or changed in the DOM.

  * **Use `IntersectionObserver` (`waitForVisibleElement`)** for waiting on elements to scroll into view.

* **Why:** `setInterval` polling is extremely inefficient. It forces the browser's JavaScript engine to perform expensive query operations hundreds of times per second, even when nothing on the page has changed. On mobile devices with constrained CPU and memory, this resource exhaustion leads to the WebView's JavaScript context crashing silently, which is extremely difficult to debug. `MutationObserver` is a native, highly optimized browser API that solves this problem by only executing code when a relevant DOM change actually occurs.

**Modern Waiting Patterns (TypeScript/JavaScript):**

The automation engine uses event-driven APIs instead of polling. Follow these patterns:

* **`waitForElement`**: Use for DOM structural changes (elements being added/removed). Uses `MutationObserver` as primary strategy.
* **`waitForVisibleElement`**: Use for visibility checks, especially for lazy-loaded content and virtualized lists. Uses `IntersectionObserver`.
* **`waitForActionableElement`**: Use before ALL critical interactions (clicks, value setting). Performs comprehensive 5-point check:
  1. Attached (in DOM)
  2. Visible (checkVisibility API or offsetParent)
  3. Stable (no ongoing animations)
  4. Enabled (not disabled/inert)
  5. Unoccluded (not covered by another element)

**Mobile Performance Checklist: The "Observe, Don't Poll" Mandate**

When waiting for DOM changes, `MutationObserver` is mandatory, but it must be used correctly to preserve battery and performance. The core principle is **"Observe Narrowly, Process Lightly"**.

* ✅ **DO:** Observe the smallest possible DOM subtree (e.g., a specific chat container like `#chat-history` instead of `document.body`).

* ✅ **DO:** Filter mutations aggressively inside your callback. Only process changes relevant to your goal.

* ✅ **DO:** Disconnect observer (`observer.disconnect()`) immediately after the condition is met. Leaving observers running is a common cause of memory leaks.

* ✅ **DO:** Limit observation types in the config (`{ childList: true }`). Only watch what you need.

* ❌ **NEVER:** Use `setInterval` to poll the DOM. This is the primary cause of silent WebView crashes.

* ❌ **NEVER:** Observe `document.body` with `subtree: true` unless absolutely necessary and combined with aggressive filtering.

* ❌ **NEVER:** Leave an observer connected after its task is complete.

**Actionability vs Simple Waiting:**

* **Use `
