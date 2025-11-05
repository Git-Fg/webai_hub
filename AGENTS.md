# AGENT MANIFESTO: AI Hybrid Hub

Your primary mission is to assist in the development of the AI Hybrid Hub, a Flutter application bridging a native UI with web-based AI providers.

Core Philosophy: Prioritize simplicity, robustness, and maintainability. The code is the single source of truth; your contributions must be clear and self-documenting.

Current Phase: MVP-1.0. Focus on validating the core "Assist & Validate" workflow for the Google AI Studio provider. Refer to @blueprint_mvp for scope limitations.

---

## 📚 Critical File References (Aliases)

- @blueprint_mvp: `BLUEPRINT_MVP.md` (Current scope & architecture)
- @blueprint_full: `BLUEPRINT_FULL.md` (Future vision & v2.0 architecture)
- @automation_engine: `ts_src/automation_engine.ts` (JS automation logic)
- @conversation_provider: `lib/features/hub/providers/conversation_provider.dart` (Dart state orchestration)
- @webview_screen: `lib/features/webview/widgets/ai_webview_screen.dart` (WebView implementation)
- @contributing: `CONTRIBUTING.md` (Guide for human developers)

---

## 🔁 Development Workflow (Understand → Modify → Verify)

### Phase 1 — Understand

1. Consult blueprints: @blueprint_mvp and @blueprint_full.
2. Explore the codebase (see Critical Structure below).
3. **ALWAYS verify documentation** using context7 when working with external libraries or frameworks. Don't guess—use the latest official documentation.
4. Use recommended tools: dart-mcp, context7, web_search; mobile-mcp for device runs.

### Phase 2 — Modify

Absolute Rules:

- TypeScript → npm run build after ANY modification in `ts_src/` (app uses compiled `assets/js/bridge.js`).
- Riverpod/Freezed → flutter pub run build_runner build --delete-conflicting-outputs after any `@riverpod` / `@freezed` change.

Symptoms if you forget the TypeScript build:

- TypeScript modifications are not reflected in the app
- JavaScript errors appear in the WebView console
- Functions are not found when called from Dart

Code Quality:

