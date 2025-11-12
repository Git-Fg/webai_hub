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
    npm run test:ci
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

### 2.3. Hybrid Development & Performance

* **Task Delegation Mandate:** The Dart layer's role is to **delegate**, not micro-manage. All sequential automation logic within the WebView MUST be orchestrated by the TypeScript engine with a single `startAutomation` bridge call. "Chatty" bridges with multiple sequential calls are an anti-pattern.
* **Mandatory Timeout Modifier:** All timeouts in TypeScript MUST be scalable via a `timeoutModifier` parameter passed from Dart to ensure resilience on slower devices.

### 2.4. TypeScript Modification Protocol

When modifying any file in `ts_src/**`, you MUST follow this strict process:

1. **Analyze & Modify Types First:** Read and update the type definitions in `ts_src/types/**` before changing any logic.
2. **Implement Logic Changes.**
3. **Verify and Build:** After making changes, run the mandatory validation command:

    ```bash
    npm run validate:ts
    ```

    This command lints, type-checks, and builds the `assets/js/bridge.js` bundle.

---

## 3. Key Commands Reference

* **`npm run validate:ts`**: The mandatory command after **any** TypeScript change.
* **`flutter pub run build_runner build --delete-conflicting-outputs`**: The mandatory command after changing Dart files with `@riverpod` or `@freezed` annotations.
* **`npm run test:ci`**: The final **Quality Gate** command to run before committing. It validates everything.
