# AI Hybrid Hub - Agent Manifesto

Your primary mission is to assist in the development of the AI Hybrid Hub, a Flutter application bridging a native UI with web-based AI providers.

**Core Philosophy:** Prioritize simplicity, robustness, and maintainability. The code is the single source of truth; your contributions must be clear and self-documenting. **All features must be engineered for performance and adaptability, ensuring full compatibility with low-end devices.**

---

## 1. The Two Core Workflows

Your work on this project is divided into two distinct, high-level workflows. Always identify which workflow you are in.

### **Workflow A: Code Development & Modification**

This workflow applies when you are writing or changing feature code (e.g., adding a new setting, refactoring a provider).

1. **Understand:** Consult `@blueprint_full` for architecture and `@conversation_provider` or `@automation_engine` for existing patterns.
2. **Modify:** Write clean, self-documenting code. Adhere to best practices in Section 3.
3. **Verify:** Before committing, you are responsible for ensuring all static analysis and code generation checks pass by running a single command:
    * Run `npm run validate` to check both Dart and TypeScript code and run code generation.
    * See [Available Commands Reference](#2-available-commands-reference) for detailed command information.
4. **Commit:** After verification succeeds, you MUST commit changes to local repository. This creates an atomic checkpoint. Follow **Version Control Protocol** defined below.

---

#### Version Control Protocol (VCP)

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

### 3. ABSOLUTE CONSTRAINT: NEVER PUSH and NEVER USE GIT CLI

You MUST NEVER use directly `git` cli command and never push by yourself : use your native tool `git`. Your role is to build a clean, logical commit history on the local branch. The human user is solely responsible for reviewing, squashing (if necessary), and pushing changes to the remote repository. This is a critical safety boundary.

---

#### Sub-Workflow: TypeScript Modification Protocol

When modifying any file in `ts_src/**`, you MUST follow this strict, four-step protocol.

#### Step 1: Analyze Types First

Before writing code, read the relevant type definitions (`ts_src/types/**`) to understand the existing contracts.

#### Step 2: Modify Types Before Logic

If a change is required, update the type definition file (`.ts` or `.d.ts`) **FIRST**.

#### Step 3: Implement Logic Changes

Modify the implementation logic, adhering to the standards in Section 3.4.

#### Step 4: Verify and Build

This is a mandatory verification process, now consolidated into a single command.

```bash
npm run validate:ts
```

This single command will automatically handle linting, static type checking, and building of asset bundle. You MUST resolve all errors it reports.

* See [Available Commands Reference](#2-available-commands-reference) for detailed command information.

#### **Workflow B: Autonomous Feature Validation**

This workflow applies when you need to perform a full, end-to-end "manual" test of a provider's integration. This is a fully automated process.

1. **Initiate:** Invoke the autonomous validation protocol by tagging the rule with the target provider ID.
    * **Example:** `@autonomous-validator aistudio`
2. **Execute:** The `@autonomous-validator` rule is the **single source of truth** for this entire process. It will guide you through:
    * Analyzing the codebase to generate a test plan.
    * Using the unified `reports/run_session.sh` script to manage the test environment.
    * Executing the test plan.
    * Diagnosing and attempting to fix any failures by analyzing session-specific log files.
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

```text
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

#### 2.4. Autonomous Validation Scripts

The autonomous validation workflow relies on a single, powerful script for managing the application's lifecycle.

**`bash reports/run_session.sh`**

* **Purpose:** The unified script for starting, stopping, and managing a validation session.

* **Behavior:**

  * If no session is running, it builds the TypeScript assets and launches the Flutter app in the background. It stores the process ID and waits until the app is ready.

  * If a session is already running (detected via a `flutter.pid` file), it first terminates that old session before starting a new one.

* **Usage:**

  * To **start a new session** (or restart a stuck one): `bash reports/run_session.sh`

  * To **stop the current session**: `bash reports/run_session.sh` (The script's self-cleaning logic will handle the termination).

* **Output:**

  * The script outputs a unique `SESSION_ID` to stdout (format: `YYYY-MM-DD_HH-MM-SS`).

  * All session output is logged to `reports/run_${SESSION_ID}.log`.

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

### 1. Prefixed and Scoped Messages

All logs must be prefixed with a scope in square brackets to provide immediate context about their origin.

* **Format:** `[Scope] Message`

* **Examples:**
  * `[Engine] Bridge ready signal sent.` (General orchestrator)
  * `[AI Studio] Settings panel opened successfully.` (Provider-specific logic)
  * `[waitForElement] Still searching...` (Utility-specific logs)

* **Why:** In a hybrid app, this is the only way to quickly differentiate between logs from the general engine, a specific chatbot module, and a low-level utility.

### 2. The Intent-Action-Result (IAR) Pattern

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

### 3. Data-Rich Payloads, Not Verbose Dumps

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

## 4. Structured Error Diagnostics (The Critical Rule)

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

### 3.2. State Management (Riverpod 3.0+)

* **Use Modern Notifiers:** **ALWAYS** use code-generated `@riverpod` notifiers. **NEVER** use legacy `StateNotifier` or `ChangeNotifier`.
* **Check `ref.mounted` After `await`:** **ALWAYS** add `if (!ref.mounted) return;` after any `await` call in a provider method to prevent "use after dispose" errors.
* **Safely Access AsyncValue State:** When reading the state of an `AsyncNotifier` in a callback or non-reactive context, **ALWAYS** use `ref.read(provider).valueOrNull` or pattern matching to avoid runtime exceptions if the state is `AsyncLoading` or `AsyncError`.
* **Critical Anti-Pattern: `TabController`

#### 3.3. Hybrid Development (Timing, Delays, and Performance)

**Guiding Principle:** The application must remain performant and reliable on low-end devices and slow networks. To achieve this, we follow two core strategies: TypeScript-centric orchestration for speed, and configurable modifiers for resilience.

##### **The "Task Delegation" Mandate for Performance**

- **Guiding Principle:** To minimize latency, the Dart layer's role is to **delegate**, not to **micro-manage**. All sequential automation logic that occurs within the WebView MUST be orchestrated by the TypeScript engine (`automation_engine.ts`).

- ✅ **ALWAYS:** Consolidate all parameters (prompt, model, settings) into a single options object in Dart and pass it to a master `startAutomation` function in TypeScript with a single bridge call. The TypeScript layer is then responsible for the entire sequence (resetting state, applying settings, entering prompt, submitting).

- ❌ **NEVER:** Create a "chatty" bridge where Dart sends a sequence of individual commands to the WebView to execute a workflow (e.g., `await bridge.applyModel()`, then `await bridge.setTemperature()`, then `await bridge.sendPrompt()`). This introduces unnecessary latency at each step and is considered an anti-pattern.

##### **The Mandatory Timeout Modifier Pattern for Resilience**

- **Concept:** All timeouts within the TypeScript automation engine **MUST** be scalable via a `timeoutModifier` parameter passed from Dart. This allows users on slower devices or networks to increase timeouts without code changes.

- **Implementation:** The `AutomationOptions` object includes a `timeoutModifier` field (default: `1.0`). All timeout calculations in TypeScript multiply base timeouts by this modifier (e.g., `baseTimeout * options.timeoutModifier`).

- **Rationale:** This pattern ensures the app remains performant by default (fast timeouts) while providing a simple configuration path for users who need more patience on slower hardware or networks.
