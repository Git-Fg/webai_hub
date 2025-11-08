# AI Hybrid Hub - Agent Manifesto

Your primary mission is to assist in the development of the AI Hybrid Hub, a Flutter application bridging a native UI with web-based AI providers.

**Core Philosophy:** Prioritize simplicity, robustness, and maintainability. The code is the single source of truth; your contributions must be clear and self-documenting. **All features must be engineered for performance and adaptability, ensuring full compatibility with low-end devices.**

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

First, stage all changes.

Then, commit with a message following this exact format: `type(scope): summary`

* **`type`**: `feat`, `fix`, `refactor`, `docs`, `chore`, `style`, `test`.
* **`scope`**: The part of app affected (e.g., `hub`, `webview`, `aistudio`, `bridge`, `docs`, `ci` ...).
* **`summary`**: A concise, present-tense description of change.

**Examples:**

commit message : "fix(webview): Correct bridge timeout handling on Android"

commit message : "feat(hub): Implement ephemeral error messages via new provider"

commit message : "refactor(aistudio): Consolidate settings logic into applyAllSettings"

commit message : "docs(agents): Add Version Control Protocol with never-push rule"

**3. 🛑 ABSOLUTE CONSTRAINT: NEVER PUSH and NEVER USE GIT CLI**

You MUST NEVER use directly `git` cli command and never push by yourself : use your native tool `git`. Your role is to build a clean, logical commit history on the local branch. The human user is solely responsible for reviewing, squashing (if necessary), and pushing changes to the remote repository. This is a critical safety boundary.

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

#### 3.1.2. TypeScript Logging Protocol for Automation

**Guiding Principle:** Logs are for diagnosing state, not just printing strings. To ensure failures are immediately diagnosable and success is verifiable, all `console.log` and `console.error` calls within the TypeScript automation engine (`ts_src/**`) MUST adhere to this structured protocol.

**1. Prefixed and Scoped Messages**

All logs must be prefixed with a scope in square brackets to provide immediate context about their origin.

* **Format:** `[Scope] Message`

* **Examples:**
  * `[Engine] Bridge ready signal sent.` (General orchestrator)
  * `[AI Studio] Settings panel opened successfully.` (Provider-specific logic)
  * `[waitForElement] Still searching...` (Utility-specific logs)

* **Why:** In a hybrid app, this is the only way to quickly differentiate between logs from the general engine, a specific chatbot module, and a low-level utility.

**2. The Intent-Action-Result (IAR) Pattern**

For any significant operation, log the flow using three distinct phases to make the sequence of events clear.

* **A. Intent:** Log what you are about to do.

  ```typescript
  console.log('[AI Studio] Attempting to click Send button...');
  ```

* **B. Action:** Execute the code.

  ```typescript
  sendButton.click();
  ```

* **C. Result:** Log the successful outcome.

  ```typescript
  console.log('[AI Studio] Send button clicked successfully.');
  ```

* **Why:** This pattern makes it trivial to follow the automation script's execution path and pinpoint exactly where an operation hung or failed.

**3. Data-Rich Payloads, Not Verbose Dumps**

When logging objects or variables, log a curated summary of key properties, not the entire object. This keeps logs readable.

* ❌ **NEVER:** Log an entire object directly.

  ```typescript
  // ANTI-PATTERN: Produces unreadable "[object Object]" or a massive dump.
  console.log('Received options:', options);
  ```

* ✅ **ALWAYS:** Log a new object containing only the most relevant properties. For long strings, log a preview.

  ```typescript
  // CORRECT: Provides a clear, concise, and useful summary.
  console.log('[Engine] Received automation options:', {
    model: options.model,
    promptLength: options.prompt.length,
    promptPreview: options.prompt.substring(0, 50) + '...',
    temperature: options.temperature,
  });
  ```

**4. Structured Error Diagnostics (The Critical Rule)**