- Explain "Why", not "What" (use // WHY: and // TIMING: where relevant).
- Zero tolerance for debugging artifacts (no print/debugPrint/console.log; no commented-out code).

Anti-Patterns / Timing:

- Never use TabController for business logic; use `ref.read(currentTabIndexProvider.notifier).changeTo(index)`.
- Avoid delays; only as last resort with a short, justified // TIMING: comment.

### Phase 3 — Verify

- Run unit tests: `flutter test` (or VS Code: Run configuration "Flutter Tests (Agent)").
- For manual checks: use mobile-mcp and `flutter run -d <device_id>`.

---

## 🌍 Project Environment

- Project Root: `/Users/felix/Documents/Flutter/WebAI_Hub/`
- Editor Hooks: see `.vscode/settings.json` (format on save, markdownlint) and `.vscode/launch.json` (includes "Flutter Tests (Agent)").

---

# AGENTS.md

Guide for AI agents working on this Flutter AI Hybrid Hub project.

## 🎯 Project Context

This project is in **MVP** phase with a 2-tabs architecture (native Hub + WebView Google AI Studio). The goal is to validate the "Assist & Validate" workflow with a single provider before moving to the full version.

## 🤖 Specific Instructions for Agents

### Essential Commands

```bash
# ⚠️ CRITICAL: Build TypeScript after ANY modification in ts_src/
npm run build

# Code generation after Riverpod/Freezed changes
flutter pub run build_runner build --delete-conflicting-outputs

# Unit tests
flutter test

# Launch app (specific device)
flutter run -d <device_id>

# after running it, always wait at least 30 sec the time the app runs
```

### 🔍 Documentation & Verification Tools

**ALWAYS use documentation tools when in doubt or when verifying the latest best practices.**

When you need to verify documentation, check API usage, or ensure you're using the most modern approach, you **MUST** use these tools:

- **context7** (`mcp_context7_get-library-docs`): **ALWAYS prefer this first** for up-to-date library documentation. It provides the latest, most accurate documentation for popular libraries and frameworks. Use it whenever you have any doubt about:
  - API usage or function signatures
  - Best practices and patterns
  - Latest features and updates
  - Type definitions and interfaces
  - Migration guides and breaking changes

- **web_search**: Use alongside context7 for:
  - Libraries not available in context7
  - Recent announcements or blog posts
  - Community discussions and GitHub issues
  - Stack Overflow answers for specific edge cases

**Golden Rule**: When modifying code that uses external libraries or frameworks, **ALWAYS** verify the latest documentation using context7 first. Don't rely on memory or outdated knowledge. The simplest and most modern approach is usually the correct one, and context7 helps you find it.

**Libraries used in this project (with context7 IDs):**

- **Flutter Riverpod** (state management): `/rrousselgit/riverpod`
- **Flutter InAppWebView** (WebView integration): `/pichillilorenzo/inappwebview.dev`
- **Freezed** (code generation): `/rrousselgit/freezed`
- **Vite** (TypeScript build tool): `/vitejs/vite`
- **TypeScript**: `/microsoft/typescript`

**Other commonly available libraries in context7 include** (among many others):

- React: `reactjs/react.dev`
- Flutter/Dart: Use `mcp_dart_*` tools for Dart-specific documentation
- Shadcn: `shadcn-ui/ui`
- Vercel AI SDK: `vercel/ai`
- Radix UI: `radix-ui/website`

Use `mcp_context7_resolve-library-id` to find the correct library ID before fetching documentation.

### ⚠️ TypeScript Workflow - MANDATORY

**ABSOLUTE RULE**: After **ANY** modification in `ts_src/`, you **MUST** execute:

```bash
npm run build
```

**Why**: TypeScript files in `ts_src/` are compiled to `assets/js/bridge.js`. Flutter loads the compiled JavaScript bundle, so:

- ✅ Modify `automation_engine.ts` → **MANDATORY**: `npm run build`
- ✅ Change CSS selectors → **MANDATORY**: `npm run build`
- ✅ Add/remove global functions → **MANDATORY**: `npm run build`
- ✅ Modify signature of a function called from Dart → **MANDATORY**: `npm run build`
- ✅ Change TypeScript dependencies → **MANDATORY**: `npm install` then `npm run build`

**Symptoms if you forget**:

- TypeScript modifications are not reflected in the app
- JavaScript errors in the WebView console
- Functions not found when called from Dart

### Work Rules

1. **Always check blueprints** before any modification
2. **Respect MVP philosophy** - stay simple and functional
3. **Use Tree** to explore the tree structure before creating files
4. **Run `npm run build`** after **ANY** TypeScript modification in `ts_src/`
5. **Run build_runner** after any modification of generated Dart code (@riverpod, @freezed)
6. **Use `keepAlive: true`** for shared services/states (`webViewControllerProvider`) and `autoDispose` (default) for screen states. See `BLUEPRINT_MVP.md` section 7.4 for the decision guide.

### 📜 Code Quality & Commenting Philosophy

**Our guiding principle: The code is the single source of truth.** Your code should be so clear that it requires minimal comments. Comments are a necessary utility, not a replacement for readable code.

#### 1. The Golden Rule of Commenting: Explain "Why", not "What"

A comment must explain *why* a decision was made, or provide context that is impossible to infer from the code itself. It must **never** state *what* the code is doing.

**Dart Examples:**

❌ **BAD ("What" comment - useless):**

```dart
// Get the last message
final lastMessage = state.last;
```

✅ **GOOD ("Why" comment - essential context):**

```dart
// WHY: Truncate the conversation to the edited message to maintain
// context consistency for the AI on the next prompt submission.
final truncatedConversation = state.sublist(0, messageIndex + 1);
```

✅ **GOOD ("TIMING" comment - critical justification):**

```dart
// TIMING: Wait 300ms to allow the panel closing animation to complete.
// No JS callback is available for this event.
await Future.delayed(const Duration(milliseconds: 300));
```

**TypeScript Examples:**

❌ **BAD ("What" comment - useless):**

```typescript
// Click the button
sendButton.click();
```

✅ **GOOD ("Why" comment - essential strategy):**

```typescript
// WHY: Start from the "Edit" button and traverse up the DOM. This is a more
// stable anchor than relying on the container's auto-generated class name.
const lastEditButton = allEditButtons[allEditButtons.length - 1] as HTMLElement;
const parentTurn = lastEditButton.closest('ms-chat-turn');
```

#### 2. Zero-Tolerance Policy for Debugging Artifacts

Committing debugging artifacts is strictly forbidden. They pollute the codebase, create noise in logs, and are a sign of incomplete work.

**The following must be removed before any commit:**

- `print()` or `debugPrint()` statements.

- `console.log()`, `console.warn()`, `console.error()`.

- **Commented-out code blocks.** Your Git history is the only archive. Old code left in comments becomes technical debt and quickly goes stale.

### 🚫 Critical Anti-Patterns

#### Anti-Pattern 1: Using Flutter `TabController` for Business Logic

- ❌ **NEVER**: `final tabController = ref.read(tabControllerProvider); tabcontroller?.animateTo(1);`
- ✅ **ALWAYS**: `ref.read(currentTabIndexProvider.notifier).changeTo(index)`
- **Why**: `TabController` is heavy to synchronize and cannot be shared between widgets and providers. See `BLUEPRINT_MVP.md` section 7.1 for details.

#### Timing Management: A Pragmatic Approach to Delays

In a hybrid application interacting with a third-party WebView, timing is complex. Delays (`Future.delayed`, `setTimeout`) are a **necessary and pragmatic tool** for handling asynchrony, especially when waiting for DOM updates, animations, or framework lifecycle events that don't offer callbacks.

Our principle is not to forbid delays, but to use them **judiciously and with clear justification**. An unexamined delay is technical debt; a well-documented delay is a solution.

#### The "Diagnose-First" Principle

Before adding a new delay or increasing an existing one, your **first step** is always to investigate the root cause. A quick check can often reveal a more robust, event-driven solution. Ask yourself:

- **Is there an event or callback we can listen to?** (e.g., `onLoadStop`, a signal from the JS bridge, a JS `Promise` we can await).
- **Can we observe the change?** Can a `MutationObserver` reliably detect the element we are waiting for?
- **Is this a state synchronization issue?** Could a Riverpod provider be updated more predictably?
- **Can we poll for a specific condition?** Instead of a blind wait, can we check for an element's attribute or visibility in a loop (like the `waitForElement` utility)?

#### Legitimate Use Cases for Delays

A delay is a perfectly acceptable tool in several common scenarios in this project:

1. **Post-Action Stabilization:** After a programmatic action (like `.click()`) that triggers a UI update or animation in the WebView, a short, fixed delay (e.g., 50-300ms) can be the most reliable way to wait for the web framework's event loop to settle.
2. **Opaque External Systems:** When waiting for something that provides no observable completion event, such as a CSS animation fading in a button.
3. **Throttling/Debouncing:** Intentionally slowing down operations to prevent rate-limiting or to wait for user input to cease.

#### The Protocol for Modifying Delays

It is sometimes necessary to adjust an existing delay because the web page's behavior has changed. **Never increase a delay blindly.** You must follow this workflow:

1. **Diagnose:** Understand *precisely why* the initial delay is no longer sufficient. (e.g., "The AI loading spinner now has a 200ms fade-out animation that wasn't there before.").
2. **Document:** Add or update the `// TIMING:` comment to justify the change and record the date. This history is invaluable.

   ```dart
   // TIMING (UPDATED 11/2025): Increased from 300ms to 500ms to account for the new 
   // fade-out animation on the response container. No JS callback is available.
   await Future.delayed(const Duration(milliseconds: 500));
   ```

3. **Adjust Minimally:** Only increase the delay by the amount required to restore reliability, plus a small safety margin. Do not double the value "just in case."
4. **Re-evaluate Alternatives:** Every time you touch a delay, ask: "Has a new, more reliable method (like a new element ID or attribute) become available since this was last touched?"

**Golden Rule:** Every delay is a form of technical debt. Justify its existence and cost with a clear comment.

#### Anti-Pattern 2: Outdated Riverpod and Async Patterns

The project uses Riverpod 3.0+. Adhere to its modern patterns to ensure safety, performance, and maintainability.

**1. Use Modern Notifiers, Not Legacy `StateNotifier`**

- ❌ **NEVER**: Use `StateNotifierProvider`, `StateNotifier`, or `ChangeNotifierProvider`. They are considered legacy and are not used in this project.
- ✅ **ALWAYS**: Use the modern, code-generated `@riverpod` annotation to create `Notifier` or `AsyncNotifier` classes.

**The choice between `Notifier` and `AsyncNotifier` is simple and depends on how the state is initialized:**

- **Use `Notifier` for SYNCHRONOUS state:** The `build()` method returns a value directly. This is for state that you create and manage within the app, like the current conversation list.
- **Use `AsyncNotifier` for ASYNCHRONOUS state:** The `build()` method returns a `Future` or is marked `async`. This is for state that must be fetched from an external source (database, network) during initialization. Riverpod will automatically manage the `AsyncLoading`, `AsyncData`, and `AsyncError` states for you.

**`Notifier` (Synchronous) Example - Correct for `ConversationProvider`**

```dart
// WHY: The conversation starts as an empty list. It is built and modified
// synchronously by user actions. This is the perfect use case for Notifier.
@riverpod
class Conversation extends _$Conversation {
  @override
  List<Message> build() => []; // State is initialized synchronously

  void addMessage(String text, bool isFromUser) {
    // Methods modify the synchronous state directly.
    state = [...state, Message(...)];
  }
}
```

**`AsyncNotifier` (Asynchronous) Example - Correct for `GeneralSettingsProvider`**

```dart
// WHY: The settings must be loaded asynchronously from SharedPreferences
// when the provider is first initialized. This is the perfect use case for AsyncNotifier.
@riverpod
class GeneralSettings extends _$GeneralSettings {
  @override
  Future<GeneralSettingsData> build() async {
    // The build method is async and returns a Future.
    // Riverpod handles the initial loading state for us.
    final service = await _getSettingsService();
    return service.loadSettings();
  }

  Future<void> updateSettings(GeneralSettingsData newSettings) async {
    // Async methods use AsyncValue.guard to handle loading/error states.
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = await _getSettingsService();
      await service.saveSettings(newSettings);
      return newSettings;
    });
  }
}
```

**2. Always Check `ref.mounted` After `await`**

- ✅ **ALWAYS**: `if (!ref.mounted) return;`
- **Why**: Prevents "use after dispose" errors. If a provider is disposed while an async operation is in flight, accessing its state or `ref` will cause a crash. This check ensures safety.

```dart
final user = await ref.read(userRepositoryProvider).fetchUser();
if (!ref.mounted) return; // CRITICAL check after await
state = state.copyWith(user: user);
```

**3. Handle Provider Errors Correctly with `ProviderException`**

- ✅ **DO**: Catch `ProviderException` and unwrap the original error from `e.exception`.
- **Why**: Riverpod 3.0 wraps errors. This pattern allows you to distinguish between a provider that failed itself versus a provider that failed because one of its dependencies failed.

```dart
try {
  ref.watch(myFailingProvider);
} on ProviderException catch (e) {
  // Unwrap the original, specific error
  final originalError = e.exception;
  // Now handle the originalError
}
```

**4. Await Futures Concurrently**

- ❌ **NEVER**: `await futureA; await futureB;` if they are independent.
- ✅ **ALWAYS**: `final (resultA, resultB) = await (futureA, futureB).wait;`
- **Why**: Awaiting independent futures sequentially is inefficient. Using Dart 3's record pattern with `.wait` runs them in parallel, significantly improving performance.

```dart
// GOOD: Fetches user and settings in parallel
final (user, settings) = await (
  ref.read(userRepositoryProvider).fetchUser(),
  ref.read(settingsRepositoryProvider).fetchSettings(),
).wait;
```

**5. Use `unawaited` for Fire-and-Forget Futures**

- ✅ **DO**: Wrap futures you don't `await` with `unawaited()`.
- **Why**: This signals to the linter (`unawaited_futures`) and other developers that you are intentionally not waiting for the future to complete. It prevents unhandled exceptions from being silently swallowed.

```dart
// GOOD: Intent is clear, and linter is satisfied.
unawaited(analytics.logEvent('user_action'));
```

### Common Errors to Avoid

- ❌ **FORGETTING `npm run build` after TypeScript modification** - **CRITICAL ERROR**
  - Modifications in `ts_src/` are not reflected without build
  - The app still uses the old `assets/js/bridge.js`
  - JavaScript functions called from Dart will not be found
- ❌ Forgetting `build_runner` after adding `@riverpod` or `@freezed`
- ❌ Modifying TypeScript without verifying that `npm run build` executes without errors
- ❌ Committing TypeScript modifications without having run `npm run build` beforehand
- ❌ Writing "What" comments instead of "Why" comments. See the "Code Quality Philosophy" section.
- ❌ Committing any debugging artifacts (`print`, `console.log`, commented-out code).

### Real Application Testing

When using mobile-mcp:

- Never uninstall/reinstall the app (disconnection)
- Wait ~20s after restart for stabilization
- Use `flutter run -d <device_id>` to target a device

### 🤖 The Systematic "Observe → Diagnose → Fix" Protocol

Your primary mission is to build and maintain the application. When a task requires verification or when you encounter a bug, you **MUST** follow this protocol. Do not guess the cause of a problem; use the tools to prove it.

#### Phase 1: Observe the Behavior (`mobile-mcp`)

Before diagnosing, you must first understand **what** is happening. Use `mobile-mcp` to interact with the running application and capture the state of the UI.

- **To see the UI:** Use `mobile_take_screenshot`. This provides essential visual context of the problem.

- **To confirm UI elements:** Use `mobile_list_elements_on_screen` to verify if a widget is present, visible, and accessible.

- **To test a workflow:** Use `mobile_tap_on_screen` or `mobile_type_keys` to replicate the user journey that triggers the bug.

**You must include the output (especially screenshots) in your analysis.**

#### Phase 2: Diagnose the Root Cause (`dart-mcp` + Logs)

After observing the symptom with `mobile-mcp`, use `dart-mcp` and logs to find the **why**.

**Your diagnostic process must follow this priority:**

**1. Check for Crashes and Runtime Errors:**

- **Tool:** `dart-mcp`

- **Command:** `get_runtime_errors`

- **When:** Always run this first if the app is unresponsive, has crashed, or behaves unexpectedly. A runtime exception is the most likely culprit.

**2. Inspect Application State (Riverpod):**

- **Tool:** `dart-mcp`

- **Problem:** The UI *looks* correct, but the data is wrong, a button is disabled, or the app is stuck in a state. This is likely a state management issue.

- **Action:** Investigate the state of the key Riverpod providers.

  - **`automationStateProvider`**: Is the app stuck in `sending`, `observing`, or `failed`?

  - **`isExtractingProvider`**: Is the "Extract" button disabled because this is unexpectedly `true`?

  - **`conversationProvider`**: Does the list of messages match what's on screen? Is the last message in an `error` state?

  - **`currentTabIndexProvider`**: Is the app on the wrong tab?

**3. Analyze the Widget Tree:**

- **Tool:** `dart-mcp`

- **Command:** `get_widget_tree`

- **When:** If a widget is visually missing or laid out incorrectly, this command confirms whether it exists in the Flutter widget hierarchy at all. Compare this with the output of `mobile_list_elements_on_screen`.

**4. Check the WebView Bridge:**

- **Context:** The native UI and Riverpod state seem correct, but the WebView is not responding.

- **Action:**

  1. Review the **WebView Console Logs** (`onConsoleMessage` output). Look for JavaScript errors like "function not found" or "null is not an object". This is the most common source of WebView issues.

  2. Use `get_runtime_errors` (`dart-mcp`) to check for Dart-side exceptions originating from the `JavaScriptBridge`.

#### Phase 3: Fix and Verify

1. **Propose the Fix:** Based on your diagnosis from Phase 2, implement the code change.

2. **Verify the Fix:**

   - Run `npm run build` (if TS changed) and/or `build_runner`.

   - Run `flutter test` to catch any regressions.

   - Use `mobile-mcp` to re-run the exact same workflow from Phase 1.

   - Use `mobile_take_screenshot` to provide visual proof that the bug is resolved.

---

### 💡 Practical Example: Debugging a Disabled Button

**Scenario:** The user reports that after sending a prompt, the "Extract & View Hub" button sometimes remains disabled indefinitely.

**Your Thought Process & Actions:**

1. **OBSERVE:**

   - **Action:** Use `mobile-mcp` to launch the app and send a prompt. Wait for the automation to reach the refinement phase.

   - **Action:** Use `mobile_take_screenshot`.

   - **Output:** *You provide the screenshot showing the disabled button.*

   - **Analysis:** "I have confirmed the 'Extract & View Hub' button is disabled when it should be active."

2. **DIAGNOSE:**

   - **Hypothesis 1 (Crash):** "First, I will check for any runtime errors."

     - **Action:** Run `get_runtime_errors` with `dart-mcp`.

     - **Output:** *You provide the (empty) list of errors.*

     - **Conclusion:** "No runtime errors. The issue is likely state-related."

   - **Hypothesis 2 (State):** "The button is disabled when `isExtractingProvider` is `true`. I will inspect the provider's state."

     - **Action:** *(As of Nov 2025, an agent would describe its internal check or use a conceptual tool to check the provider's value).* "I am inspecting the state of `isExtractingProvider`. The logs show its value is `true`."

     - **Analysis:** "Diagnosis complete. The `isExtractingProvider` is being set to `true` but is never reset to `false` in the case of an extraction error. This is a bug in the `extractAndReturnToHub` method in `conversation_provider.dart`."

3. **FIX & VERIFY:**

   - **Action:** "I will add a `finally` block in `extractAndReturnToHub` to ensure `isExtractingProvider` is always set to `false`."

   - **Action:** *Propose the code change for `conversation_provider.dart`.*

   - **Action:** "Now I will verify the fix. I have re-built the app and will repeat the initial steps."

   - **Action:** Use `mobile-mcp` to trigger the same workflow, including the error condition.

   - **Action:** Use `mobile_take_screenshot`.

   - **Output:** *You provide the new screenshot showing the button is now enabled after the workflow completes.*

   - **Conclusion:** "The fix is verified. The button is now correctly enabled."

## 📁 Critical Structure

```text
lib/features/
├── hub          # Native chat UI
├── webview      # WebView + JS bridge
└── automation   # Workflow + overlay

ts_src/
└── automation_engine.ts  # JS engine (hardcoded selectors MVP)
```

## 🔍 Points of Attention

- CSS selectors are **hardcoded** in TypeScript (MVP approach)
- Persistence is **in-memory** only (no Drift in MVP)
- Architecture is **2-tabs** and not 5-tabs like the full version
- Tests use **fakes** rather than complex mocks

## 🏗️ Critical Constraints

Always priorize using your native tools over fragile cli commands. You have a lot of tools : use them !
Make sure to always wait 30sec after running flutter run -d ...

## 🏗️ Critical Architectural Rules

⚠️ **Critical Rule**: NEVER use Flutter `TabController` for business logic. Use `ref.read(currentTabIndexProvider.notifier).changeTo(index)`. See `BLUEPRINT_MVP.md` section 7.1 for the complete explanation.
