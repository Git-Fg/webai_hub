# Full Blueprint: AI Hybrid Hub (v2.0)

## 1. Vision & Core Principles

**Philosophy:** "Build the Product" – Transform the MVP-validated prototype into a reliable, scalable, and user-delighting application. Robustness, maintainability, and user experience are the priorities.

This blueprint is built on four core principles:
1.  **"Assist, Don't Hide":** The app remains a transparent assistant.
2.  **Hybrid Architecture:** An elegant fusion of a native UI and WebViews.
3.  **Anti-Fragile Robustness:** Failures (CAPTCHAs, selector changes) are nominal states that trigger graceful degradation.
4.  **"Local-First" Privacy:** All user data is stored and processed exclusively on-device.

## 2. Production Architecture & Tech Stack

This stack is prescriptive and optimized for static type-safety and performance.

| Component      | Chosen Technology                 | Target Version | Role                                                  |
| :------------- | :-------------------------------- | :------------- | :---------------------------------------------------- |
| **Framework**    | Flutter / Dart                    | `Flutter >= 3.19.0`, `Dart >= 3.3.0` | Application foundation.                             |
| **State Management** | `flutter_riverpod` + `riverpod_generator` | `^2.5.1`       | Reactive, type-safe, decoupled state management.      |
| **Modeling**     | `freezed`                         | `^2.5.2`       | Immutability for models and states, Union Types.      |
| **Database**     | **`drift`**                       | `^2.18.0`      | **Type-safe SQLite persistence** for conversations.     |
| **WebView**    | `flutter_inappwebview`            | `^6.0.0`       | Critical component for automation and session handling. |
| **Code Quality** | **`very_good_analysis`**          | `^7.0.0`       | **Strict linting rules** for production quality.        |
| **Web Tooling**  | TypeScript + Vite/esbuild         | `vite ^5.0.0`  | Robustness and maintainability of the JS bridge.      |
| **Build Optimization** | Custom `build.yaml` file      | N/A            | Optimize build times for code generators.             |

### Target File Structure

```
lib/
├── core/                       # Shared services, base models
│   ├── database/               # Drift configuration and DAOs
│   └── services/               # Services (e.g., SessionManager)
├── features/                   # Feature modules
│   ├── hub/                    # Native chat UI and logic
│   ├── webview/                # WebView management and bridge
│   └── automation/             # Workflow logic and Overlay
├── shared/                     # Reusable widgets and constants
└── main.dart                   # Entry point, 5-tab architecture
assets/
└── js/
    └── bridge.js               # Generated JS bundle
ts_src/
└── automation_engine.ts        # Automation engine source code
```

## 3. Key Features & Workflows

### 3.1. Multi-Provider Support

-   **Target Providers:**
    1.  Google AI Studio
    2.  Qwen
    3.  Z-ai
    4.  Kimi
-   **Navigation:** An `IndexedStack` manages 5 persistent views: 1 native Hub + 4 dedicated `WebView`s.

### 3.2. "Assist & Validate" Workflow (Full)

The workflow is implemented with its 4 complete phases, driven by the Companion Overlay.

1.  **Phase 1 (Sending):** Dart calls `startAutomation(prompt, providerConfig)` on the TS bridge.
2.  **Phase 2 (Observing):** The TS engine uses the "Two-Step Ephemeral Observer" strategy to detect the end of generation and notifies Dart.
3.  **Phase 3 (Refining):** The native overlay displays "Ready for validation." The user has full control of the `WebView`.
4.  **Phase 4 (Validation):** User clicks "Validate." Dart calls `extractFinalResponse()`. The response is extracted and persisted in the Drift database.

## 4. Detailed Technical Specifications

### 4.1. Configuration-Driven DOM Automation Engine

-   **Remote Configuration:** CSS selectors are **NOT** hardcoded. They are defined in a **remote JSON file**, versioned per provider.
    -   **JSON Structure:** Each selector definition includes a `primary` selector and an ordered array of `fallbacks`.
    -   **Management:** The Dart layer is responsible for fetching (with `ETag`), caching locally, and injecting this configuration into the `WebView` on startup.

-   **"Defense in Depth" Fallback Strategy:** The TS engine sequentially iterates through selectors (`primary`, then `fallbacks`) until an "actionable" (visible, not-disabled) element is found.

-   **Optimized `MutationObserver`:** The "Ephemeral Two-Step Observer" strategy is implemented to preserve performance and battery on mobile.

-   **Shadow DOM Handling:** The engine includes a recursive search function for `open` mode and a "monkey-patching" strategy to attempt to force `open` mode on `closed` roots.

### 4.2. JavaScript Bridge (RPC API)

-   **Pattern:** The bridge is an asynchronous **RPC (Remote Procedure Call)** API based on `Promise`s and the `JavaScriptHandler`s of `flutter_inappwebview`.
-   **API Contract:** The TypeScript API (`automation_engine.ts`) exposes typed functions (e.g., `startAutomation`). The Dart API (`javascript_bridge.dart`) registers corresponding handlers.
-   **State Communication:** For status updates and errors, the TS engine uses a **unidirectional event stream** to a single Dart handler (`automationBridge`), sending structured `AutomationEvent` objects.

### 4.3. Error Handling & Graceful Degradation

-   **Heuristic Failure Triage (TypeScript-side):** On failure, the engine analyzes the page to identify the cause and sends a specific error code:
    -   `ERROR_CAPTCHA_DETECTED`
    -   `ERROR_LOGIN_REQUIRED`
    -   `ERROR_SELECTOR_EXHAUSTED` (outdated config)
-   **Orchestrated Response (Dart-side):** The Dart layer receives these codes and adapts the UI to guide the user:
    -   **CAPTCHA:** Displays an overlay requesting manual intervention.
    -   **Login:** Displays a message indicating reconnection is needed.
    -   **Selector:** Informs the user of temporary unavailability and logs the error for maintenance.

## 5. Data & Persistence

### 5.1. Native Conversation Persistence

-   **Technology:** **Drift** is used to create a local SQLite database.
-   **Schema:** The database stores `Conversations` and `Messages`.
-   **Interaction:** A Riverpod `ConversationProvider` interacts with Drift-generated DAOs to read and write to the database, using reactive queries (`.watch()`) to update the UI automatically.

### 5.2. Web Session Persistence

-   **Technology:** The native singletons **`CookieManager`** and **`WebStorageManager`** from `flutter_inappwebview`.
-   **Implementation:** A Dart `SessionManager` service is responsible for managing cookies to maintain login sessions, including platform-specific workarounds for Android and iOS to ensure reliability across app restarts.

## 6. Evolution from MVP to Full Version

| Feature             | MVP (v1.0)                      | Full Version (v2.0)                                    |
| :------------------ | :------------------------------ | :----------------------------------------------------- |
| **Scope**           | 1 Provider (Google AI Studio)   | 4+ Providers                                           |
| **Database**        | **None** (in-memory state)      | ✅ **Drift** for history                               |
| **CSS Selectors**   | **Hardcoded** in TypeScript     | ✅ **Remote JSON Configuration**                       |
| **Fallback Strategy** | No (single selector)            | ✅ **Yes (array of fallbacks)**                        |
| **Error Handling**  | Generic (`AUTOMATION_FAILED`)   | ✅ **Specific Heuristic Triage**                       |
| **`MutationObserver`**| Simple implementation           | ✅ **Optimized (two-step)**                            |
| **Advanced Cases**  | Ignored (e.g., Shadow DOM)      | ✅ **Handled**                                         |
| **Code Quality**    | `flutter_lints` (standard)      | ✅ **`very_good_analysis` (strict)**                   |