When an operation fails, the `console.error` log **MUST** be a complete diagnostic report, not just an error message. It must include:

* **Operation:** What was being attempted?
* **Reason:** The specific error message.
* **Inputs:** The data used (e.g., selectors, timeouts).
* **State:** The state of the web page at the moment of failure (URL, readyState, etc.).

* **Example Implementation:**

  ```typescript
  // In a catch block...
  const pageState = {
    url: window.location.href,
    readyState: document.readyState,
  };

  const errorMessage = `
    Operation: Waiting for actionable "Edit" button
    Reason: Element found but was not visible or interactive.
    Selectors Used: [${selectors.join(', ')}]
    Timeout: ${timeout}ms
    Page State: URL=${pageState.url}, ReadyState=${pageState.readyState}
  `;
  console.error(`[AI Studio] ${errorMessage}`);
  throw new Error(errorMessage); // Re-throw to ensure the promise rejects.
  ```

* **Why:** This turns a simple failure log into a full bug report, drastically reducing the time needed for a developer (or another AI) to diagnose and fix the issue. It was this exact structure that allowed us to quickly solve the last regression.

#### 3.2. State Management (Riverpod 3.0+)

* **Use Modern Notifiers:** **ALWAYS** use code-generated `@riverpod` notifiers. **NEVER** use legacy `StateNotifier` or `ChangeNotifier`.
* **Check `ref.mounted` After `await`:** **ALWAYS** add `if (!ref.mounted) return;` after any `await` call in a provider method to prevent "use after dispose" errors.
* **Safely Access AsyncValue State:** When reading the state of an `AsyncNotifier` in a callback or non-reactive context, **ALWAYS** use `ref.read(provider).valueOrNull` or pattern matching to avoid runtime exceptions if the state is `AsyncLoading` or `AsyncError`.
* **Critical Anti-Pattern: `TabController` for Business Logic:**
  * ❌ **NEVER:** `ref.read(tabControllerProvider)?.animateTo(1);`
  * ✅ **ALWAYS:** `ref.read(currentTabIndexProvider.notifier).changeTo(index);`
  * **Why:** `TabController` is a UI concern. `currentTabIndexProvider` is the single source of truth for navigation state.

#### 3.3. Hybrid Development (Timing, Delays, and Performance)

**Guiding Principle:** The application must remain performant and reliable on low-end devices and slow networks. Hardcoded, fixed timings are an anti-pattern. All asynchronous operations must be adaptable.

##### **The "Observe, Don't Poll" Mandate**

* ❌ **NEVER:** Use `setInterval` or recursive `setTimeout` to poll for DOM elements. This is the primary cause of silent WebView crashes on mobile due to CPU exhaustion.

* ✅ **ALWAYS:** Use `MutationObserver` (`waitForElement`) for DOM structure changes and `IntersectionObserver` for visibility checks. These native APIs are event-driven and highly efficient.

* ✅ **ALWAYS:** Follow the **"Observe Narrowly, Process Lightly"** principle: observe the smallest possible DOM subtree and disconnect the observer immediately after its condition is met to conserve resources.

**Critical Anti-Pattern: `setInterval` for DOM Polling**

* ❌ **NEVER:** Use `setInterval` or recursive `setTimeout` loops to poll for existence or state of a DOM element.

  * `// ANTI-PATTERN: Inefficient and causes silent crashes on mobile`

  * `setInterval(() => { if (document.querySelector('#foo')) { ... } }, 100);`

* ✅ **ALWAYS:** Use correct, modern, event-driven API for specific wait condition. This is a non-negotiable performance and stability requirement.

  * **Use `MutationObserver` (`waitForElement`)** for waiting on elements to be added, removed, or changed in the DOM.

  * **Use `IntersectionObserver` (`waitForVisibleElement`)** for waiting on elements to scroll into view.

