# Full Blueprint: AI Hybrid Hub (v2.0)

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

### 3.2. The "Assist & Validate" Meta-Conversation Workflow

The core user experience is building a "meta-conversation" within the native Hub. This is orchestrated through a state-driven cycle that gives the user complete control over the AI's input and output.

#### 3.2.1. Building the Conversation: Contextual Seeding & Iterative Refinement (XML-Driven)

The workflow is now driven by a structured XML prompt that ensures clarity, eliminates ambiguity, and provides extensibility. While a simpler plain‑text format remains available as a fallback, the default is the following XML schema:

```xml
<prompt>
  <!-- System instructions provide high-level guidance for the entire conversation. -->
  <system>
    <![CDATA[
    You are an expert Flutter developer. All code examples must be sound and null-safe.
    ]]>
  </system>

  <!-- The history provides the full conversational context. -->
  <history>
User: How do I implement a Riverpod provider with keepAlive?

Assistant: To keep a provider's state, you can use the `@Riverpod(keepAlive: true)` annotation. Here is an example...

User: [Additional turns would be added here as flat text]
  </history>

  <!-- The user's current, specific request. -->
  <user_input>
    <![CDATA[
    Thank you. Now, show me how to test it.
    ]]>
  </user_input>
</prompt>
```

Key principles of this structure:

- CDATA encapsulation for all user/assistant/system content to avoid breaking XML on `<`/`>` characters.
- Clear separation of roles via `<system>`, `<history>`, and `<user_input>` tags to improve instruction adherence. History is formatted as flat text inside `<history>` tags for natural readability.
- Unchanged automation engine: the TypeScript bridge still receives a single `prompt` string and injects it; prompt construction logic lives in Dart.
- Provider capability nuance: for providers with a reliable, native "system prompt" field, the `<system>` section MAY be omitted from the XML and provided natively instead (see §4.6 Exception).

Flow remains centered on two actions:

#### A. Starting a New Turn (Contextual Seeding)

1. **Context Compilation (XML):** The Dart layer composes `<system>`, `<history>` (containing flat text format of conversation turns), and the new `<user_input>` into a single XML string.
2. **Session Reset:** The `WebView` is reloaded to a "new chat" URL to ensure a clean slate prior to injection.
3. **Automation Kick-off:** The XML string is passed to `startAutomation(prompt)` in the JavaScript bridge for injection and submission.
4. **State Transition:** `idle` → `sending` → `observing` as the AI generates its response in the `WebView`.

#### B. Refining the Current Turn (Iterative Refinement Loop)

1. **Initial Extraction:** The user triggers "Extract & View Hub"; Dart calls `extractFinalResponse()` and updates the last AI message in the Hub while remaining in `refining`.
2. **Review & Re‑engage:** The user reviews in the Hub, then returns to the `WebView` to request changes if needed.
3. **Manual Refinement:** The user continues the conversation directly in the `WebView`.
4. **Re‑extraction:** After the AI updates its response, the user extracts again; Dart replaces the same AI message’s content in the Hub. Repeat as needed.
5. **Finalization:** The "Done" action finalizes the turn and returns automation state to `idle`.

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

- **Remote Configuration:** CSS selectors are **NOT** hardcoded. They are defined in a **remote JSON file**, versioned per provider.
  - **JSON Structure:** Each selector definition includes a `primary` selector and an ordered array of `fallbacks`.
  - **Management:** The Dart layer is responsible for fetching (with `ETag`), caching locally, and injecting this configuration into the `WebView` on startup.

- **"Defense in Depth" Fallback Strategy:** The TS engine sequentially iterates through selectors (`primary`, then `fallbacks`) until an "actionable" (visible, not-disabled) element is found. See §4.10.1 for the Selector Priority Pyramid that guides selector choice.

- **Optimized `MutationObserver`:** The "Observe Narrowly, Process Lightly" strategy is implemented to preserve performance and battery on mobile. See §4.10.4 for detailed mobile performance principles.

- **Shadow DOM Handling:** The engine includes a recursive search function for `open` mode and a "monkey-patching" strategy to attempt to force `open` mode on `closed` roots.

- **Modern Waiting Patterns:** The engine uses event-driven APIs (`MutationObserver`, `IntersectionObserver`) instead of polling. See §4.10.2 for the "Sensor Array" pattern and §4.10.3 for comprehensive actionability checks.

This configuration-driven approach directly supports the README's Multi-Provider Support goal: by relying on a remotely fetched JSON (with ETag-based caching), providers can be added or updated (selectors and behaviors) without requiring a new app release.

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

##### Layer 2: Proactive Heartbeat Verification

- **Heartbeat Pattern:** The `checkBridgeHeartbeat()` method uses `evaluateJavascript` wrapped in `Future.timeout()` (2 seconds) to detect dead contexts.
- **Canonical Signal:** A `TimeoutException` is not an error but the **canonical signal of a dead context**. This prevents infinite hangs on "zombie" contexts that appear alive but hang indefinitely.
- **Integration:** Heartbeat checks are performed:
  - Before each polling iteration in `waitForBridgeReady()` to detect zombie contexts early
  - Before critical operations (`startAutomation`, `extractFinalResponse`) to fail fast
  - After SPA navigations to validate bridge health
  - On app resume to detect iOS "zombie" contexts after backgrounding

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

