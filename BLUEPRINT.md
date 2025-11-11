# Blueprint: AI Hybrid Hub (v2.0)

## 1. Vision & Core Principles

**Philosophy:** "Build the Product" – Transform the MVP-validated prototype into a reliable, scalable, and user-delighting application. Robustness, maintainability, and user experience are the priorities.

This blueprint is built on four core principles:

1. **"Assist, Don't Hide":** The app remains a transparent assistant.
2. **Hybrid Architecture:** An elegant fusion of a native UI and WebViews.
3. **Anti-Fragile Robustness:** Failures (CAPTCHAs, selector changes) are nominal states that trigger graceful degradation.
4. **"Local-First" Privacy:** All user data is stored and processed exclusively on-device.

In alignment with the project README's long-term roadmap, the Full Blueprint ultimately enables Automated Provider Comparison and Intelligent Response Synthesis. These are direct expressions of the "Assist, Don't Hide" philosophy: the app transparently orchestrates multiple providers, compares their outputs, and helps synthesize a better final answer without hiding how results are produced.

## 2. Production Architecture & Tech Stack

This stack is prescriptive and optimized for static type-safety and performance.

| Component      | Chosen Technology                 | Target Version | Role                                                  |
| :------------- | :-------------------------------- | :------------- | :---------------------------------------------------- |
| **Framework**    | Flutter / Dart                    | `Flutter >= 3.3.0`, `Dart >= 3.3.0` | Application foundation.                             |
| **State Management** | `flutter_riverpod` + `riverpod_generator` | `^3.0.1`       | Reactive, type-safe, decoupled state management.      |
| **Modeling**     | `freezed`                         | `^3.0.0`       | Immutability for models and states, Union Types.      |
| **Database**     | **`drift`**                       | `^2.18.0`      | **Type-safe SQLite persistence** for conversations.     |
| **WebView**    | `flutter_inappwebview`            | `^6.0.0`       | Critical component for automation and session handling. |
| **Code Quality** | **`very_good_analysis`**          | `^10.0.0`      | **Strict linting rules** for production quality.        |
| **Web Tooling**  | TypeScript + Vite/esbuild         | `vite ^7.1.12` | Robustness and maintainability of the JS bridge.      |
| **Build Optimization** | Custom `build.yaml` file      | N/A            | Optimize build times for code generators.             |

### Target File Structure

