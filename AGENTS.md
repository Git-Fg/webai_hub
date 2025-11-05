# AI Hybrid Hub - Agent Manifesto

Your primary mission is to assist in the development of the AI Hybrid Hub, a Flutter application bridging a native UI with web-based AI providers.

**Core Philosophy:** Prioritize simplicity, robustness, and maintainability. The code is the single source of truth; your contributions must be clear and self-documenting.

**Current Phase:** MVP-1.0. Focus on validating the core "Assist & Validate" workflow for the Google AI Studio provider. Refer to `@blueprint_mvp` for scope limitations.

---

### 1. The "Golden Rules": Non-Negotiable Workflow Commands

These are the three most critical commands. Forgetting them is the most common source of errors.

| Command                                                              | When to Run                                     | Why It's Critical                                                                                                   |
| :------------------------------------------------------------------- | :---------------------------------------------- | :------------------------------------------------------------------------------------------------------------------ |
| `npm run build`                                                      | After **ANY** modification in `ts_src/**`.      | The app loads the compiled `assets/js/bridge.js`, not the source `.ts` files. Without this, your changes have no effect. |
| `flutter pub run build_runner build --delete-conflicting-outputs`    | After **ANY** modification to `@riverpod` or `@freezed` annotations. | Providers and models rely on generated files (`*.g.dart`, `*.freezed.dart`). Stale code will cause compilation or runtime errors. |
| `flutter test`                                                       | Before **ANY** commit.                          | Ensures your changes have not introduced regressions. All new logic must be covered by unit tests.                  |

---

### 2. The Development Cycle: Understand → Modify → Verify

Follow this systematic cycle for every task.

#### 2.1. Phase 1: Understand

1. **Consult Blueprints:** Always start by reviewing `@blueprint_mvp` (current scope) and `@blueprint_full` (future vision).
2. **Explore the Codebase:** Use the file structure reference (Section 5.2) and aliases (Section 5.1) to navigate the project.
3. **Verify Documentation:** When using external libraries (Riverpod, InAppWebView), **ALWAYS** use `context7` to check the latest official documentation. Do not guess or rely on old knowledge.

#### 2.2. Phase 2: Modify

1. **Adhere to Golden Rules:** Run the build commands from Section 1 as required.
2. **Maintain Code Quality:** Follow the code quality and commenting philosophy (Section 4.1).
3. **Avoid Anti-Patterns:** Review the project-specific anti-patterns (Section 4) to ensure you are writing robust and maintainable code.

#### 2.3. Phase 3: Verify

1. **Run Unit Tests:** Use `flutter test` or the "Flutter Tests (Agent)" VS Code launch configuration.
2. **Perform Manual Checks:** For UI and workflow validation, use `mobile-mcp`.
    * Launch the app on a specific device with `flutter run -d <device_id>`.
    * **CRITICAL:** After launching the app via command line, **always wait at least 30 seconds** for the application to fully initialize and stabilize before interacting with it.

---

### 3. The Debugging Protocol: "Observe → Diagnose → Fix"

When a task requires verification or you encounter a bug, you **MUST** follow this protocol. Do not guess the cause of a problem; use the tools to prove it.

#### 3.1. Step 1: Observe the Behavior (`mobile-mcp`)

Before diagnosing, you must first understand **what** is happening.

* **To see the UI:** Use `mobile_take_screenshot`. This provides essential visual context.
* **To confirm UI elements:** Use `mobile_list_elements_on_screen` to verify if a widget is present and accessible.
* **To test a workflow:** Use `mobile_tap_on_screen` or `mobile_type_keys` to replicate the user journey that triggers the bug.

#### 3.2. Step 2: Diagnose the Root Cause (`dart-mcp` + Logs)

After observing the symptom, find the **why**. Your diagnostic process must follow this priority:

1. **Check for Crashes and Runtime Errors:**
    * **Tool:** `dart-mcp`
    * **Command:** `get_runtime_errors`
    * **When:** Always run this first. A runtime exception is the most likely culprit.

2. **Inspect Application State (Riverpod):**
    * **Tool:** `dart-mcp`
    * **When:** If the UI looks correct but the data is wrong or the app is stuck.
    * **Action:** Investigate the state of key providers: `automationStateProvider`, `conversationProvider`, `currentTabIndexProvider`.

3. **Analyze the Widget Tree:**
    * **Tool:** `dart-mcp`
    * **Command:** `get_widget_tree`
    * **When:** If a widget is visually missing or laid out incorrectly.

4. **Check the WebView Bridge:**
    * **When:** The native UI seems correct, but the WebView is not responding.
    * **Action 1:** Review **WebView Console Logs** (`onConsoleMessage` output). Look for JavaScript errors.
    * **Action 2:** Use `get_runtime_errors` (`dart-mcp`) to check for Dart-side exceptions from the `JavaScriptBridge`.

#### 3.3. Step 3: Fix and Verify

1. **Propose the Fix:** Based on your diagnosis, implement the code change.
2. **Verify the Fix:**
    * Run `npm run build` and/or `build_runner`.
    * Run `flutter test` to catch regressions.
    * Use `mobile-mcp` to re-run the exact workflow and use `mobile_take_screenshot` to provide visual proof that the bug is resolved.

#### 3.4. Practical Example: Debugging a Disabled Button

**Scenario:** The "Extract & View Hub" button remains disabled indefinitely.