### 4.4. State-Driven Workflow Orchestration (Dart-side)

The complex "Assist & Validate" workflow is orchestrated entirely within the Dart layer, primarily in the `ConversationProvider`. The JavaScript bridge remains a simple "driver" for the web page.

- **Context Management:** The private method `_buildPromptWithContext` is responsible for generating the XML prompt string. It composes `<system>`, `<history>` (flat text format), and `<user_input>` from current state. A robust XML construction approach will be used (library vs. safe builder to be decided). A legacy plain‑text format may be retained as a user‑selectable fallback. The instruction text that introduces the conversation history is customizable via the `historyContextInstruction` setting in `GeneralSettings`, allowing users to fine-tune how context is framed for the AI.

- **WebView Lifecycle Control:** Before starting any new conversation turn (Contextual Seeding), the `_orchestrateAutomation` method explicitly calls `webViewController.loadUrl()` with the provider's "new chat" URL. This is a critical step to ensure each turn is hermetic and contextually clean.

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

To create a fluid and non-obstructive user experience, the application adopts several advanced UI patterns managed by dedicated Riverpod state providers.

#### 4.7.1. Draggable & Minimizable Companion Overlay

The automation overlay is not a static banner. It is a fully interactive floating panel designed to maximize visibility of the underlying WebView.

- **Implementation:**
  - A `GestureDetector` with an `onPanUpdate` callback tracks drag movements. This is preferred over the `Draggable` widget for real-time positional control.
  - A dedicated `OverlayStateNotifier` provider (`@Riverpod(keepAlive: true)`) manages the overlay's state, including its `Offset` (position) and a boolean `isMinimized`. `keepAlive` is essential to preserve the panel's position when switching between tabs.
  - The panel's position is clamped to the screen's boundaries. This is achieved in the UI layer (`main.dart`) by measuring the overlay's `RenderBox` size via a `GlobalKey` and the screen's `MediaQuery` size, then passing these constraints to a clamping method in the notifier.
  - An `AnimatedSwitcher` handles the smooth visual transition between the full-sized panel and its minimized `FloatingActionButton` state.

#### 4.7.2. Decoupled Error & Status Messaging

To provide non-destructive user feedback (e.g., an extraction error) without polluting the permanent conversation history, the application uses a dedicated provider for ephemeral messages.

- **Problem:** An extraction failure should not overwrite the "Assistant is responding..." message, as this would prevent the user from retrying the extraction.
- **Solution:**
  - An `EphemeralMessageProvider` (`@riverpod`) holds a single, nullable `Message` object.
  - When an error occurs (e.g., in `ConversationProvider.extractAndReturnToHub`), it posts the error message to this provider instead of altering its own state list.
  - The `HubScreen` UI listens to `EphemeralMessageProvider`. If the state is not null, it renders the message as a temporary `ChatBubble` at the end of the `ListView`.
  - The ephemeral message is cleared automatically on the next user action (like starting a new extraction or finalizing the automation).

#### 4.7.3. Signal-Based UI Actions (Auto-Scrolling)

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

| Use Case | API | Rationale |
|----------|-----|-----------|
| **DOM Structural Changes** (elements added/removed) | `MutationObserver` | Event-driven, responds immediately to DOM mutations. More efficient than polling. |
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

### 5.1. Native Conversation Persistence

- **Technology:** **Drift** is used to create a local SQLite database.
- **Schema:** The database stores `Conversations` and `Messages`.
- **Interaction:** A Riverpod `ConversationProvider` interacts with Drift-generated DAOs to read and write to the database, using reactive queries (`.watch()`) to update the UI automatically.

### 5.2. Web Session Persistence

- **Technology:** The native singletons **`CookieManager`** and **`WebStorageManager`** from `flutter_inappwebview`.
- **Implementation:** A Dart `SessionManager` service is responsible for managing cookies to maintain login sessions, including platform-specific workarounds for Android and iOS to ensure reliability across app restarts.

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
| **CSS Selectors**   | **Hardcoded** in TypeScript     | ✅ **Remote JSON Configuration**                       |
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

2. **Tolerant error handling:** In `extractAndReturnToHub`, prioritize returning useful text even if an error also occurred. Capture both and decide based on response presence/emptiness:

    ```dart
    String? responseText;
    Object? error;

    try {
      // Use callAsyncJavaScript
      responseText = await bridge.extractFinalResponse(); 
    } on Object catch (e) {
      error = e;
    }

    if (responseText != null && responseText.isNotEmpty) {
      // Success! Ignore 'error' or log it.
    } else {
      // Failure, handle 'error'.
    }
    ```

3. **Integrate response observer:** If waiting is needed after sending the prompt, transition to `.observing()` and start a provider-specific response observer; adapt `checkUIState` to detect the provider's end-of-response indicator (e.g., the appearance of a "Copy" button).

#### Phase 4: Final Debugging

1. Use JS logs during development at key steps (e.g., `console.log('Target element:', element.outerHTML)`).
2. Use DOM inspection tools to capture a snapshot of the DOM when extraction fails and analyze why selectors did not match.
