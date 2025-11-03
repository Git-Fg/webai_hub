# CLAUDE.md

This file provides guidance to the AI Agent when working with code in this repository.

## 🎯 Project Philosophy

**IMPORTANT**: This is a **personal project** focused on **simplicity, modernity, and elegance**. The goal is to create beautiful, maintainable code that demonstrates advanced Flutter patterns.

-   **🎯 Simplicity First**: Choose the simplest solution that works well.
-   **🚀 Modern Code**: Use current best practices (Flutter 3.19+, Riverpod Generators).
-   **🧱 Follow the Blueprints**: Adhere to `BLUEPRINT.md` for the complete architectural vision and `BLUEPRINT_MVP.md` for the current implementation phase.

## Project Overview

**AI Hybrid Hub** is a Flutter application that creates a multi-provider AI assistant. The project implements an "Assist & Validate" workflow by bridging a native mobile UI with web-based AI providers through a robust JavaScript automation engine.

## 🛠️ Development Commands

### Basic Setup
```bash
# Install Flutter dependencies
flutter pub get

# Install TypeScript dependencies
npm install
```

### Code Generation & Building
```bash
# Build the TypeScript bridge (run after every change in ts_src/)
npm run build

# Generate Dart code (Riverpod/Freezed)
flutter pub run build_runner build --delete-conflicting-outputs
```

**CRITICAL**: You MUST run `npm run build` if you perform any of the following actions:

#### 1. For TypeScript (`ts_src/`)
✅ **Modify any TypeScript file** in `ts_src/` directory (especially `automation_engine.ts`).
✅ **Change function signatures** exported to Dart (e.g., `startAutomation`, `extractFinalResponse`).
✅ **Add or remove global functions** that are called from Dart via JavaScript bridge.
✅ **Modify CSS selectors** or DOM manipulation logic.
✅ **Change TypeScript dependencies** in `package.json` (after running `npm install`).

**IMPORTANT**: The TypeScript source files in `ts_src/` are compiled to `assets/js/bridge.js`. Flutter loads the compiled JavaScript bundle, so **any change to TypeScript files requires running `npm run build`** before testing or committing.

**CRITICAL**: You MUST run build_runner if you perform any of the following actions:

#### 2. For Riverpod (@riverpod)
✅ **Create a new provider** by annotating a class or function with @riverpod.
✅ **Rename an existing provider** (e.g., Conversation becomes ChatConversation).
✅ **Change provider parameters** (e.g., myProvider(ref) becomes myProvider(ref, String userId)).
✅ **Change provider return type** (e.g., returning List<Message> now returns Future<List<Message>>).

#### 3. For Freezed (@freezed)
✅ **Create new model class** annotated with @freezed (as done for Message model).
✅ **Add, remove, or rename fields** in @freezed class (e.g., adding DateTime timestamp to Message model).
✅ **Change field types** in @freezed class.
✅ **Add or modify factories** (e.g., for creating union types for state management).

#### 4. For Project Configuration
✅ **Add new dependencies** that use build_runner in pubspec.yaml (after running flutter pub get).
✅ **Update package versions** like riverpod_generator or freezed, as new versions may generate different code.

### Testing
```bash
# Run unit tests
flutter test

# Run tests with coverage
flutter test --coverage
```

### Running the App
```bash
# Run the app in debug mode
flutter run

# Run on specific device (if multiple devices connected)
flutter run -d <device_id>
```

## Core Architecture

### Technology Stack
-   **Framework**: Flutter >= 3.19.0
-   **State Management**: `flutter_riverpod` with `riverpod_generator`.
-   **WebView**: `flutter_inappwebview` is the required package for its powerful JS bridge.
-   **Database**: **Drift** is planned for type-safe SQLite persistence in the full version (currently not used in MVP).
-   **JS Bridge**: TypeScript (`ts_src/`) built with Vite into a single bundle (`assets/js/`).

### Automation Engine

-   **Selector Strategy**: Currently **hardcoded CSS selectors** in TypeScript (MVP approach). The full version will use a remote **JSON configuration** for CSS selectors to allow updates without deploying a new app version.
-   **Error Handling**: Currently implements basic error handling with generic `AUTOMATION_FAILED` error code (MVP approach). The full version will include specific heuristic triage for CAPTCHA, login required, selector exhaustion, etc.
-   **State Monitoring**: Currently uses a simplified `MutationObserver` with basic debouncing technique (MVP approach). The full version will implement performance-optimized patterns like the "Ephemeral Two-Step Observer" for better battery efficiency.

### JavaScript Bridge API Contract

**IMPORTANT**: The communication pattern is **Asynchronous RPC (Remote Procedure Call)**.

1.  **TypeScript (`automation_engine.ts`)** must expose global, Promise-based functions for Dart to call (e.g., `startAutomation`, `extractFinalResponse`).
2.  **Dart** must register `JavaScriptHandler`s to handle events and requests from TypeScript. The primary handler for status updates is named `'automationBridge'`.

Always refer to the active blueprint for the precise API contract for the current development phase.

### Riverpod Provider Lifecycle: autoDispose vs keepAlive

**CRITICAL DECISION**: Choosing the correct lifecycle mode for providers is essential to avoid state synchronization issues and memory leaks.

#### When to Use `autoDispose` (Default `@riverpod`)