1. **OBSERVE:** Use `mobile_take_screenshot` to confirm the disabled button visually.
2. **DIAGNOSE:**
    * Run `get_runtime_errors` (`dart-mcp`). **Result:** No errors.
    * **Hypothesis:** The state controlling the button is incorrect.
    * **Action:** Inspect `automationStateProvider`. **Result:** It is stuck in `.refining(isExtracting: true)`.
    * **Analysis:** The `isExtracting` flag is never reset to `false` on an error path in `extractAndReturnToHub`.
3. **FIX & VERIFY:**
    * **Action:** Propose a code change to `conversation_provider.dart` that adds a `finally` block to ensure the flag is always reset.
    * **Action:** Re-run the workflow with `mobile-mcp` and provide a final `mobile_take_screenshot` showing the button is correctly enabled.

---

### 4. Technical Best Practices & Anti-Patterns

#### 4.1. Code Quality & Commenting

* **Guiding Principle:** The code is the single source of truth. It should be so clear that it requires minimal comments.
* **The Golden Rule:** Comments must explain **"Why,"** not "What." Use `// WHY:` for strategic decisions and `// TIMING:` for justifying delays.

    ```dart
    // WHY: Truncate the conversation to the edited message to maintain
    // context consistency for the AI on the next prompt submission.
    final truncatedConversation = state.sublist(0, messageIndex + 1);
    ```

* **Zero-Tolerance for Debugging Artifacts:** Before any commit, remove all `print()`, `debugPrint()`, `console.log()`, and commented-out code blocks.

#### 4.2. State Management (Riverpod 3.0+)

* **Use Modern Notifiers:** **ALWAYS** use code-generated `@riverpod` `Notifier` (for sync state) or `AsyncNotifier` (for async state). **NEVER** use legacy `StateNotifier` or `ChangeNotifier`.
* **Check `ref.mounted` After `await`:** **ALWAYS** add `if (!ref.mounted) return;` after any `await` call in a provider method to prevent "use after dispose" errors.
* **Handle Provider Errors:** Catch `ProviderException` and unwrap the original error from `e.exception` to handle failures correctly.
* **Await Concurrently:** Use Dart 3's record pattern for parallel awaits: `final (user, settings) = await (fetchUser(), fetchSettings()).wait;`.
* **Use `unawaited`:** Wrap fire-and-forget futures with `unawaited()` to satisfy the linter and signal intent.
* **Critical Anti-Pattern: `TabController` for Business Logic:**
  * ❌ **NEVER:** `ref.read(tabControllerProvider)?.animateTo(1);`
  * ✅ **ALWAYS:** `ref.read(currentTabIndexProvider.notifier).changeTo(index);`
  * **Why:** `TabController` is a UI concern and cannot be safely accessed from business logic providers. `currentTabIndexProvider` is the single source of truth for navigation.

#### 4.3. Hybrid Development (Timing & Delays)

Delays are a pragmatic tool for hybrid apps but must be used judiciously.

* **Diagnose First:** Before adding a delay, always investigate alternatives: Is there a callback? A `Promise`? A `MutationObserver`?
* **Legitimate Use Cases:** Delays are acceptable for post-action stabilization (50-300ms after a `.click()`), waiting for opaque animations, or throttling.
* **Protocol for Modifying Delays:**
    1. **Diagnose:** Understand precisely why the current delay is insufficient.
    2. **Document:** Add or update a `// TIMING:` comment with the justification and date.
    3. **Adjust Minimally:** Increase the delay only by the amount required.
    4. **Re-evaluate:** Check if a more reliable method has become available.

#### 4.4. General Dart/Flutter Best Practices

* **Use Modern `.withValues(alpha: ...)` for Color Alpha:**
  * ❌ **NEVER:** `Colors.black.withOpacity(0.1);`
  * ✅ **ALWAYS:** `Colors.black.withValues(alpha: 0.1);`
  * **Why:** As of late 2024, `.withOpacity()` is deprecated and causes precision loss. `.withValues()` is the modern, accurate method.

---

### 5. Project Reference

#### 5.1. Critical File Aliases

* `@blueprint_mvp`: `BLUEPRINT_MVP.md` (Current scope & architecture)
* `@blueprint_full`: `BLUEPRINT_FULL.md` (Future vision & v2.0 architecture)
* `@automation_engine`: `ts_src/automation_engine.ts` (JS automation logic)
* `@conversation_provider`: `lib/features/hub/providers/conversation_provider.dart` (Dart state orchestration)
* `@webview_screen`: `lib/features/webview/widgets/ai_webview_screen.dart` (WebView implementation)
* `@contributing`: `CONTRIBUTING.md` (Guide for human developers)

#### 5.2. Critical File Structure

```text
lib/features/
├── hub          # Native chat UI
├── webview      # WebView + JS bridge
└── automation   # Workflow + overlay

ts_src/
└── automation_engine.ts  # JS engine (hardcoded selectors for MVP)
```

#### 5.3. Documentation & Verification Tools

* **`context7` (`mcp_context7_get-library-docs`):** **ALWAYS prefer this first** for up-to-date library documentation (Riverpod, InAppWebView, Freezed, etc.).
* **`web_search`:** Use for libraries not in context7, blog posts, or community discussions.

#### 5.4. Project Environment

* **Project Root:** `/Users/felix/Documents/Flutter/WebAI_Hub/`
* **Editor Hooks:** See `.vscode/settings.json` and `.vscode/launch.json`.
