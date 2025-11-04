# AGENTS.md

Guide for AI agents working on this Flutter AI Hybrid Hub project.

## 🎯 Project Context

This project is in **MVP** phase with a 2-tabs architecture (native Hub + WebView Google AI Studio). The goal is to validate the "Assist & Validate" workflow with a single provider before moving to the full version.

## 🤖 Specific Instructions for Agents

### Recommended Tools

Use these tools systematically when available:

- **mobile-mcp**: To test the application in real conditions
- **dart-mcp**: For Dart code analysis
- **context7**: For documentation searches

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
```

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

-   `print()` or `debugPrint()` statements.

-   `console.log()`, `console.warn()`, `console.error()`.

-   **Commented-out code blocks.** Your Git history is the only archive. Old code left in comments becomes technical debt and quickly goes stale.

### 🚫 Critical Anti-Patterns

#### Anti-Pattern 1: Using Flutter `TabController` for Business Logic

- ❌ **NEVER**: `final tabController = ref.read(tabControllerProvider); tabController?.animateTo(1);`
- ✅ **ALWAYS**: `ref.read(currentTabIndexProvider.notifier).changeTo(index)`
- **Why**: `TabController` is heavy to synchronize and cannot be shared between widgets and providers. See `BLUEPRINT_MVP.md` section 7.1 for details.

#### Timing Management Principle: Delays as Last Resort

Delays (`Future.delayed`, `setTimeout`) are powerful tools for managing asynchrony, but their abusive use masks underlying problems and creates a fragile application. They treat **symptoms** (an action fails because an element is not ready) and not the **cause** (why wasn't the element ready?).

- ❌ **Symptomatic Approach (to avoid)**: Add or increase a `Future.delayed(Duration(seconds: 2))` as soon as a timing problem appears, without investigation.

- ✅ **Fundamental Approach (Absolute Priority)**: **ALWAYS** start by looking for the root cause:
  - Is there an event or callback we can listen to? (ex: `onLoadStop`, a signal from the JS bridge)
  - Is a Riverpod provider state poorly synchronized?
  - Is it a race condition in the widget/WebView lifecycle?
  - Does the CSS selector target an element that appears after an animation? Can we wait for the end of the animation with a more precise `MutationObserver`?

#### When is a delay acceptable?

A delay is considered a **legitimate last resort** only in the following cases:

1. **Interaction with an opaque external system**: When waiting for the end of a CSS animation or a third-party script in the `WebView` that provides **no observable completion event**.

2. **Minimal safety cushion**: A very short delay (ex: 100-300ms) can be used to ensure the UI thread has had time to finalize a complex render after a state change, although solutions like `WidgetsBinding.instance.addPostFrameCallback` are often preferable.

**Golden rule**: If a delay is added, it must be **short**, **bounded**, and accompanied by a comment explaining **why** an event-based solution was not possible.

```dart
// TIMING: Wait 300ms to allow the panel closing animation to complete.
// No JS callback is available for this event.
await Future.delayed(const Duration(milliseconds: 300));
```

#### Rule for adjusting existing delays

It is sometimes necessary to increase an existing delay because the web page behavior has changed. **Never increase a delay blindly.**

**Mandatory workflow for modifying a delay:**

1. **Diagnose**: Understand *precisely why* the initial delay is no longer sufficient. (Ex: "The AI loading spinner now lasts on average 500ms longer").

2. **Document**: Add or update the comment to justify the increase.
   ```dart
   // TIMING (UPDATED 03/11/2025): Increased from 300ms to 800ms because the new AI interface
   // adds a fade animation that delays the button appearance.
   await Future.delayed(const Duration(milliseconds: 800));
   ```

3. **Adjust minimally**: Only increase the delay by the strictly necessary duration, with a small safety margin. Don't double the value "just in case".

4. **Consider the alternative**: Every time you touch a delay, ask yourself if a new detection method (a new attribute on an element, an event) hasn't become available.

**Conclusion: Every delay is technical debt. Justify it.**

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

### Debug Workflow

#### Debugging Principle

When facing an error, prioritize a systematic approach: **1. Observe** (behavior via `mobile-mcp`, screenshots), **2. Diagnose** (JS logs via `onConsoleMessage`, Riverpod state, CSS selectors), **3. Fix the root cause** (not the symptom), **4. Verify** (re-test complete workflow).

#### Debugging Guides

1. **WebView Problem**:
   - Verify that `npm run build` was executed after TypeScript modifications
   - Verify the JS bridge in `assets/js/bridge.js` (this file is generated, do not modify directly)
   - Verify JavaScript logs in the WebView console
2. **State Problem**: Verify Riverpod providers and generated files
3. **Build Problem**:
   - For TypeScript: Verify that `npm run build` executes without errors
   - For Dart: Verify that dependencies are synchronized (`flutter pub get`)
   - Verify that `build_runner` was launched after @riverpod/@freezed modifications

## 📁 Critical Structure

```text
lib/features/
├── hub/          # Native chat UI
├── webview/      # WebView + JS bridge
└── automation/   # Workflow + overlay

ts_src/
└── automation_engine.ts  # JS engine (hardcoded selectors MVP)
```

## 🔍 Points of Attention

- CSS selectors are **hardcoded** in TypeScript (MVP approach)
- Persistence is **in-memory** only (no Drift in MVP)
- Architecture is **2-tabs** and not 5-tabs like the full version
- Tests use **fakes** rather than complex mocks

## 🏗️ Critical Architectural Rules

⚠️ **Critical Rule**: NEVER use Flutter `TabController` for business logic. Use `ref.read(currentTabIndexProvider.notifier).changeTo(index)`. See `BLUEPRINT_MVP.md` section 7.1 for the complete explanation.
