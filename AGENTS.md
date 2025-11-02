# CLAUDE.md

This file provides guidance to the AI Agent when working with code in this repository.

## 🎯 Project Philosophy

**IMPORTANT**: This is a **personal project** focused on **simplicity, modernity, and elegance**. The goal is to create beautiful, maintainable code that demonstrates advanced Flutter patterns.

-   **🎯 Simplicity First**: Choose the simplest solution that works well.
-   **🚀 Modern Code**: Use current best practices (Flutter 3.19+, Riverpod Generators).
-   **🧱 Follow the Blueprints**: Adhere to `BLUEPRINT.md` for the complete architectural vision and `BLUEPRINT_MVP.md` for the current implementation phase.

**IMPORTANT** : You must ALWAYS use your available tool (context7, mobile-mcp, dart-mcp ...) as soon as it's relevant. Never hesitate to use them as it give you the ability to be fully autonomous in your work.

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

**CRITICAL**: You MUST run build_runner if you perform any of the following actions:

#### 1. For Riverpod (@riverpod)
✅ **Create a new provider** by annotating a class or function with @riverpod.
✅ **Rename an existing provider** (e.g., Conversation becomes ChatConversation).
✅ **Change provider parameters** (e.g., myProvider(ref) becomes myProvider(ref, String userId)).
✅ **Change provider return type** (e.g., returning List<Message> now returns Future<List<Message>>).

#### 2. For Freezed (@freezed)
✅ **Create new model class** annotated with @freezed (as done for Message model).
✅ **Add, remove, or rename fields** in @freezed class (e.g., adding DateTime timestamp to Message model).
✅ **Change field types** in @freezed class.
✅ **Add or modify factories** (e.g., for creating union types for state management).

#### 3. For Project Configuration
✅ **Add new dependencies** that use build_runner in pubspec.yaml (after running flutter pub get).
✅ **Update package versions** like riverpod_generator or freezed, as new versions may generate different code.

### Running the App
```bash
# Run the app in debug mode
flutter run
```

## Core Architecture

### Technology Stack
-   **Framework**: Flutter >= 3.19.0
-   **State Management**: `flutter_riverpod` with `riverpod_generator`.
-   **WebView**: `flutter_inappwebview` is the required package for its powerful JS bridge.
-   **Database**: **Drift** is used for type-safe SQLite persistence in the full version.
-   **JS Bridge**: TypeScript (`ts_src/`) built with Vite into a single bundle (`assets/js/`).

### Automation Engine

-   **Selector Strategy**: The engine's resilience relies on a remote **JSON configuration** for CSS selectors. This allows for updates without deploying a new app version. For development, selectors may be temporarily hardcoded as specified in the relevant blueprint.
-   **Error Handling**: The engine must diagnose failures (e.g., CAPTCHA, login required) and report specific error codes to the Dart layer for graceful degradation.
-   **State Monitoring**: Use `MutationObserver` with performance-optimized patterns (e.g., the "Ephemeral Two-Step Observer") to detect the state of the web UI without draining battery.

### JavaScript Bridge API Contract

**IMPORTANT**: The communication pattern is **Asynchronous RPC (Remote Procedure Call)**.

1.  **TypeScript (`automation_engine.ts`)** must expose global, Promise-based functions for Dart to call (e.g., `startAutomation`, `extractFinalResponse`).
2.  **Dart** must register `JavaScriptHandler`s to handle events and requests from TypeScript. The primary handler for status updates is named `'automationBridge'`.

Always refer to the active blueprint for the precise API contract for the current development phase.

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