```text
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

- **Target Providers:**
    1. Google AI Studio
    2. Qwen
    3. Z-ai
    4. Kimi
- **Navigation:** An `IndexedStack` manages 5 persistent views: 1 native Hub + 4 dedicated `WebView`s.

### 3.2. The "Orchestrate, Compare, Synthesize" Meta-Workflow

The core user experience evolves from a single conversation into an orchestration dashboard. The user crafts one prompt in the Hub, which is then broadcast to a user-defined set of "Presets". The responses are aggregated back into the Hub for direct comparison, and potentially, AI-driven synthesis into a single, superior answer.

#### 3.2.1. Presets and Groups: The Core Units of Orchestration

Inspired by proven systems like CodeWebChat, the application's core logic is built around "Presets" and "Groups". This provides a powerful and flexible way for users to manage and compare AI interactions.

**A. Presets**

A Preset is a named, persistent configuration that defines a complete context for an AI interaction. It includes:

- **Provider:** The target web service (e.g., `ai_studio`).
- **Model:** The specific model to use (e.g., `Gemini 2.5 Flash`).
- **Parameters:** A full set of settings like `temperature`, `topP`, etc.
- **Affixes:** An optional `prompt_prefix` and `prompt_suffix` to frame the user's input.
- **UI State:** Flags like `is_pinned` for prioritizing in the UI.

**B. Groups**

A Group is structurally a Preset **without a `provider` or `model` defined**. Its purpose is twofold:

1. **UI Organization:** In the user interface, Groups act as collapsible headers, allowing users to organize their Presets thematically (e.g., "Creative Writing", "Code Generation").
2. **Settings Inheritance:** Groups can define their own `prompt_prefix` and `prompt_suffix`. When a Preset under a Group is used, its affixes are intelligently combined with those of its parent Group, allowing for powerful, layered prompt engineering.

#### 3.2.2. The Three Phases of the Workflow

**A. Phase 1: Orchestration (Multi-Dispatch)**

1. **Preset Selection:** In the Hub UI, the user is presented with their list of Presets and Groups. They can select one or multiple Presets via checkboxes.

2. **Prompt Dispatch:** The user writes a single prompt and clicks "Send".

3. **Parallel Automation:** The orchestration logic iterates through each selected Preset. For each one, it:

   a. Finds its parent Group (by looking upwards in the list order).

   b. Constructs the final prompt string by combining the Group's affixes and the Preset's affixes with the user's input (`group_prefix + preset_prefix + user_input + preset_suffix + group_suffix`).

   c. Initiates a dedicated automation cycle for the corresponding WebView, passing the final prompt and all other parameters from the Preset.

**B. Phase 2: Comparison**

1. **Response Aggregation:** As each WebView's automation completes, the extracted response is sent back to the Hub, tagged with the name of the Preset that generated it.

2. **Comparison View:** The Hub UI displays the responses side-by-side (or in a tabbed view on smaller screens) under the original user prompt, allowing for immediate comparison of different models' or settings' outputs.

**C. Phase 3: Synthesis & Curation**

1. **Manual Curation:** The user selects the best response, which is then committed to the permanent conversation history as the definitive assistant message for that turn.

2. **(Roadmap) Intelligent Synthesis:** The user can select multiple responses and ask a primary "synthesis" Preset to analyze, critique, and merge them into a single, superior answer.

### 3.3. Advanced User Controls

To enhance the user's ability to curate the perfect conversation, two advanced features are integrated directly into the Hub UI.

#### 3.3.1. Manual Message Editing

The user is the final authority on the conversation's content. After an AI response has been extracted and finalized (i.e., the automation state is `idle`), the user can tap on any AI-generated message bubble in the Hub to open an editing dialog. This allows for manual corrections, additions, or removals. The edited text permanently replaces the original in the conversation history, ensuring that all future "Contextual Seeding" turns use the user-approved version.

#### 3.3.2. System Prompt Management

Users can define a persistent "system prompt" or master instruction (e.g., "You are an expert Flutter developer. All code examples must be sound and null-safe.") that guides the AI's behavior across an entire conversation. This prompt is applied at the beginning of each new turn, ensuring consistent tone, personality, and constraints.

#### 3.3.3. History Context Instruction Customization

Users can customize the instruction text that introduces the conversation history in XML prompts. This text appears before the `<history>` section and frames how the AI interprets the contextual conversation. The default instruction is: "Here is the previous conversation history for your context. Consider these your own past messages:". This setting can be edited in the Settings screen under "Prompt Engineering", allowing users to tailor the framing to their specific use case or to match their preferred AI's instruction style.

## 4. Detailed Technical Specifications

### 4.1. Configuration-Driven DOM Automation Engine

- **Hardcoded Selectors:** CSS selectors are defined directly in the TypeScript automation engine files, organized per provider in the `ts_src/chatbots/` directory.
  - **Selector Structure:** Each provider implementation uses an array of selectors with a `primary` selector and ordered `fallbacks` for resilience.
  - **Management:** Selectors are maintained in the codebase and updated via app releases when provider UIs change.

- **"Defense in Depth" Fallback Strategy:** The TS engine sequentially iterates through selectors (`primary`, then `fallbacks`) until an "actionable" (visible, not-disabled) element is found. See §4.10.1 for the Selector Priority Pyramid that guides selector choice.

- **Optimized `MutationObserver`:** The "Observe Narrowly, Process Lightly" strategy is implemented to preserve performance and battery on mobile. See §4.10.4 for detailed mobile performance principles.

- **Shadow DOM Handling:** The engine includes a recursive search function for `open` mode and a "monkey-patching" strategy to attempt to force `open` mode on `closed` roots.

- **Modern Waiting Patterns:** The engine uses event-driven APIs (`MutationObserver`, `IntersectionObserver`) instead of polling. See §4.10.2 for the "Sensor Array" pattern and §4.10.3 for comprehensive actionability checks.

This modular architecture supports the README's Multi-Provider Support goal: new providers can be added by implementing the `Chatbot` interface in a new file within `ts_src/chatbots/`, following the established patterns for selector management and fallback strategies.

**For comprehensive documentation on selector strategies, waiting patterns, and debugging methodologies, see §4.10.**

### 4.2. JavaScript Bridge (RPC API)

- **Pattern:** The bridge is an asynchronous **RPC (Remote Procedure Call)** API based on `Promise`s and the `JavaScriptHandler`s of `flutter_inappwebview`.
- **API Contract:** The TypeScript API (`automation_engine.ts`) exposes typed functions (e.g., `startAutomation`). The Dart API (`javascript_bridge.dart`) registers corresponding handlers.
- **State Communication:** For status updates and errors, the TS engine uses a **unidirectional event stream** to a single Dart handler (`automationBridge`), sending structured `AutomationEvent` objects.

#### 4.2.1. Resilient Bridge Architecture (Four-Layer Defense)

The JavaScript bridge implements a multi-layered defense system to handle the ephemeral nature of WebView JavaScript contexts and recover from crashes, context loss, and silent failures.

##### Layer 1: Defensive Injection

- **Multi-Event Strategy:** Bridge script is injected on multiple lifecycle events:
  - `onWebViewCreated`: Registers Dart-side handlers **once** (idempotent registration)
  - `onLoadStop`: Injects script after full-page reloads
  - `onUpdateVisitedHistory`: Validates bridge health during SPA navigations (where `onLoadStop` doesn't fire)
- **JavaScript Idempotency:** The bridge script (`automation_engine.ts`) uses a master guard clause (`if (window.__AI_HYBRID_HUB_INITIALIZED__)`) to ensure it can be safely re-injected multiple times without side effects.

##### Layer 2: Multi-Stage Readiness Protocol

- **Multi-Stage Verification:** The `waitForBridgeReady()` method uses a robust, four-stage protocol instead of simple polling. It sequentially waits for:

  1. **Native Controller:** The Flutter `InAppWebViewController` widget is initialized.

  2. **Page Load:** The web page's `document.readyState` is `'complete'`. This prevents race conditions where the script is checked before the page has finished loading.

  3. **Script Injection:** The `window.__AI_HYBRID_HUB_INITIALIZED__` flag is present, confirming the JavaScript bundle has executed.

  4. **Final Signal:** The JavaScript bridge sends an explicit "ready" signal to Dart, confirming all handlers are active.

- **Integration:** This comprehensive check is performed before any critical operation (`startAutomation`, `extractFinalResponse`), guaranteeing the bridge is in a valid state.

##### Layer 3: Disaster Recovery (Platform-Specific)

- **Android Renderer Process Crashes (`onRenderProcessGone`):**
  - **Fatal:** The WebView instance becomes unusable and must be destroyed
  - **Recovery:** Increment `WebViewKeyProvider` to trigger widget recreation via key change
  - **State Reset:** Bridge readiness state is reset before recreation
- **iOS Content Process Crashes:**
  - **Recoverable:** Detected via lifecycle observer (`didChangeAppLifecycleState`) on app resume
  - **Recovery:** Heartbeat check detects zombie contexts; bridge script is re-injected or page is reloaded
  - **Pattern:** iOS crashes often manifest as "zombie" contexts that hang on `evaluateJavascript` calls

##### Layer 4: State Externalization

- **Principle:** The JavaScript context (`window` object) is volatile and must **never** be the source of truth for persistent state.
- **Implementation:** All critical state (session tokens, automation progress) is owned by the Dart layer and persisted via:
  - `CookieManager` (for session state)
  - `WebStorageManager` (for application state)
- **Rehydration:** The JavaScript bridge can "rehydrate" itself from native storage upon initialization if needed.

**Benefits:**

- **Self-Healing:** The bridge automatically detects and recovers from context loss without user intervention
- **Prevents Hangs:** Heartbeat pattern prevents infinite waits on dead contexts
- **SPA Support:** Handles modern web apps with client-side routing that don't trigger `onLoadStop`
- **Platform-Aware:** Uses platform-specific recovery strategies optimized for each OS

### 4.3. Error Handling & Graceful Degradation

- **Heuristic Failure Triage (TypeScript-side):** On failure, the engine analyzes the page to identify the cause and sends a specific error code:
  - `ERROR_CAPTCHA_DETECTED`
  - `ERROR_LOGIN_REQUIRED`
  - `ERROR_SELECTOR_EXHAUSTED` (outdated config)
- **Orchestrated Response (Dart-side):** The Dart layer receives these codes and adapts the UI to guide the user:
  - **CAPTCHA:** Displays an overlay requesting manual intervention.
  - **Login:** Displays a message indicating reconnection is needed.
  - **Selector:** Informs the user of temporary unavailability and logs the error for maintenance.

### 4.4. Workflow Orchestration: TypeScript-Centric Task Delegation

To achieve maximum performance and responsiveness, the application has evolved from a Dart-driven orchestration model to a **TypeScript-centric task delegation model**. The guiding principle is to minimize the latency of the Dart-JavaScript bridge by reducing communication to a single, comprehensive command.

- **Previous Model (Anti-Pattern):** The Dart layer acted as a "micro-manager," sending a sequence of individual commands to the WebView (`loadUrl`, `waitForReady`, `startAutomation`, `startResponseObserver`), with each step introducing bridge latency.

- **Current Model (High-Performance):**

  1. **Single Point of Entry:** The Dart `ConversationProvider` is now only responsible for gathering all user settings and context into a single `AutomationOptions` object.

  2. **Total Delegation:** It makes a **single call** to a master `startAutomation(options)` function in the JavaScript bridge.

  3. **Autonomous TypeScript Orchestrator:** The `automation_engine.ts` script takes full control of the end-to-end workflow within the WebView:

      - It autonomously resets the UI to a clean state (e.g., by clicking "New Chat").

      - It applies all settings (model, temperature, etc.).

      - It enters the prompt and validates UI readiness (e.g., token count).

      - It submits the prompt.

      - It begins observing for the response.

  4. **Final Notification:** The script only communicates back to Dart upon final success (`NEW_RESPONSE_DETECTED`) or failure (`AUTOMATION_FAILED`, `LOGIN_REQUIRED`), eliminating all intermediate chatter.

This architecture dramatically reduces the perceived latency for the user, as the entire complex automation sequence runs natively within the high-performance JavaScript environment of the WebView, free from the overhead of multiple asynchronous bridge crossings. The Dart layer's role is simplified to that of a delegator, not an orchestrator.

**Implementation Details:**

- **Context Management:** A dedicated `PromptBuilder` service (`lib/features/hub/services/prompt_builder.dart`) is responsible for generating the prompt string. Its `buildPromptWithContext` method composes `<system>`, `<history>`, and `<user_input>` from the current state. The instruction text that introduces the conversation history is customizable via the `historyContextInstruction` setting in `GeneralSettings`, allowing users to fine-tune how context is framed for the AI.

- **WebView Lifecycle Control:** The TypeScript engine is now responsible for resetting the UI. At the beginning of each automation cycle, it calls its internal `resetState()` method, which simulates a click on the "New Chat" button within the web page. This in-page navigation is significantly faster than the previous full-page reload (`loadUrl`) initiated by Dart.

- **State Machine Logic:** The `AutomationState` provider acts as the central state machine.

  - `idle`: The default state. Sending a prompt from here triggers the **Contextual Seeding** workflow.

  - `sending`/`observing`: Transitional states during AI response generation.

  - `refining`: A persistent, looping state. The app remains here throughout the **Iterative Refinement** process. All `extractAndReturnToHub` calls during this state will update the last AI message.

  - The `finalizeAutomation` method (triggered by the "Done" button) is the sole path from `refining` back to `idle`.

### 4.5. Native-Side Conversation Curation

The logic for manual message editing is handled entirely within the Dart/Riverpod layer, requiring no changes to the TypeScript automation engine.

- **State Management:** The `ConversationProvider` will expose a new method, `editMessage(messageId, newText)`. This method finds the target message in the state list and replaces it with a new instance containing the updated text.

- **UI Trigger:** The `ChatBubble` widget's `onTap` behavior will be updated to allow editing of both user and assistant messages, but only when the `AutomationState` is `idle`. This prevents editing a message that is actively being refined by the AI.

### 4.6. Unified System Prompt Injection via XML (with Native UI Exception)

The default mechanism is the `<system>` tag within the XML prompt. This unifies instruction handling across providers.

Advantages:

- **Universal compatibility:** Works for all web providers without dedicated system fields.
- **Simplified defaults:** The bridge continues to accept a single `prompt` string; orchestration complexity remains in Dart.

Exception – Providers with native system prompt fields:

- Some providers expose a first‑class, reliable "system/instructions" field in their UI. For these, the system instructions SHOULD be provided natively and OMITTED from the XML prompt (i.e., no `<system>` section).
- Configuration (conceptual): mark capability at provider level (e.g., `supportsNativeSystemPrompt: true`). If used, the Dart orchestration must ensure the native field is set before sending the user prompt. How this is achieved (selector, native control, or a provider‑specific helper) is an implementation detail and outside this blueprint’s scope.
- Rationale: Avoids duplicating or conflicting instructions (native + in‑prompt) and adheres to provider UX when it exists.

### 4.7. Prompt Structure with Duplicated Instruction for Focus

The XML prompt structure intentionally duplicates the user prompt and system prompt at both the beginning and end of the prompt. This is not an oversight but a deliberate design choice with important implications for AI model performance.

**Structure:**

1. **Initial Instruction:** User prompt + system prompt (if applicable)
2. **Context:** History, files, and other contextual information
3. **Repeated Instruction:** User prompt + system prompt (if applicable)

**Why Duplication is Necessary:**

- **Recency Bias:** Large language models exhibit strong recency bias, giving disproportionate weight to information appearing at the end of prompts
- **Focus Maintenance:** When extensive context (history, files) is included, models may lose focus on the actual user request
- **Mitigation Strategy:** Placing the user's current input at both beginning and end ensures the model maintains focus on the current task while still benefiting from context

**Implementation Details:**

- The duplication occurs in `_buildPromptWithContext` method in `conversation_provider.dart`
- System prompt is only included if `shouldInjectSystemPrompt` is true (based on provider capabilities)
- This pattern is applied consistently across all providers that don't support native system prompts

This pattern is a proven technique for maintaining model focus in complex prompting scenarios and should be preserved when extending the prompt system.

## 5. Data & Persistence

### 4.8. Advanced UI/UX Patterns

To create a fluid and non-obstructive user experience, the application adopts a clear paradigm: **Notifications for Status, Overlay for Interaction**. This separates informational feedback from interactive controls.

#### 4.8.1. Ephemeral Notifications for Status Updates

For purely informational states where no user action is required, the app uses ephemeral, non-occluding notifications. This prevents the UI from interfering with the automation engine and provides clear, temporary feedback.

- **Problem:** A persistent overlay shown during the automation's setup phase (`sending`) can physically block (occlude) web elements that the script needs to click, causing automation to fail.

- **Solution:**
  - A dedicated `AutomationStateObserver` widget listens for changes in the `AutomationState`.
  - For informational states (`sending`, `observing`, `failed`), it programmatically displays an `ElegantNotification`.
  - These notifications inform the user of the current status without blocking interaction with the underlying WebView. They are automatically managed (shown and dismissed) as the state transitions.

##### 4.8.2. Interactive Companion Overlay for User Actions

The draggable `CompanionOverlay` is now reserved exclusively for states that require direct user interaction.

- **Implementation:**
  - The overlay's visibility is strictly tied to interactive states: `refining` and `needsLogin`.
  - **`refining` State:** The overlay appears as a full, draggable panel, allowing the user to position it conveniently while accessing the "Extract & View Hub" and "Done" buttons.
  - **`needsLogin` State:** The overlay appears as a simplified, non-draggable, centered modal dialog, presenting the "I'm logged in, Continue" button for a clear, focused action.
  - This conditional behavior ensures the UI component matches the required user task, reducing confusion and improving usability.

#### 4.8.3. Signal-Based UI Actions (Auto-Scrolling)

To maintain a clean separation between business logic and UI implementation, actions like scrolling are triggered via a signal-based provider rather than direct calls.

- **Problem:** `ConversationProvider` should not hold a dependency on a `ScrollController` from the `HubScreen`.
- **Solution:**
  - A simple `ScrollToBottomRequestProvider` (`@riverpod`) is created. Its state is a simple integer that acts as a trigger.
  - When `ConversationProvider` completes an action that should result in a scroll (e.g., successful extraction), it calls a `requestScroll()` method on the notifier, which simply increments the state.
  - The `HubScreen` uses `ref.listen` to watch for changes to this provider's state. When a change is detected, it calls its local `_scrollToBottom()` method, which has access to the `ScrollController`.
  - This pattern effectively decouples the "intent" (scroll needed) from the "implementation" (how to scroll).

### 4.9. Bridge Robustness & Security Patterns

The Flutter-JavaScript bridge is a critical but fragile component. Based on comprehensive research into `flutter_inappwebview` best practices (late 2025), the application implements defensive patterns to prevent documented failure modes.

#### 4.9.1. Mandatory Timeout Protection for `callAsyncJavaScript`

**Problem:** The `callAsyncJavaScript` API can silently hang indefinitely on Android, causing deadlocks and app crashes. This is a documented issue in the flutter_inappwebview library.

**Solution:** All `callAsyncJavaScript` calls **MUST** be wrapped with `Future.timeout()`:

```dart
final result = await controller.callAsyncJavaScript(
  functionBody: 'return await window.extractFinalResponse();',
).timeout(
  const Duration(seconds: 30),
  onTimeout: () => throw AutomationError(
    errorCode: AutomationErrorCode.bridgeTimeout,
    location: 'extractFinalResponse',
    message: 'Bridge call timed out after 30 seconds',
    diagnostics: _getBridgeDiagnostics(),
  ),
);
```

**Implementation:** See `lib/features/webview/bridge/javascript_bridge.dart` in the `extractFinalResponse()` method.

#### 4.9.2. Event-Driven Bridge Readiness Detection

**Problem:** Polling-based bridge readiness detection is unreliable and can miss the actual ready state, leading to race conditions.

**Solution:** Listen for the official `flutterInAppWebViewPlatformReady` event, which fires when the platform is truly ready:

```typescript
// Listen for the official platform ready event
document.addEventListener('flutterInAppWebViewPlatformReady', () => {
  console.log('[Engine] Received flutterInAppWebViewPlatformReady event');
  signalReady();
});

