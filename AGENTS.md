# AI Hybrid Hub - Agent Manifesto

Your primary mission is to assist in the development of the AI Hybrid Hub. This document is the single source of truth for all development principles and workflows.

**Core Philosophy:** Prioritize simplicity, robustness, and maintainability. The code is the ultimate authority; your contributions must be clear and self-documenting. All features must be engineered for performance, ensuring full compatibility with low-end devices.

---

## 1. Core Protocols & Workflows

This project operates on two primary workflows, governed by strict, non-negotiable protocols.

### **Workflow A: Code Development & Modification**

This workflow applies when you are writing or changing feature code.

1. **Understand:** Analyze existing code and the `@blueprint` to align with the current architecture.
2. **Implement:** Write clean, self-documenting code, adhering to the technical best practices outlined in this document.
3. **Verify (The Quality Gate):** Before committing, you are responsible for ensuring your changes pass the project's entire suite of quality checks. This is done by running a single, unified command:

    ```bash
    pnpm run test:ci
    ```

    This command validates all Dart and TypeScript code, runs tests, and performs code generation. You MUST resolve all errors it reports.
4. **Commit (The Atomicity Protocol):** After verification succeeds, you MUST commit your changes to the local repository. Each commit must be a single, logical unit of work and follow the Conventional Commits format (`type(scope): summary`).

    **Absolute Constraint:** You must **NEVER** use `git push`. Your role is to build a clean local commit history. A human user is solely responsible for interacting with the remote repository.

### **Workflow B: Autonomous Protocol Execution**

This workflow applies when performing a fully automated, end-to-end task, such as feature validation or regression testing.

1. **Initiate:** Invoke the appropriate autonomous protocol by name (e.g., `@protocols/autonomous-validator`).
2. **Execute:** The protocol is the single source of truth for the entire task. It will guide you through its own specific lifecycle of setup, execution, diagnosis, self-correction, and reporting.
3. **Environment Management:** All autonomous protocols use the `bash reports/run_session.sh` script to manage a clean and isolated test environment. The script's successful completion signals that the application is launched and ready for interaction.

---

## 2. Technical Best Practices (The Unchanging Rules)

These are the fundamental principles of quality code in this project.

### 2.1. Code Quality & Logging

* **Comments Explain "Why":** Comments must explain intent (`// WHY:`), not mechanics.
* **Zero Debugging Artifacts:** Before any commit, you MUST remove all `print()`, `console.log()`, and commented-out code.
* **Structured Logging:** All `console.log` and `console.error` calls within the TypeScript automation engine MUST follow the structured logging protocol (e.g., `[Scope] Message`, Intent-Action-Result pattern, data-rich payloads).

### 2.2. State Management (Riverpod 3.0+)

* **Use Modern Notifiers:** ALWAYS use code-generated `@riverpod` notifiers. NEVER use legacy `StateNotifier` or `ChangeNotifier`.
* **Check `ref.mounted` After `await`:** ALWAYS add `if (!ref.mounted) return;` after any `await` call in a provider method to prevent "use after dispose" errors.
* **Separation of Concerns:** Providers MUST delegate all business logic to service classes. Providers orchestrate state and coordinate services; they NEVER contain business logic, database queries, or data transformations.

### 2.5. Architecture: Three-Layer Separation

The application enforces a strict three-layer architecture. When making any changes, you MUST respect these boundaries:

* **UI Layer (Widgets):**
  * ✅ Capture user interactions
  * ✅ Display data from providers
  * ✅ Trigger provider actions
  * ❌ NEVER access database directly
  * ❌ NEVER contain business logic
  * ❌ NEVER call services directly (must go through providers)

* **Provider Layer (State Management):**
  * ✅ Call service methods for business operations
  * ✅ Manage reactive state (streams, notifiers)
  * ✅ Coordinate multiple services
  * ❌ NEVER contain business logic
  * ❌ NEVER query database directly (except stream providers watching data)
  * ❌ NEVER perform data transformations

* **Service Layer (Business Logic):**
  * ✅ Perform database operations
  * ✅ Transform and validate data
  * ✅ Implement business rules
  * ✅ Handle complex workflows
  * ❌ NEVER manage UI state directly
  * ❌ NEVER trigger UI actions directly (use signal providers)

**Critical Rule:** When debugging, testing, or fixing issues, **always interact with the service/provider layer**, never patch business logic at the widget level. All fixes must be implemented in the appropriate service or provider.

### 2.6. TypeScript Bridge: Self-Contained Provider Files

**Design Principle:** Every provider (`.ts`) in `packages/bridge/chatbots/` MUST be fully self-contained.

* **Self-Contained Requirements:**
  * ✅ All selectors for the provider must be defined in the provider file
  * ✅ All interaction logic (input simulation, button clicks, DOM traversal) must be in the provider file
  * ✅ All extraction logic (response parsing, text cleaning) must be in the provider file
  * ✅ All fallback strategies and error recovery must be in the provider file
  * ✅ All provider-specific timing constants and configuration must be in the provider file

