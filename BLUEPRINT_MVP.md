# MVP Blueprint: AI Hybrid Hub (v1.0)

**Version:** MVP-1.0
**Philosophy:** "Prove the Automation Loop" – Validate the core "Assist & Validate" workflow as quickly and simply as possible. Speed takes priority over perfection.

## 1. MVP Vision & Scope

### 1.1. Sole Objective

To implement and validate the complete 4-phase "Assist & Validate" workflow for a **single AI provider**.

-   **Target Provider:** **Google AI Studio**. Chosen for its seemingly stable selectors, making it ideal for a hardcoded MVP.
-   **Core Functionality:** The user must be able to send a prompt from the native UI, watch the automation unfold in the `WebView`, manually refine the response, and validate it to bring it back into the native UI.

### 1.2. What's In Scope (Strictly)

-   **Functional 2-Tab Architecture:** A native "Hub" tab and a `WebView` tab for the target provider.
-   **Minimal Hub UI:** A text input field, a send button, and a list of chat bubbles to display the current conversation.
-   **Functional JavaScript Bridge:** Bi-directional communication (Dart <-> TypeScript) to drive the automation.
-   **Simplified Automation:** Prompt injection, send button click, and final response extraction.
-   **Basic Companion Overlay:** A simple banner displaying the automation state ("Sending...", "Observing...", "Ready for validation") and "Validate" / "Cancel" buttons.

### 1.3. What's Explicitly Out of Scope

-   **Data Persistence:** The conversation is managed **in-memory only**. It is lost when the app restarts.
-   **Multi-Provider Support:** The automation logic is hardcoded for a single provider.
-   **Remote Configuration:** All CSS selectors are **hardcoded** in the TypeScript file.
-   **Advanced Robustness:** No fallback strategy for selectors, no Shadow DOM handling.
-   **Sophisticated Error Handling:** The system only handles one failure type: `AUTOMATION_FAILED`, without diagnosing the cause.

## 2. Simplified Tech Stack

| Component         | Chosen Technology              | Justification for MVP                                             |
| :---------------- | :----------------------------- | :---------------------------------------------------------------- |
| **State Management**  | **Riverpod + Freezed**         | Retained. They simplify in-memory state management and prevent bugs. |
| **Database**        | **NONE**                       | **Major simplification.** Persistence is not required to prove the loop. |
| **Code Quality**    | **`flutter_lints` (default)**  | Sufficient for prototyping. `very_good_analysis` is deferred.     |
| **WebView Library** | **`flutter_inappwebview`**     | **Non-negotiable.** Its JS bridge capabilities are essential.    |
| **Web Tooling**     | **TypeScript + Vite/esbuild**  | Retained. The type-safety on the JS bridge justifies the setup cost. |

## 3. Minimal Hybrid Architecture

### 3.1. App Structure

-   A `TabBarView` with two primary tabs:
    1.  **Hub (Native):** A `Scaffold` with a `ListView` (for bubbles) and a `Row` (for the input field).
    2.  **Provider (WebView):** An `InAppWebView` that loads the target provider's URL.

### 3.2. Session Persistence (Simplified)

-   **Approach:** Rely on the default behavior of `flutter_inappwebview`.
-   **User Workflow:**
    1.  The user manually navigates to the `WebView` tab on first use.
    2.  They sign in to their account on the provider's website.
    3.  `flutter_inappwebview`'s `CookieManager` will persist the session for subsequent app launches. No manual cookie management is implemented.

### 3.3. Communication Bridge

-   The TypeScript bridge is developed and bundled into a **single JavaScript file**.
-   This bundle is injected into the `WebView` via a **`UserScript`** at **`AT_DOCUMENT_START`**.
-   Communication follows a simple **RPC (Remote Procedure Call)** pattern, based on `Promise`s and `JavaScriptHandler`s.

## 4. "Hardcoded" DOM Automation Engine

This is where the main MVP simplifications are made. The focus is on function, not maintainability.

### 4.1. CSS Selectors

-   **Implementation:** Selectors are **`string` constants** declared directly at the top of the TypeScript automation engine file.
    ```typescript
    // File: ts_src/automation_engine.ts
    const PROMPT_INPUT_SELECTOR = "input-area";
    const SEND_BUTTON_SELECTOR = 'send-button[variant="primary"]';
    // ...etc
    ```
-   **Fallback Strategy:** **NONE.** A single selector is used. If it breaks, the MVP is considered broken, which is acceptable for this phase.

### 4.2. Interaction Logic

-   Interaction functions (`clickElement`, `typeText`) use `async/await` and a simple `waitForElement` primitive.
-   `waitForElement` implements a `setInterval` loop that checks for the element's presence until a timeout is reached. No complex "actionability" checks.

### 4.3. State Detection with `MutationObserver` (Simplified)

-   **Strategy:** A single `MutationObserver` is attached to a known, broad chat container.
-   **End-of-Generation Detection:** A simple **"debounce"** technique is used. The end is declared after a period of calm (e.g., 500ms) with no new DOM mutations. Performance and battery impact are not concerns for the MVP.

### 4.4. Error Handling (Minimal)

-   **Implementation:** The automation workflow is wrapped in a single `try/catch` block.
-   **Communication:**
    -   On success, the engine returns the extracted text to Dart.
    -   On failure (any exception in the `catch` block), the engine sends a single, generic error code (e.g., `AUTOMATION_FAILED`) to Dart.
-   **UI Response:** The Dart layer, upon receiving `AUTOMATION_FAILED`, simply displays an error message in the conversation and dismisses the companion overlay.

## 5. MVP "Assist & Validate" Workflow

1.  **Phase 1 (Sending):** User sends a prompt. Dart calls `startAutomation(prompt)` on the TS bridge. The script finds the input, types the prompt, finds the send button, and clicks it.
2.  **Phase 2 (Observing):** The simplified `MutationObserver` activates and waits for generation to complete via debouncing, then notifies Dart.
3.  **Phase 3 (Refining):** The app displays "Ready for validation" in the overlay. The user is free to interact with the `WebView`.
4.  **Phase 4 (Validation):** User clicks the native "Validate" button. Dart calls `extractFinalResponse()`. The script finds the last response element, extracts its text, and returns it to Dart. Dart updates the conversation UI.

## 6. MVP Validation Checklist

The MVP is considered a **success** if and only if all the following conditions are met:
-   [ ] The user can send a prompt from the Hub.
-   [ ] The app automatically switches to the `WebView` tab.
-   [ ] The prompt is correctly injected and sent in the `WebView`.
-   [ ] The app detects the end of response generation.
-   [ ] The user can click "Validate" to extract the response.
-   [ ] The extracted response appears correctly in the Hub.
-   [ ] The entire workflow can be repeated multiple times without restarting the app.