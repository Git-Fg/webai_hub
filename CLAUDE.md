# CLAUDE.md

This file provides guidance to the AI Agent when working with code in this repository.

## 🎯 Project Philosophy

**IMPORTANT**: This is a **personal project** focused on **simplicity**, **modernity**, and **elegance**. For the MVP, the primary goal is **speed of implementation** to validate the core concept. Avoid over-engineering and stick strictly to the blueprint.

- **🎯 Simplicity First**: Choose the simplest solution that works.
- **🚀 Modern Code**: Use current best practices (Flutter 3.19+, Riverpod Generators).
- **🧱 Follow the Blueprint**: Adhere strictly to the `BLUEPRINT_MVP.md` and the step-by-step guide.

## Project Overview: MVP Implementation

This project is the **MVP build** of the **AI Hybrid Hub**. The **sole objective** is to implement the "Assister & Valider" workflow for a **single provider: Google AI Studio**.

**Current Status**: The project structure is set up. The next steps involve implementing the application logic according to the provided step-by-step guide.

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

## Architecture Overview (MVP Constraints)

### Core Concept
Bridge a native Flutter UI with the Google AI Studio web interface using a JavaScript bridge to automate the prompt submission and response extraction workflow.

### Technology Stack (MVP Versions)
- **Framework**: Flutter >= 3.19.0
- **State Management**: `flutter_riverpod: ^2.5.1` with `riverpod_generator`. State is **in-memory only**.
- **WebView**: `flutter_inappwebview: ^6.0.0`.
- **JS Bridge**: TypeScript (`ts_src/automation_engine.ts`) built with Vite into a single bundle (`assets/js/bridge.js`).
- **Database**: **NONE**. Do not implement any database persistence for the MVP.

### Automation Engine (Hardcoded for MVP)

-   **Provider Target**: **Google AI Studio ONLY**. URL: `https://aistudio.google.com/prompts/new_chat`
-   **Selector Strategy**: **HARDCODED** in `ts_src/automation_engine.ts`. Do not implement a remote JSON configuration. Use these exact selectors:
    ```typescript
    const PROMPT_INPUT_SELECTOR = "input-area";
    const SEND_BUTTON_SELECTOR = 'send-button[variant="primary"]';
    const RESPONSE_CONTAINER_SELECTOR = "response-container";
    const GENERATION_INDICATOR_SELECTOR = 'mat-icon[data-mat-icon-name="stop"]';
    ```
-   **Error Handling**: **SIMPLIFIED**. The TypeScript engine only needs to notify Dart of two states: `GENERATION_COMPLETE` or `AUTOMATION_FAILED`. No complex error diagnosis is required.

### JavaScript Bridge API (MVP Contract)

**IMPORTANT**: Adhere to this exact API.

1.  **TypeScript (`automation_engine.ts`) must expose two global functions:**
    -   `startAutomation(prompt: string): Promise<void>`
    -   `extractFinalResponse(): Promise<string>`

2.  **Dart (`ai_webview_screen.dart`) must register one JavaScript handler:**
    -   `handlerName: 'automationBridge'`
    -   This handler receives events from TypeScript, specifically `{ type: 'GENERATION_COMPLETE' }` or `{ type: 'AUTOMATION_FAILED', payload: string }`.

## Development Workflow

1.  Modify Dart code in the `lib/` directory.
2.  If you change models or providers, run the Dart code generator.
3.  Modify TypeScript code in `ts_src/automation_engine.ts`.
4.  **After any change to TypeScript, you MUST run `npm run build`**.
5.  Run the application with `flutter run`.

Stick to the provided step-by-step guide to implement the remaining logic. Do not add features or complexity beyond the scope of the MVP blueprint.