* **Why:** `setInterval` polling is extremely inefficient. It forces the browser's JavaScript engine to perform expensive query operations hundreds of times per second, even when nothing on the page has changed. On mobile devices with constrained CPU and memory, this resource exhaustion leads to the WebView's JavaScript context crashing silently, which is extremely difficult to debug. `MutationObserver` is a native, highly optimized browser API that solves this problem by only executing code when a relevant DOM change actually occurs.

##### **The Mandatory Timeout Modifier Pattern**

* **Concept:** All timeouts within the TypeScript automation engine **MUST** be scalable. A user-configurable `timeoutModifier` is passed from Dart to TypeScript with every automation task.

* **Implementation Rule:**

  * A global `timeoutModifier` is stored on the `window` object by the `startAutomation` function.

  * All timing-sensitive utilities (e.g., `waitForActionableElement`) **MUST NOT** use hardcoded default timeouts directly.

  * They **MUST** call a shared utility function, `getModifiedTimeout(defaultTimeout)`, which applies the global `timeoutModifier` before executing the wait.

* **Why:** This pattern makes the entire automation engine's timing user-configurable. It is our primary strategy for ensuring compatibility with low-end devices and is not optional.

* **Diagnose First:** Before adding a `Future.delayed`, always investigate alternatives (callbacks, `Promise`, `MutationObserver`).
* **Justify and Document:** Delays are a last resort. If one is necessary, it **MUST** be documented with a `// TIMING:` comment explaining the justification and the date.

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

* **Use `waitForActionableElement`** before ALL critical interactions (clicks, value setting). Performs comprehensive 5-point check:
  1. Attached (in DOM)
  2. Visible (checkVisibility API or offsetParent)
  3. Stable (no ongoing animations)
  4. Enabled (not disabled/inert)
  5. Unoccluded (not covered by another element)

---

#### **3.4. UI & Layout (Spacing with `gap`)**

* **Guiding Principle:** Use the `gap` package for all vertical and horizontal spacing within `Column`, `Row`, and other `Flex`-based layouts.

* ✅ **ALWAYS:** Use `const Gap(...)`.

    ```dart

    Row(

      children: [

        const Icon(Icons.info),

        const Gap(8), // Correct: clean, readable, and explicit.

        const Text('Information'),

      ],

    )

    ```

* ❌ **NEVER:** Use `SizedBox` for spacing.

    ```dart

    // ANTI-PATTERN: Verbose and less clear about intent.

    const SizedBox(width: 8),

    ```

* **Why:** The `Gap` widget is a simple, `const`-_friendly_ abstraction that makes layout code more readable and self-documenting by clearly stating its purpose is to create space.

#### **3.5. Navigation (`auto_route`)**

* **Guiding Principle:** All navigation between screens MUST be handled by the `auto_route` package. The routing configuration is centralized in `lib/core/router/app_router.dart`.

* ✅ **ALWAYS:** Use the generated `Route` objects and the `context.router` extension.

    ```dart

    // Correct: Type-safe, centralized, and easy to refactor.

    unawaited(context.router.push(const SettingsRoute()));

    ```

* ❌ **NEVER:** Use manual `Navigator.push` with `MaterialPageRoute`.

    ```dart

    // ANTI-PATTERN: Brittle, not type-safe, and decentralizes navigation logic.

    Navigator.push(

      context,

      MaterialPageRoute(builder: (context) => const SettingsScreen()),

    );

    ```

* **Why:** `auto_route` provides compile-time safety for route arguments, eliminates boilerplate, and creates a single source of truth for all navigation paths in the app. This makes the codebase more robust and easier to maintain.

#### **3.6. Dependency Management (CLI Commands Only)**

* **Guiding Principle:** All dependency modifications MUST be performed using CLI commands. Manual editing of dependency files is strictly forbidden.

