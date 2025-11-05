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

- **"Defense in Depth" Fallback Strategy:** The TS engine sequentially iterates through selectors (`primary`, then `fallbacks`) until an "actionable" (visible, not-disabled) element is found.

- **Optimized `MutationObserver`:** The "Ephemeral Two-Step Observer" strategy is implemented to preserve performance and battery on mobile.

- **Shadow DOM Handling:** The engine includes a recursive search function for `open` mode and a "monkey-patching" strategy to attempt to force `open` mode on `closed` roots.

This configuration-driven approach directly supports the README's Multi-Provider Support goal: by relying on a remotely fetched JSON (with ETag-based caching), providers can be added or updated (selectors and behaviors) without requiring a new app release.

### 4.2. JavaScript Bridge (RPC API)

- **Pattern:** The bridge is an asynchronous **RPC (Remote Procedure Call)** API based on `Promise`s and the `JavaScriptHandler`s of `flutter_inappwebview`.
- **API Contract:** The TypeScript API (`automation_engine.ts`) exposes typed functions (e.g., `startAutomation`). The Dart API (`javascript_bridge.dart`) registers corresponding handlers.
- **State Communication:** For status updates and errors, the TS engine uses a **unidirectional event stream** to a single Dart handler (`automationBridge`), sending structured `AutomationEvent` objects.

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

## 5. Data & Persistence

### 4.7. Advanced UI/UX Patterns

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

1. Prefer `callAsyncJavaScript` for stability: To call an async JS function and await its result, avoid `evaluateJavascript` with manual `Promise`s and timeouts. Use `callAsyncJavaScript` so the value is returned reliably via `result.value`.
2. Tolerant error handling: In `extractAndReturnToHub`, prioritize returning useful text even if an error also occurred. Capture both and decide based on response presence/emptiness.
3. Integrate response observer: If waiting is needed after sending the prompt, transition to `.observing()` and start a provider-specific response observer; adapt `checkUIState` to detect the provider's end-of-response indicator (e.g., the appearance of a "Copy" button).

#### Phase 4: Final Debugging

1. Use JS logs during development at key steps (e.g., `console.log('Target element:', element.outerHTML)`).
2. Use DOM inspection tools to capture a snapshot of the DOM when extraction fails and analyze why selectors did not match.

### Annexe de Blueprint : Guide d'Intégration d'un Nouveau Provider Web

Ce guide récapitule la méthodologie et les leçons apprises lors de l'intégration de Google AI Studio. Suivre ces étapes permettra d'intégrer de nouveaux providers (ChatGPT, Claude, etc.) de manière rapide, robuste et maintenable.

#### Principes Fondamentaux

1. **Simplicité avant tout :** Toujours commencer par les sélecteurs CSS et les opérations JavaScript les plus simples et les plus standards possible.
2. **Partir du Fiable pour Trouver l'Incertain :** Si un conteneur est difficile à cibler, trouver un élément simple à l'intérieur (comme un bouton) et remonter à son parent (`.closest()`).
3. **Asynchronisme Explicite :** Ne jamais se fier à des délais fixes (`setTimeout`, `Future.delayed`). Utiliser des mécanismes d'attente active (`waitForElement`) et des retours de communication explicites (`callAsyncJavaScript`).
4. **Tolérance aux Fautes :** L'automatisation doit être "blindée". Elle doit pouvoir réussir sa mission principale (ex: extraire du texte) même si des erreurs non critiques se produisent sur la page web.
5. **Injection Universelle :** Le script du bridge doit être présent sur toutes les pages pour survivre aux navigations et aux crashs de rendu. La logique de décision ("Dois-je agir ?") appartient au script lui-même, pas au code d'injection.

---

### Processus d'Intégration Étape par Étape

#### Phase 1 : Analyse Manuelle (Navigateur de Bureau)

L'objectif est d'identifier les "points d'ancrage" fiables pour chaque action.

1. **Identifier les Actions Clés :** Pour un nouveau provider, déterminez les 3 actions fondamentales :
    - **Entrer du texte :** Quel est l'élément `<textarea>` ou `<input>` ?
    - **Envoyer le prompt :** Quel est le bouton `<button>` de soumission ?
    - **Extraire la réponse :** Quelle est la méthode la plus stable ? (Voir point 3)

2. **Trouver les Sélecteurs les plus Simples :**
    - Ouvrez le site du provider dans les outils de développement de Chrome/Firefox.
    - Identifiez les sélecteurs les plus uniques et les moins susceptibles de changer. Privilégiez les `[aria-label]`, les ID, ou les attributs `data-*` par rapport aux classes CSS génériques (`.div-a23bc`).
    - Créez un script de validation (similaire à `validation/aistudio_selector_validator.js`) pour tester vos sélecteurs directement dans la console.

