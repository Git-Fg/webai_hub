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