* ✅ **ALWAYS:** Use CLI commands to manage dependencies.

  * **For Dart/Flutter packages:**
    * `flutter pub add <package_name>` to add a dependency
    * `flutter pub remove <package_name>` to remove a dependency
    * `flutter pub upgrade <package_name>` to upgrade a specific package
    * `flutter pub upgrade` to upgrade all packages

  * **For npm/TypeScript packages:**
    * `npm install <package_name>` or `npm install <package_name> --save-dev` to add a dependency
    * `npm uninstall <package_name>` to remove a dependency
    * `npm update <package_name>` to update a specific package

* ❌ **NEVER:** Manually edit `pubspec.yaml` or `package.json` to add, remove, or modify dependencies.

  ```yaml
  # ANTI-PATTERN: Manual editing bypasses dependency resolution and version locking.
  dependencies:
    some_package: ^1.0.0  # ❌ NEVER do this
  ```

  ```json
  // ANTI-PATTERN: Manual editing bypasses dependency resolution and version locking.
  {
    "dependencies": {
      "some-package": "^1.0.0"  // ❌ NEVER do this
    }
  }
  ```

* **Why:** CLI commands ensure proper dependency resolution, version locking, and consistency across the project. They automatically update lock files (`pubspec.lock` and `package-lock.json`), resolve version conflicts, and maintain the integrity of the dependency tree. Manual editing can lead to inconsistent states, unresolved dependencies, and difficult-to-debug issues.

#### 3.7. Modeling (Freezed 3.0+)

* **Guiding Principle:** For classes with factory constructors, you **MUST** use the `sealed` or `abstract` keyword. `sealed` is the recommended modern choice as it enables exhaustive pattern matching. Omitting these keywords will cause build errors.

* ✅ **ALWAYS (Recommended):** Use `sealed` for classes with factories.

  ```dart
  @freezed
  sealed class Message with _$Message {
    const factory Message({ required String id, /*... */ }) = _Message;
  }
  ```

* ❌ **NEVER:** Omit `sealed` or `abstract` on classes with factories.

  ```dart
  // ANTI-PATTERN: This will fail to compile with freezed: ^3.0.0
  @freezed
  class Message with _$Message {
    const factory Message({ required String id, /*... */ }) = _Message;
  }
  ```

#### 3.8. Data Persistence (Drift)

* **Guiding Principle:** Use the modern, platform-aware `NativeDatabase` constructor to abstract away file path management. This removes unnecessary dependencies on `path_provider`.

* ✅ **ALWAYS:** Use `NativeDatabase.inDatabaseFolder` for database initialization.

  ```dart
  // In your database class constructor
  AppDatabase() : super(NativeDatabase.inDatabaseFolder(path: 'db.sqlite'));
  ```

* ❌ **AVOID (Legacy):** Manual path construction with `path_provider`.

  ```dart
  // LEGACY PATTERN: Verbose and requires extra dependencies.
  LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase(file);
  });
  ```

#### 3.9. Data Persistence & Management (Drift)

**Guiding Principle:** The on-device database must remain efficient and its size must be managed to prevent performance degradation over time.

* **Cascading Deletes:** When defining foreign key relationships, **ALWAYS** use `onDelete: KeyAction.cascade`. This offloads the responsibility of cleaning up related data (e.g., deleting a conversation's messages) to the database itself, which is more efficient and reliable than manual Dart code.

* **Automatic History Pruning:** To protect device storage, a history pruning mechanism **MUST** be implemented.

  * **Trigger:** Pruning should occur once on application startup to avoid performance overhead during user interaction.

  * **Logic:** The process must fetch the user-configured `maxConversationHistory` setting, identify all conversation records exceeding this limit (ordered by creation date), and delete them in a single, efficient batch operation.

* **Atomic Operations:** Any sequence of related database writes (e.g., creating a new conversation and its first message) **MUST** be wrapped in a `db.transaction()` block. This guarantees data integrity by ensuring that either all operations complete successfully or all are rolled back in case of an error.