3. **Valider la Stratégie d'Extraction :**
    - **Scénario A (Idéal) :** Utilisez la **Phase 1 du Guide d'Investigation** pour chercher si le contenu de la conversation est dans un objet JavaScript global (`window.appState`, etc.). Si oui, c'est la méthode à privilégier.
    - **Scénario B (Le plus courant) :** Si les données ne sont pas dans un objet global, adoptez la stratégie **"Partir du Fiable"** :
        1. Trouvez un bouton unique et stable sur la réponse finalisée (ex: "Copier", "Modifier", "Régénérer").
        2. Utilisez ce bouton comme point d'ancrage.
        3. À partir de ce bouton, utilisez `.closest()` pour remonter au conteneur principal du message.
        4. Une fois le conteneur trouvé, utilisez `.querySelector()` pour trouver l'élément contenant le texte de la réponse.
        5. Validez cette séquence dans votre script de validation.

#### Phase 2 : Implémentation de la Logique (TypeScript)

1. **Créer le Fichier du Chatbot :** Créez un nouveau fichier dans `ts_src/chatbots/`, par exemple `chatgpt.ts`.
2. **Implémenter l'Interface `Chatbot` :** Remplissez les trois fonctions requises en utilisant les sélecteurs et la stratégie validés à l'étape précédente.
    - `waitForReady()`: Attend un élément qui n'apparaît qu'une fois la page entièrement chargée.
    - `sendPrompt(prompt)`: Implémente la séquence : trouver le champ, le remplir, trouver le bouton, cliquer.
    - `extractResponse()`: Implémente la stratégie d'extraction validée. **Utilisez la logique de "blindage"** pour séparer l'extraction de valeur des actions de nettoyage (comme fermer un mode édition) avec des `try...catch` permissifs.

3. **Ajouter des Délais Stratégiques :** Incorporez des délais très courts (50-100ms) après des actions qui modifient le DOM (comme un clic qui fait apparaître un `textarea`) pour laisser le temps au framework de la page de se stabiliser.

4. **Mettre à jour `automation_engine.ts` :** Ajoutez le nouveau provider à la liste `SUPPORTED_SITES`.

#### Phase 3 : Orchestration et Communication (Dart)

1. **Utiliser `callAsyncJavaScript` pour la Stabilité :** C'est la leçon finale et la plus importante. Pour appeler une fonction `async` de votre script JS et attendre son résultat, **n'utilisez pas `evaluateJavascript` avec des `Promise`s manuelles et des délais.** Utilisez `callAsyncJavaScript`.

    **Fichier : `lib/features/webview/bridge/javascript_bridge.dart`**

    ```dart
    // Ancienne méthode fragile
    // await controller.evaluateJavascript(source: '(async () => { window.res = await func() })()');
    // await Future.delayed(Duration(milliseconds: 100));
    // result = await controller.evaluateJavascript(source: 'window.res');

    // Nouvelle méthode robuste
    final result = await controller.callAsyncJavaScript(
      functionBody: 'return await window.extractFinalResponse();',
    );
    // La valeur est directement dans result.value
    final String responseText = result.value;
    ```

    *Note : Cette correction cruciale a été faite manuellement par vous et doit être la norme pour toutes les futures intégrations.*

2. **Gestion d'Erreur Tolérante :** Lors de l'implémentation de `extractAndReturnToHub` pour le nouveau provider, adoptez la structure qui priorise le résultat :

    ```dart
    String? responseText;
    Object? error;

    try {
      // Utilise callAsyncJavaScript
      responseText = await bridge.extractFinalResponse(); 
    } on Object catch (e) {
      error = e;
    }

    if (responseText != null && responseText.isNotEmpty) {
      // Succès ! On ignore 'error' ou on le logue.
    } else {
      // Échec, on traite 'error'.
    }
    ```

3. **Intégrer le Déclenchement de l'Observateur :** Si le nouveau provider nécessite une attente après l'envoi du prompt, réutilisez le système d'observateur :
    - Dans `conversation_provider.dart`, après `bridge.startAutomation()`, passez à l'état `.observing()` et appelez `bridge.startResponseObserver()`.
    - Dans le script JS (`automation_engine.ts`), adaptez la logique de `checkUIState` pour détecter l'indicateur de fin de réponse du nouveau provider (par exemple, l'apparition d'un bouton "Copier").

#### Phase 4 : Débogage Final

1. **Utiliser les Logs JS :** Gardez les logs JS (`console.log`) sur les étapes clés pendant le développement. Le log `console.log('Target element:', element.outerHTML)` est particulièrement puissant.
2. **Utiliser l'Inspecteur de DOM :** Si une extraction échoue, utilisez le bouton "Inspect DOM" pour obtenir une "photographie" de l'état de la page au moment de l'échec et comprendre pourquoi les sélecteurs ne correspondent pas.