* **What CAN be Shared:**
  * ✅ Cross-provider utilities (`waitForElement`, `waitForActionableElement`, `notifyDart`)
  * ✅ Type definitions (`Chatbot` interface, `AutomationOptions`)
  * ✅ Bridge constants (`EVENT_TYPE_*`)

* **What MUST NOT be Shared:**
  * ❌ Provider-specific selectors
  * ❌ Provider-specific DOM traversal logic
  * ❌ Provider-specific extraction strategies
  * ❌ Provider-specific timing constants

**Critical Rule:** When debugging, validating, or updating a provider, always operate within its dedicated `.ts` file in `packages/bridge/chatbots/`. Selector changes, extraction logic, or interaction bugs for a provider are fixed and tested ONLY in its self-contained TS file. Do not extract provider-specific logic into shared helpers unless explicitly cross-provider.

### 2.3. Hybrid Development & Performance

* **Task Delegation Mandate:** The Dart layer's role is to **delegate**, not micro-manage. All sequential automation logic within the WebView MUST be orchestrated by the TypeScript engine with a single `startAutomation` bridge call. "Chatty" bridges with multiple sequential calls are an anti-pattern.
* **Mandatory Timeout Modifier:** All timeouts in TypeScript MUST be scalable via a `timeoutModifier` parameter passed from Dart to ensure resilience on slower devices.

### 2.4. TypeScript Modification Protocol

When modifying any file in `packages/bridge/**`, you MUST follow this strict process:

1. **Analyze & Modify Types First:** Read and update the type definitions under `packages/bridge/types/**` before changing any logic.
2. **Implement Logic Changes.**
3. **Verify and Build:** After making changes, run the mandatory validation command from the repository root:

    ```bash
    pnpm run validate:ts
    ```

    This delegates to the bridge workspace (`@ai-hub/bridge`) and lints, type-checks, and builds the output bundle at `assets/js/bridge.js`.

---

## 3. Key Commands Reference

* **`pnpm install`**: Installs all TypeScript dependencies across all packages. Run this from the root directory.
* **`pnpm run validate:ts`**: The mandatory command after **any** TypeScript change in the `packages/bridge` directory.
* **`flutter pub run build_runner build --delete-conflicting-outputs`**: The mandatory command after changing Dart files with `@riverpod` or `@freezed` annotations.
* **`pnpm run test:ci`**: The final **Quality Gate** command to run before committing. It validates everything.

## 4. Monorepo Project Structure

This project uses a hybrid monorepo structure. The Flutter application remains at the root, while all TypeScript code is organized into packages within the `packages/` directory, managed by **pnpm workspaces**.

* **`packages/`**: Contains all TypeScript code.

  * `packages/bridge`: The core TypeScript automation engine source code (formerly `ts_src`).

* **`pubspec.yaml` (root)**: Defines the primary Flutter application.

* **`pnpm-workspace.yaml` (root)**: Defines the pnpm workspaces.

**Workflow Constraint:** All new TypeScript code or tooling MUST be added as a new package within the `packages/` directory.

## 5. Documentation & Maintenance Protocols

### 5.1. Changelog Protocol

You MUST maintain `CHANGELOG.md` at the project root.

* **When to Create Entries:**
  * Only create a new entry for a **massive achievement** (architecture overhaul, new core system, large refactor, protocol overhaul).
  * Any smaller change is either added as a bullet/clarification to the latest entry, or omitted entirely.
  * **CRITICAL:** Before creating a new entry, check if an entry already exists for today's date. If it does, update/clarify that existing entry instead of creating a new one. Never create multiple entries for the same day.

* **Entry Format:**
  * Always add new entries at the **top** of the file, so the most recent achievement is listed first.
  * **Date Requirement:** You MUST use the `date +%Y-%m-%d` command to get the current date in YYYY-MM-DD format. Never hardcode dates.
  * Format: `# [YYYY-MM-DD] - Major Achievement Title`
  * Follow with a single summary line (1-2 lines max).

* **History Preservation:**
  * Never remove history—entries are only clarified, not deleted.
  * Previous entries are never removed; only clarified for accuracy.

### 5.2. Update Flow

After finalizing a huge task:

1. Run `date +%Y-%m-%d` to get the current date.
2. Check if an entry already exists for that date in `CHANGELOG.md`.
3. If an entry exists for today, update/clarify that entry. If not, create a new entry.
4. Draft the entry in the required concise format (date from command, title, single summary) and prepend it to the changelog (or update the existing entry for that date).

Collaborators and automated agents are responsible for reviewing and ensuring the `CHANGELOG.md` reflects the current state after every major update.

### 5.3. Conciseness Enforcement

All changelog entries MUST be concise (1-2 lines max). Do not include excessive context, rationale, or issue references—focus on what changed and why.

Remove filler, background, or exhaustive lists from each entry. Focus only on the "what" and "why" in as few words as possible.

### 5.4. Review Requirement

Every workflow for finalization or QA includes verification that `CHANGELOG.md` is up to date and accurate. Before committing major changes, ensure the changelog reflects the achievement.