// Keep fallback polling for robustness
trySignalReady();
```

**Rationale:** Event-driven detection is more reliable than timing-based polling, but the fallback polling mechanism is retained for robustness.

**Implementation:** See `ts_src/automation_engine.ts` for the event listener implementation.

#### 4.9.3. Security Configuration Requirements

**Problem:** The default security posture of the JavaScript bridge is dangerously permissive, allowing any website to access the bridge API.

**Solution:** Bridge security should be configured to whitelist only trusted domains. The exact API varies by flutter_inappwebview version and should be configured when available to restrict bridge access to trusted domains only.

**Reference:** These patterns are based on comprehensive research into flutter_inappwebview communication bridge best practices, citing specific GitHub issues and changelogs documenting failure modes and security vulnerabilities.

#### 4.9.4. User Agent Management for OAuth Compatibility

**Problem:** Google and other OAuth providers are increasingly blocking login requests from unidentified WebViews, returning a "disallowed_useragent" error. The default User Agent provided by `flutter_inappwebview` is often flagged.

**Solution:** The application implements a multi-layered system to manage the WebView's User Agent identity, providing both user control and architectural robustness.

1. **User-Configurable UA:** The `GeneralSettings` model allows the user to select from a list of standard, verified browser User Agents (e.g., 'Chrome on Windows') or provide their own custom string. This is managed via the `UserAgentSelector` widget in the settings screen.

2. **Dynamic UA Application:** In `AiWebviewScreen`, the `_buildWebView` method reads the user's selection from `generalSettingsProvider` and dynamically constructs the `InAppWebViewSettings` with the appropriate `userAgent` string.

3. **Forced WebView Recreation:** A User Agent can only be set when an `InAppWebView` is first created. To apply a changed setting, the existing WebView must be destroyed and a new one created. This is achieved reliably by:

   * A `ref.listen` in `AiWebviewScreen` monitors `generalSettingsProvider` for changes to the User Agent fields.

   * Upon detecting a change, it calls `ref.read(webViewKeyProvider.notifier).incrementKey()`.

   * Incrementing this key forces Flutter to rebuild the `InAppWebView` widget, which then uses the new User Agent from its `initialSettings`.

### 4.10. Resilient Selector Strategy & Modern Waiting Patterns

The automation engine implements state-of-the-art techniques for reliable DOM interaction, based on comprehensive research into modern web automation best practices. This section documents the core principles and implementation patterns.

#### 4.10.1. The Selector Priority Pyramid

Selectors must be a "contract," not an implementation detail. The most resilient selectors are based on a priority pyramid:

1. **Tier 1: User-Facing Locators** (Highest Priority)
   - ARIA roles and accessible names (`aria-label`, `role`)
   - Semantic HTML attributes that form an explicit contract
   - **Rationale:** These attributes are designed for accessibility and are least likely to change with styling updates

2. **Tier 2: Stable Test Hooks**
   - `data-testid` attributes (if available)
   - Stable IDs that are part of the application's public API
   - **Rationale:** Explicitly designed for testing, forming a contract between developers and automation

3. **Tier 3: Structural Relationships**
   - Modern CSS selectors like `:has()` for contextual relationships
   - `.closest()` traversal from stable inner elements to containers
   - **Rationale:** More resilient than direct paths, but still dependent on DOM structure

4. **Never Use:**
   - Auto-generated CSS classes (e.g., `.div-a23bc`)
   - Fragile DOM paths that break with minor layout changes
   - **Rationale:** These are implementation details that change frequently

**Implementation:** The `ai-studio.ts` chatbot module already follows this pattern, preferring `aria-label` selectors over class names. Future provider integrations should adopt this hierarchy.

#### 4.10.2. The "Sensor Array" Pattern for Asynchronous Waiting

Fixed `setTimeout` delays are an anti-pattern. A robust script uses a "sensor array" of modern browser APIs to synchronize with the application's state:

**Decision Matrix:**

| Use Case                                        | API                | Rationale                                                                                                                                                                         |
| ----------------------------------------------- | ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **DOM Structural Changes** (elements added/removed) | `MutationObserver` | Event-driven, responds immediately to DOM mutations. **Crucially, this avoids inefficient polling with `setInterval`, which is a primary cause of silent JavaScript context crashes on mobile.** |
| **Element Visibility** (scrolling, lazy-loading) | `IntersectionObserver` | Most performant for visibility checks. Essential for virtualized lists and lazy-loaded content. |
| **Layout-Dependent Properties** (animations, layout stabilization) | `requestAnimationFrame` polling | Synchronizes with browser's render loop. Correct tool for waiting on animations to complete. |

**Implementation:**

- **`waitForElement`** (`ts_src/utils/wait-for-element.ts`): Uses `MutationObserver` as primary strategy, with polling fallback for edge cases
- **`waitForVisibleElement`** (`ts_src/utils/wait-for-visible-element.ts`): Uses `IntersectionObserver` for viewport visibility detection
- **`waitForActionableElement`** (`ts_src/utils/wait-for-actionable-element.ts`): Combines `MutationObserver` with comprehensive actionability checks

#### 4.10.3. The 5-Point Actionability Check

An element is not ready for interaction just because it exists. The `waitForActionableElement` utility implements a comprehensive checklist:

1. **Attached**: Element is in the DOM (`element.isConnected`)
2. **Visible**: Using modern `element.checkVisibility()` API or fallback (`offsetParent !== null`)
3. **Stable**: No ongoing animations (using `element.getAnimations()` and `animation.finished` promises)
4. **Enabled**: Check for `disabled`, `aria-disabled`, `inert` attributes (including parent containers)
5. **Unoccluded**: Use `document.elementFromPoint()` to verify element is actually clickable

**Usage:** All critical interactions in `ai-studio.ts` use `waitForActionableElement` before clicking or setting values. This replaces scattered visibility checks with a unified, comprehensive validation.

#### 4.10.4. Mobile Performance Principles: "Observe Narrowly, Process Lightly"

`MutationObserver` can be a significant drain on CPU and battery if misconfigured. The core principle for mobile is:

##### "Observe Narrowly, Process Lightly"

1. **Observe the Smallest Possible DOM Subtree:**
   - Prefer specific containers (e.g., `ms-chat-session`) over `document.body`
   - Example: `automation_engine.ts` observes `ms-chat-session` when available, falling back to `body` only if necessary

2. **Filter Mutations Aggressively:**
   - Only process mutations that are relevant to the automation goal
   - Example: `automation_engine.ts` filters mutations to only process those that add button elements

3. **Disconnect Immediately After Purpose is Served:**
   - Observers should disconnect as soon as their condition is met
   - Example: `automation_engine.ts` disconnects the observer immediately after detecting the target state

4. **Limit Observation Types:**
   - Only observe necessary mutation types (`childList`, `attributes`, etc.)
   - Avoid observing `characterData` or `subtree` when not needed

**Implementation:** The `startObserving()` function in `automation_engine.ts` demonstrates these principles:

- Observes narrowest scope (`ms-chat-session` preferred)
- Filters mutations before processing (`shouldProcessMutation`)
- Disconnects immediately when condition met (`stopObserving()`)

#### 4.10.5. Debugging Flakiness Systematically

Intermittent failures should be diagnosed systematically, not by attempting local reproduction.

**Failure Classification:**

1. **Locator Failure**: Selector no longer matches (site changed, selector outdated)
   - **Diagnosis:** Analyze DOM snapshots from CI runs
   - **Fix:** Update selector or add fallback to selector priority pyramid

2. **Wait Failure**: Element exists but timing is wrong (race condition)
   - **Diagnosis:** Check if `waitForActionableElement` is being used, verify timeout values
   - **Fix:** Increase timeout, add retry logic, or use more appropriate waiting strategy

3. **State Failure**: Application is in unexpected state (CAPTCHA, login required)
   - **Diagnosis:** Analyze error messages and page state from logs
   - **Fix:** Implement graceful degradation (see §4.3)

**Process:**

1. **Analyze Artifacts:** Use traces, videos, screenshots from CI runs (not local reproduction)
2. **Classify Failure:** Determine if it's Locator, Wait, or State issue
3. **Apply Fix:** Based on classification, apply appropriate solution
4. **Verify:** Re-run in CI environment, not locally

**Reference:** This methodology is based on industry best practices from leading test automation frameworks (Playwright, Cypress) and modern web automation research.

### 4.11. Architectural Evolution for Preset-Based Orchestration

This vision requires extending our already robust architecture to support dynamic, multi-target automation.

#### 4.11.1. Preset Persistence with Drift

Presets and their organization will be stored in the local database.

- **Schema Evolution:** A new `Presets` table will be added to `lib/core/database/database.dart`. The schema will be:

  - `id`: `IntColumn` (auto-incrementing primary key).
  - `name`: `TextColumn` (must be unique).
  - `providerId`: `TextColumn` (nullable; `NULL` identifies a Group).
  - `displayOrder`: `IntColumn` (to manage user-defined order for grouping).
  - `is_pinned`: `BoolColumn`.
  - `is_collapsed`: `BoolColumn` (UI state for groups).
  - `settings`: `TextColumn` (stores a JSON blob containing model, temperature, affixes, etc.).

- **Data Access:** The `AppDatabase` class will expose CRUD methods for presets, including a `watchAllPresets()` stream ordered by `displayOrder`.

#### 4.11.2. State Management and Orchestration Logic

The Riverpod layer will be extended to manage the new entities and workflow.

- **State Providers:**

  - `presetsProvider`: A `StreamProvider` that watches `db.watchAllPresets()`.
  - `selectedPresetsProvider`: A `StateProvider<Set<int>>` that holds the IDs of the presets checked by the user for the next dispatch.

- **Orchestration Logic (`ConversationActions`):**

  - The `sendPromptToAutomation` method will be refactored. It will no longer take a simple prompt.
  - Its new logic will be:

    1. Read the `selectedPresetsProvider` to get the target preset IDs.
    2. Read the full list of presets from `presetsProvider`.
    3. For each selected preset ID:

       a. Find the preset object and its parent group (by iterating backwards on `displayOrder`).

       b. Call a new private method, `_dispatchAutomationForPreset`, passing the combined prompt and settings.

  - `_dispatchAutomationForPreset` will contain the logic to launch a single automation cycle, similar to the current implementation.

#### 4.11.3. UI for Preset Management

A new, dedicated UI will be created for managing presets, likely accessible from the Hub screen.

- **Features:** Inspired by `Presets.tsx`, it will use a library like `reorderable_list` to allow drag-and-drop reordering. It will support creating presets/groups, editing, duplicating, and pinning.

- **Selection:** The main Hub UI will display the list of presets with checkboxes, allowing the user to easily select targets for the multi-dispatch.

### 5.1. Native Conversation Persistence

- **Technology:** **Drift** is used to create a local SQLite database.
- **Schema:** The database stores `Conversations` and `Messages`.
- **Interaction:** A Riverpod `ConversationProvider` interacts with Drift-generated DAOs to read and write to the database, using reactive queries (`.watch()`) to update the UI automatically.

### 5.2. Web Session Persistence

- **Technology:** The WebView handles cookies automatically via its built-in `CookieManager`. No manual cookie management is performed.

- **Implementation:** Cookies are managed entirely by the WebView's native cookie storage mechanism. Users authenticate directly within the WebView, and their session persists naturally through the WebView's cookie handling.

- **Known Limitation - Google CookieMismatch Error:**
  - Google services (including AI Studio) may display a "CookieMismatch" error page when accessed from embedded WebViews due to Google's security policies.
  - This is a known limitation where Google detects the embedded WebView context and blocks access, even with `thirdPartyCookiesEnabled: true` configured.
  - The app includes a redirect handler that attempts to navigate to the Google login page when this error is detected, but Google's security policies may still prevent successful authentication.
  - **Workaround:** Users may need to authenticate in a regular browser first, or use Chrome Custom Tabs (future enhancement) instead of embedded WebViews for Google services.

### 5.7. Extensibility through XML Structure

The XML prompt schema enables forward‑compatible enhancements without breaking changes. New tags and attributes can unlock advanced capabilities like targeted refinements, structured outputs, and multi‑model comparisons.

Example: Targeted Message Refinement

```xml
<history>
User: ...

