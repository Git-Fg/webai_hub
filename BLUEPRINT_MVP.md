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

-   A `Stack` with `IndexedStack` and `Offstage` widgets managing two primary views:
    1.  **Hub (Native):** A `Scaffold` with a `ListView` (for bubbles) and a `Row` (for the input field).
    2.  **Provider (WebView):** An `InAppWebView` that loads the target provider's URL.
    
This approach was chosen over `TabBarView` to ensure the `WebView` state is preserved and can initialize in the background, which is critical for the automation workflow.

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
-   **Fallback Strategy:** **Yes (limited).** The TypeScript engine uses an **array of CSS selectors** for each target element (input, button), trying them sequentially. This provides basic resilience to minor DOM changes. If all selectors fail, the MVP considers the provider broken.

### 4.2. Interaction Logic

-   Interaction functions (`clickElement`, `typeText`) use `async/await` and a simple `waitForElement` primitive.
-   `waitForElement` implements a `setInterval` loop that checks for the element's presence until a timeout is reached. No complex "actionability" checks.

### 4.3. State Detection with `MutationObserver` (Simplified)

-   **Strategy:** A single `MutationObserver` is attached to a known, broad chat container.
-   **End-of-Generation Detection:** A simple **"debounce"** technique is used. The end is declared after a period of calm (e.g., 500ms) with no new DOM mutations. Performance and battery impact are not concerns for the MVP.

### 4.4. Error Handling (Improved)

-   **Implementation:** The automation workflow is wrapped in a single `try/catch` block.
-   **Communication:**
    -   On success, the engine returns the extracted text to Dart.
    -   On failure (any exception in the `catch` block), the engine sends a **structured error object** to Dart containing a `payload` (message), an `errorCode`, and a `location`. This structured approach greatly facilitates debugging.
-   **UI Response:** The Dart layer receives the structured error and displays an error message in the conversation, then dismisses the companion overlay.

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

## 7. Leçons Apprises et Décisions Architecturales Clés

This section documents key architectural decisions made during MVP development that shaped the final implementation.

### 7.1. Gestion des Onglets : L'Approche "Riverpod Pure"

#### Problème Identifié

Initially, we attempted to use Flutter's native `TabController` with a `Provider` override. This created synchronization issues because `ProviderScope` overrides only apply to descendant widgets, not global `NotifierProvider`s. As a result, `tabControllerProvider` always returned `null` in `ConversationProvider`, causing tab switching failures.

#### Solution : Architecture Riverpod Pure

**Principle:** Use **only** `currentTabIndexProvider` Riverpod to manage tab changes. The Flutter `TabController` is used **only for UI display**.

**Architecture:**

1. **Global Riverpod Provider** (`lib/main.dart`):
```dart
@riverpod
class CurrentTabIndex extends _$CurrentTabIndex {
  @override
  int build() => 0;

  void changeTo(int index) {
    if (state != index) {
      state = index;
    }
  }
}
```

2. **UI Layer** (`lib/main.dart` - `_MainScreenState`):
   - `TabController` is used **only for display** of the `TabBar`
   - Bidirectional synchronization:
     - `TabController` → `currentTabIndexProvider` (via `_onTabChanged` listener)
     - `currentTabIndexProvider` → `TabController` (via `ref.listen` in `build`)

3. **Business Logic** (`lib/features/hub/providers/conversation_provider.dart`):
   - **NEVER** access the `TabController` directly
   - **ALWAYS** use `ref.read(currentTabIndexProvider.notifier).changeTo(index)`

**Best Practices:**

1. **Single Source of Truth:** `currentTabIndexProvider` is the sole source of truth for the active tab index
2. **Separation of Concerns:**
   - **Riverpod Provider** (`currentTabIndexProvider`): Business logic, accessible everywhere
   - **Flutter TabController**: UI only, local to the `MainScreen` widget
3. **Access from Providers:** Always use `ref.read(currentTabIndexProvider.notifier).changeTo(index)`, accessible from any `NotifierProvider` without widget tree dependencies

**Problems Solved:**
- ✅ TabBar/IndexedStack synchronization: The TabBar updates visually when business logic changes tabs
- ✅ Global accessibility: `currentTabIndexProvider` is accessible from all Riverpod providers
- ✅ No race conditions: The provider manages state deterministically

### 7.2. Fiabilisation du Timing : Mécanisme `waitForBridgeReady`

#### Problème des Délais Arbitraires

Early MVP iterations relied on arbitrary `Future.delayed(Duration(seconds: 2))` calls to wait for the WebView to initialize. This approach proved unreliable because:
- The actual initialization time varies based on device performance and network conditions
- Fixed delays created race conditions
- Tests became flaky and non-deterministic

#### Solution : Signal Explicite via Bridge Ready

**Approach:** The WebView JavaScript bridge signals when it's fully initialized by calling `bridgeReadyProvider.notifier.markReady()` after successful script injection. The Dart side waits for this signal instead of using arbitrary delays.

**Implementation:**

1. **JavaScript Side** (`lib/features/webview/widgets/ai_webview_screen.dart`):
```dart
onLoadStop: (controller, url) async {
  // Script successfully injected
  ref.read(bridgeReadyProvider.notifier).markReady();
}
```