✅ **Use for state specific to a single screen/widget**:
- `TextEditingController` for form inputs
- Carousel or tab index within a single screen
- Local dialog or bottom sheet state
- Temporary cache for screen-specific data

✅ **Use for FutureProvider/StreamProvider loading screen data**:
- Data that should refresh when user leaves and returns to screen
- Example: `@riverpod Future<List<Item>> screenData(Ref ref) async { ... }`

**Benefit**: Automatic memory cleanup when screen is no longer used.

#### When to Use `keepAlive: true` (`@Riverpod(keepAlive: true)`)

✅ **Use for services and repositories**:
- API clients, authentication services
- Data repositories
- Business logic providers
- Example in project: `javaScriptBridgeProvider` (already keepAlive by default)

✅ **Use for state shared across multiple screens**:
- User authentication state
- Application theme
- Global navigation state
- Example in project: `bridgeReadyProvider` - shared between WebView widget, test containers, and business providers

✅ **Use for handles to unique resources**:
- WebView controller (unique instance to share)
- Example in project: `webViewControllerProvider` - unique reference to `InAppWebViewController`
- Database connections
- Network clients

✅ **Use for global automation/navigation state**:
- Current tab index (`currentTabIndexProvider`)
- Global automation status (`automationStateProvider`)

#### Problem Solved in Integration Test

During development of `bridge_communication_test.dart`, a critical issue was identified: `BridgeReady` and `WebViewController` providers were auto-dispose by default, creating **separate instances** between the widget and external test container, preventing state synchronization.

**Solution**: Using `@Riverpod(keepAlive: true)` ensures these shared providers maintain the same instance across all contexts.

#### Decision Checklist

Before creating a provider, ask:

1. **Is this provider used by multiple screens/widgets?**
   - Yes → `keepAlive: true`
   - No → `autoDispose` (default)

2. **Does this provider represent a unique resource (controller, service)?**
   - Yes → `keepAlive: true`
   - No → `autoDispose` (default)

3. **Is this provider accessible from external containers (tests, business providers)?**
   - Yes → `keepAlive: true`
   - No → `autoDispose` (default)

4. **Is this provider screen-specific and should refresh on each visit?**
   - Yes → `autoDispose` (default)
   - No → `keepAlive: true`

#### Symptoms of Wrong Choice

**If using `autoDispose` for shared provider**:
- ❌ Different instances created in different contexts
- ❌ Updates not visible between widget tree and external container (tests)
- ❌ Provider disposes prematurely while still used elsewhere

**If using `keepAlive` for screen-local state**:
- ❌ Memory leak: state retained after navigation
- ❌ Stale data reused after navigation
- ❌ Performance degradation (providers not disposed unnecessarily)

## 📋 Version Management & Milestones

**CRITICAL**: This project follows strict versioning practices with milestone-based commits.

### Commit Policy
- **ALWAYS commit on meaningful milestones** - never leave work uncommitted
- **Milestones include**:
  - Major feature completions
  - Bug fixes that restore functionality
  - Documentation updates (like this one)
  - Code refactoring that improves maintainability
- **Commit messages must follow conventional format**:
  ```bash
  feat: add new automation workflow
  fix: resolve WebView initialization issue
  refactor: simplify state management
  ```

### Version Control Workflow
1. **Complete a meaningful unit of work**
2. **Test the functionality thoroughly**
3. **Commit with descriptive message**

**Remember**: Uncommitted work is lost work. Commit frequently and meaningfully!

## 🧹 Code Quality Standards

**CRITICAL**: Maintain clean, professional code quality at all times.

### Code Cleanliness Policy
- **NEVER add unnecessary comments** - code should be self-documenting
- **Remove all debug statements** before committing (print, console.log, etc.)
- **Delete unused imports and variables**
- **Keep functions focused and small** - single responsibility principle
- **Use meaningful variable and function names** - no abbreviations unless universally understood
- **Follow Dart/Flutter style guidelines** consistently

### Timing & Delays Policy

**ANTI-PATTERN**: Adding delays/timeouts as a first solution to timing issues.

- **NEVER** add `Future.delayed()` or `setTimeout()` without first investigating the root cause
- **ALWAYS** search for underlying issues first:
  - Race conditions in widget/WebView lifecycle
  - Provider state synchronization problems
  - Events firing in wrong order
  - Incorrect CSS selectors or DOM elements not being available
  - Missing `await` keywords causing async issues
- **REMOVE delays immediately** if they solve symptoms but not the cause
- **ONLY use delays** when absolutely necessary and document why clearly
- **REDUCE delays** progressively once stability is proven - they add latency to the user experience

### When Comments Are Acceptable
Comments should ONLY be used when:
- Explaining complex business logic that isn't obvious
- Documenting public API contracts
- Warning about potential side effects or breaking changes
- Temporary TODO comments for immediate follow-up (should be removed promptly)

### Code Review Checklist
Before committing, ensure:
- [ ] No unnecessary comments
- [ ] No debug print statements
- [ ] All unused code removed
- [ ] Consistent formatting and naming
- [ ] Functions have clear, single purposes
- [ ] Error handling is appropriate but not overly verbose

**Principle**: If you need to add a comment to explain what the code does, consider rewriting the code to be more self-explanatory instead.