Assistant: Initial code example...
</history>
<user_input>
  <![CDATA[
  Please refine your response with messageId="asst_123". Add error handling to the code.
  ]]>
  </user_input>
```

Example: Requiring Structured Output for Comparison

```xml
<system>
  <![CDATA[
  Your response MUST be enclosed in an <ai_response> tag.
  ]]>
</system>
```

By evolving the schema (e.g., adding attributes or new sections), the prompt becomes a rich, machine‑readable document that supports progressively sophisticated features in the AI Hybrid Hub.

## 6. Evolution from MVP to Full Version

| Feature             | MVP (v1.0)                      | Full Version (v2.0)                                    |
| :------------------ | :------------------------------ | :----------------------------------------------------- |
| **Scope**           | 1 Provider (Google AI Studio)   | 4+ Providers                                           |
| **Database**        | **None** (in-memory state)      | ✅ **Drift** for history                               |
| **CSS Selectors**   | **Hardcoded** in TypeScript     | ✅ **Hardcoded** in TypeScript                          |
| **Conversation Model**| Linear (single shot per prompt) | ✅ **Multi-Turn (Contextual Seeding)**                 |
| **Extraction Process**| One-time per prompt             | ✅ **Iterative Refinement & Replacement**              |
| **WebView State**   | Persistent session              | ✅ **Reloaded per turn for clean context**             |
| **Message Editing** | Only user prompts               | ✅ **Manual editing of AI responses in Hub**           |
| **AI Instruction**  | Via prompt content only         | ✅ **Persistent System Prompt (Native & Emulated)**    |
| **Fallback Strategy** | Yes (simple hardcoded array)    | ✅ **Yes (array of fallbacks)**                        |
| **Error Handling**  | Structured (code, location)     | ✅ **Specific Heuristic Triage**                       |
| **`MutationObserver`**| Simple (absence of indicator)   | ✅ **Optimized (two-step)**                            |
| **Advanced Cases**  | Ignored (e.g., Shadow DOM)      | ✅ **Handled**                                         |
| **Code Quality**    | `flutter_lints` (standard)      | ✅ **`very_good_analysis` (strict)**                   |

## 7. New Provider Integration Guide

This section promotes and translates the original French annex to a first-class guide. It captures the methodology and lessons learned when integrating Google AI Studio and generalizes them to any new web provider (ChatGPT, Claude, Qwen, Zai, Kimi, etc.).

### Fundamental Principles

1. Simplicity first: Start with the simplest and most standard CSS selectors and DOM operations.
2. From reliable to uncertain: If a container is hard to target, find a stable inner element (like a button) and traverse up to its parent using `.closest()` to locate a robust anchor.
3. Explicit asynchrony: Avoid blind fixed delays (`setTimeout`, `Future.delayed`). Prefer active waits (e.g., a `waitForElement` utility) and explicit asynchronous communication (`callAsyncJavaScript`).
4. Fault tolerance: The automation must be resilient. It should still accomplish its primary mission (e.g., extract text) even if non-critical errors occur in the page.
5. Universal injection: The bridge script should be present on all pages to survive navigations and rendering crashes. The decision logic ("Should I act?") belongs in the script itself, not in the injection code.

---

### Step-by-Step Integration Process

#### Phase 1: Manual Analysis (Desktop Browser)

Goal: Identify reliable anchor points for each action.

1. Identify the three fundamental actions for a new provider:
   - Enter text: Which `<textarea>` or `<input>` is used?
   - Submit the prompt: Which `<button>` submits?
   - Extract the response: What is the most stable method? (see below)
2. Find the simplest selectors:
   - Use Chrome/Firefox DevTools on the provider site.
   - Prefer `[aria-label]`, IDs, or `data-*` attributes over generic, auto-generated CSS classes (e.g., `.div-a23bc`).
   - Create a quick validation script (like `validation/aistudio_selector_validator.js`) to test selectors directly in the console.
3. Validate the extraction strategy:
   - Scenario A (ideal): Check whether the conversation content is available in a global JavaScript object (e.g., `window.appState`). If yes, prefer this.
   - Scenario B (most common): If no global object exists, use the "reliable-to-uncertain" strategy:
     1) Find a unique, stable button on the finalized response (e.g., "Copy", "Edit", "Regenerate").
     2) Use this button as an anchor point.
     3) From that button, traverse up with `.closest()` to the main message container.
     4) Once located, use `.querySelector()` to find the element containing the response text.
     5) Validate the sequence with your validation script.

#### Phase 2: Implement Logic (TypeScript)

1. Create a new chatbot file in `ts_src/chatbots/` (e.g., `chatgpt.ts`).
2. Implement the `Chatbot` interface using your validated selectors and strategy:
   - `waitForReady()`: Waits for an element that appears only once the page is fully ready.
   - `sendPrompt(prompt)`: Locate the input field, fill it, locate the submit button, and click.
   - `extractResponse()`: Implement the validated extraction strategy. Use a resilient approach to separate value extraction from cleanup actions (e.g., closing edit mode) with permissive `try...catch` blocks.
3. Add small strategic delays (50–100ms) only after DOM-changing actions (like a click that reveals a textarea) to allow the page framework to settle.
4. Update `automation_engine.ts` to register the new provider in `SUPPORTED_SITES`.

#### Phase 3: Orchestration & Communication (Dart)

1. **Prefer `callAsyncJavaScript` for stability:** This is the most critical lesson. To call an async JS function and await its result, **do NOT use `evaluateJavascript` with manual `Promise`s and timeouts.** Use `callAsyncJavaScript` instead.

    **File:** `lib/features/webview/bridge/javascript_bridge.dart`

    ```dart
    // Fragile old method (DO NOT USE)
    // await controller.evaluateJavascript(source: '(async () => { window.res = await func() })()');
    // await Future.delayed(Duration(milliseconds: 100));
    // result = await controller.evaluateJavascript(source: 'window.res');

    // Robust new method (USE THIS)
    final result = await controller.callAsyncJavaScript(
      functionBody: 'return await window.extractFinalResponse();',
    );
    // The value is directly available in result.value
    final String responseText = result.value;
    ```

    **Note:** This correction is critical and must be the standard for all future integrations. The `callAsyncJavaScript` API handles async operations reliably and avoids race conditions.

2. **Tolerant error handling:** In `