2. **Dart Side** (`lib/features/webview/bridge/javascript_bridge.dart`):
```dart
Future<void> waitForBridgeReady() async {
  // Wait for WebView controller
  await _waitForWebViewToBeCreated();
  
  // Additional short delay for initialization
  await Future.delayed(const Duration(milliseconds: 300));
  
  // Poll for explicit ready signal
  while (!ref.read(bridgeReadyProvider)) {
    await Future.delayed(const Duration(milliseconds: 100));
  }
}
```

**Benefits:**
- ✅ Reliable: Waits for actual initialization event
- ✅ Testable: Deterministic behavior in tests
- ✅ Adaptive: Responds to actual device conditions, not arbitrary timeouts
- ✅ Debuggable: Clear signal of initialization success/failure

### 7.3. Stratégie Anti-Délais Arbitraires

#### Pourquoi les Délais Sont des Anti-Patterns

Adding `Future.delayed` or `setTimeout` as a first response to timing issues masks the underlying problem and creates technical debt:
- They don't address the root cause
- They make tests flaky
- They degrade user experience (unnecessary waits)
- They are maintenance burdens (arbitrary magic numbers)

#### Approche Correcte

**When encountering timing issues, investigate:**

1. **Race Conditions in Widget Lifecycle:**
   - Is the widget being built before data is available?
   - Is state being accessed before initialization?
   - Use `ref.listen` or `ValueListenable` for reactive updates

2. **Provider State Synchronization:**
   - Are multiple providers accessing the same resource?
   - Is state being modified from multiple locations?
   - Use a single source of truth pattern

3. **Event Order:**
   - Are events arriving in the wrong sequence?
   - Implement explicit sequencing or state machines

4. **CSS Selectors or Element Availability:**
   - Are selectors targeting elements that don't exist yet?
   - Use `MutationObserver` or polling with proper checks

**When a delay is acceptable:**

Only as a **last resort** when:
- The external system (e.g., WebView) provides no callback/event for the state you're waiting for
- A short, bounded delay is the only way to ensure readiness
- The delay is explicitly documented with rationale

**Rule:** If a delay fixes a symptom but not the root cause, **remove the delay immediately**. Investigate further and fix the underlying issue.

### 7.4. Stratégie d'État Riverpod : autoDispose vs. keepAlive

#### Problème Résolu lors du Test d'Intégration

During development of the integration test `bridge_communication_test.dart`, a critical issue was identified: `BridgeReady` and `WebViewController` providers were auto-dispose by default, creating **separate instances** between the widget tree and external test container, preventing state synchronization.

**Solution:** Use `@Riverpod(keepAlive: true)` for providers shared between multiple contexts (widget tree + test container).

#### Règle Générale : Quand utiliser quoi ?

**Use `autoDispose` (default `@riverpod`) for:**

✅ **Screen/widget-specific state:**
- `TextEditingController` for a form
- Carousel current index
- Local dialog or bottom sheet state
- Temporary cache for a specific screen

✅ **FutureProvider/StreamProvider for screen data:**
- Loading data that should refresh when the user leaves and returns to the screen
- Example: `@riverpod Future<List<Item>> itemsForScreen(Ref ref) async { ... }`

**Advantage:** Automatic memory release when the screen is no longer used.

**Use `keepAlive: true` (`@Riverpod(keepAlive: true)`) for:**

✅ **Services and repositories:**
- API clients, authentication services
- Data repositories
- **Example in project:** `javaScriptBridgeProvider` (keepAlive by default as simple provider)

✅ **Shared state between multiple screens:**
- User authentication state
- App theme
- **Example in project:** `bridgeReadyProvider` - shared between WebView widget, test container, and business providers

✅ **Handles to unique resources:**
- WebView controller (unique instance to share)
- **Example in project:** `webViewControllerProvider` - unique reference to `InAppWebViewController`

✅ **Global navigation state:**
- Active tab index (`currentTabIndexProvider`)
- Global automation state (`automationStateProvider`)

#### Examples in the Project

```dart
// ✅ keepAlive: true - Shared state, unique resource
@Riverpod(keepAlive: true)
class BridgeReady extends _$BridgeReady {
  @override
  bool build() => false;
  // Shared between WebView widget, test container, and business providers
}

@Riverpod(keepAlive: true)
class WebViewController extends _$WebViewController {
  @override
  InAppWebViewController? build() => null;
  // Unique handle to WebView controller
}

// ✅ autoDispose (default) - Screen-local state
@riverpod
class Conversation extends _$Conversation {
  @override
  List<Message> build() => [];
  // Screen-specific conversation state
}
```

#### Symptoms if You Use the Wrong Mode

**If you use `autoDispose` for a shared provider:**
- ❌ Different instances created in different contexts
- ❌ Updates not visible between widget tree and external container (tests)
- ❌ Provider disposes prematurely while still used elsewhere

**If you use `keepAlive` for screen-local state:**
- ❌ Memory leak: state retained even after navigation
- ❌ Stale data reused after navigation
- ❌ Degraded performance (providers not disposed unnecessarily)

#### Decision Checklist

Before creating a provider, ask:

1. **Is this provider used by multiple screens/widgets?**
   - Yes → `keepAlive: true`
   - No → `autoDispose` (default)

2. **Does this provider represent a unique resource (controller, service)?**
   - Yes → `keepAlive: true`
   - No → `autoDispose` (default)

3. **Is this provider accessible from an external container (tests, business providers)?**
   - Yes → `keepAlive: true`
   - No → `autoDispose` (default)

4. **Is this provider screen-specific and should refresh on each visit?**
   - Yes → `autoDispose` (default)
   - No → `keepAlive: true`
