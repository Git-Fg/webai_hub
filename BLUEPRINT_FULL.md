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

-   **Target Providers:**
    1.  Google AI Studio
    2.  Qwen
    3.  Z-ai
    4.  Kimi
-   **Navigation:** An `IndexedStack` manages 5 persistent views: 1 native Hub + 4 dedicated `WebView`s.

### 3.2. The "Assist & Validate" Meta-Conversation Workflow

The core user experience is building a "meta-conversation" within the native Hub. This is orchestrated through a state-driven cycle that gives the user complete control over the AI's input and output.

#### 3.2.1. Building the Conversation: Contextual Seeding & Iterative Refinement

The workflow is defined by two primary user actions: **Starting a New Turn** and **Refining the Current Turn**.

#### A. Starting a New Turn (Contextual Seeding)

This is triggered when the user sends a new prompt from the Hub UI while the automation state is `idle`.

1.  **Context Compilation:** The `ConversationProvider` (Dart) iterates through the existing Hub message history. It compiles them into a single, structured string.

    *   **Format:** A Markdown-like plain text format is preferred for maximum LLM compatibility (e.g., `User: ... \n\n Assistant: ...`). This is simpler and more effective than custom XML.

2.  **Session Reset:** To ensure a clean slate and prevent context leaks from previous web sessions, the `WebView` is programmatically reloaded to its initial "new chat" URL.

3.  **Automation Kick-off:** Once the page is ready, the compiled context string is passed to the `startAutomation` function of the JavaScript bridge. The script injects this full context as the initial prompt.

4.  **State Transition:** The app state moves from `idle` -> `sending` -> `observing` as the AI generates its response in the `WebView`.

#### B. Refining the Current Turn (Iterative Refinement Loop)

This phase begins once the AI's response is detected, and the automation state moves to `refining`.

1.  **Initial Extraction:** The user clicks "Extract & View Hub". Dart calls `extractFinalResponse()`, and the extracted text updates the last AI message in the Hub. The user is returned to the Hub tab (index 0). **Crucially, the automation state remains `refining`**.

2.  **Review & Re-engage:** The user can review the extracted text. If it needs changes, they simply navigate back to the `WebView` tab.

3.  **Manual Refinement:** The user can continue the conversation directly in the `WebView` (e.g., asking for clarification, rephrasing).

4.  **Re-extraction:** After the AI provides an updated response in the `WebView`, the user clicks "Extract & View Hub" again. The `extractFinalResponse()` function is called, and the Dart layer **replaces the content of the same AI message** in the Hub with the newly extracted text. This loop can be repeated as many times as needed.

5.  **Finalization:** Once satisfied, the user clicks the **"Done"** button on the Companion Overlay. This finalizes the turn, moving the automation state back to `idle` and making the application ready to start a new turn (back to step A).

### 3.3. Advanced User Controls

To enhance the user's ability to curate the perfect conversation, two advanced features are integrated directly into the Hub UI.

#### 3.3.1. Manual Message Editing

The user is the final authority on the conversation's content. After an AI response has been extracted and finalized (i.e., the automation state is `idle`), the user can tap on any AI-generated message bubble in the Hub to open an editing dialog. This allows for manual corrections, additions, or removals. The edited text permanently replaces the original in the conversation history, ensuring that all future "Contextual Seeding" turns use the user-approved version.

#### 3.3.2. System Prompt Management

Users can define a persistent "system prompt" or master instruction (e.g., "You are an expert Flutter developer. All code examples must be sound and null-safe.") that guides the AI's behavior across an entire conversation. This prompt is applied at the beginning of each new turn, ensuring consistent tone, personality, and constraints.

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

### 4.4. State-Driven Workflow Orchestration (Dart-side)

The complex "Assist & Validate" workflow is orchestrated entirely within the Dart layer, primarily in the `ConversationProvider`. The JavaScript bridge remains a simple "driver" for the web page.

-   **Context Management:** A private method (`_buildContextualPrompt`) is responsible for serializing the `List<Message>` into a single string. It prefixes each message with its role (e.g., "User:", "Assistant:") to provide clear context for the LLM.

-   **WebView Lifecycle Control:** Before starting a new conversation turn (Contextual Seeding), the provider explicitly calls `webViewController.loadUrl()` on the target provider's "new chat" URL. This is a critical step to ensure each turn is hermetic and contextually clean.

-   **State Machine Logic:** The `AutomationState` provider acts as the central state machine.

    -   `idle`: The default state. Sending a prompt from here triggers the **Contextual Seeding** workflow.

    -   `sending`/`observing`: Transitional states during AI response generation.

    -   `refining`: A persistent, looping state. The app remains here throughout the **Iterative Refinement** process. All `extractAndReturnToHub` calls during this state will update the last AI message.

    -   The `finalizeAutomation` method (triggered by the "Done" button) is the sole path from `refining` back to `idle`.

### 4.5. Native-Side Conversation Curation

The logic for manual message editing is handled entirely within the Dart/Riverpod layer, requiring no changes to the TypeScript automation engine.

-   **State Management:** The `ConversationProvider` will expose a new method, `editMessage(messageId, newText)`. This method finds the target message in the state list and replaces it with a new instance containing the updated text.

-   **UI Trigger:** The `ChatBubble` widget's `onTap` behavior will be updated to allow editing of both user and assistant messages, but only when the `AutomationState` is `idle`. This prevents editing a message that is actively being refined by the AI.

### 4.6. Dual-Strategy System Prompt Injection

To provide maximum compatibility, the system prompt is implemented using a dual strategy, chosen based on the capabilities of the target web UI.

-   **Provider Configuration:** The remote JSON configuration for each provider will be extended with a `systemPromptSelector` field. If this field is present and not null, the "Native Strategy" is used. Otherwise, the "Emulation Strategy" is the fallback.

-   **Global State:** A new `SystemPromptProvider` (`@Riverpod(keepAlive: true)`) will be created to store the user-defined system prompt string globally. A UI element (e.g., a settings dialog accessible from the `AppBar`) will allow the user to modify this state.

-   **Strategy 1: Native Injection (for compatible UIs)**

    1.  The `Chatbot` TypeScript interface's `sendPrompt` method is updated to `sendPrompt(prompt: string, systemPrompt?: string)`.

    2.  The Dart `ConversationProvider` calls the bridge, passing the main prompt and the system prompt as separate arguments.

    3.  The specific chatbot's TypeScript implementation (`chatgpt.ts`, for example) uses the `systemPromptSelector` to find the dedicated input field on the web page and populates it with the `systemPrompt` text before sending the main `prompt`.

-   **Strategy 2: Emulation (for UIs without a dedicated field, like AI Studio)**

    1.  If `systemPromptSelector` is null in the provider's configuration, the Dart `ConversationProvider` takes responsibility.

    2.  Before building the context string, it prepends the user's system prompt to the very beginning of the entire payload.

    3.  The combined string (System Prompt + Conversation History + New Prompt) is sent to the bridge's `startAutomation` method as a single `prompt` argument. The optional `systemPrompt` argument is left `null`.

    4.  The `ai-studio.ts` chatbot implementation requires no changes, as it receives a single, pre-formatted prompt to inject. This keeps the automation logic for simple UIs clean.

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


### Annexe de Blueprint : Guide d'Intégration d'un Nouveau Provider Web

Ce guide récapitule la méthodologie et les leçons apprises lors de l'intégration de Google AI Studio. Suivre ces étapes permettra d'intégrer de nouveaux providers (ChatGPT, Claude, etc.) de manière rapide, robuste et maintenable.

#### Principes Fondamentaux

1.  **Simplicité avant tout :** Toujours commencer par les sélecteurs CSS et les opérations JavaScript les plus simples et les plus standards possible.
2.  **Partir du Fiable pour Trouver l'Incertain :** Si un conteneur est difficile à cibler, trouver un élément simple à l'intérieur (comme un bouton) et remonter à son parent (`.closest()`).
3.  **Asynchronisme Explicite :** Ne jamais se fier à des délais fixes (`setTimeout`, `Future.delayed`). Utiliser des mécanismes d'attente active (`waitForElement`) et des retours de communication explicites (`callAsyncJavaScript`).
4.  **Tolérance aux Fautes :** L'automatisation doit être "blindée". Elle doit pouvoir réussir sa mission principale (ex: extraire du texte) même si des erreurs non critiques se produisent sur la page web.
5.  **Injection Universelle :** Le script du bridge doit être présent sur toutes les pages pour survivre aux navigations et aux crashs de rendu. La logique de décision ("Dois-je agir ?") appartient au script lui-même, pas au code d'injection.

---

### Processus d'Intégration Étape par Étape

#### Phase 1 : Analyse Manuelle (Navigateur de Bureau)

L'objectif est d'identifier les "points d'ancrage" fiables pour chaque action.

1.  **Identifier les Actions Clés :** Pour un nouveau provider, déterminez les 3 actions fondamentales :
    *   **Entrer du texte :** Quel est l'élément `<textarea>` ou `<input>` ?
    *   **Envoyer le prompt :** Quel est le bouton `<button>` de soumission ?
    *   **Extraire la réponse :** Quelle est la méthode la plus stable ? (Voir point 3)

2.  **Trouver les Sélecteurs les plus Simples :**
    *   Ouvrez le site du provider dans les outils de développement de Chrome/Firefox.
    *   Identifiez les sélecteurs les plus uniques et les moins susceptibles de changer. Privilégiez les `[aria-label]`, les ID, ou les attributs `data-*` par rapport aux classes CSS génériques (`.div-a23bc`).
    *   Créez un script de validation (similaire à `validation/aistudio_selector_validator.js`) pour tester vos sélecteurs directement dans la console.

3.  **Valider la Stratégie d'Extraction :**
    *   **Scénario A (Idéal) :** Utilisez la **Phase 1 du Guide d'Investigation** pour chercher si le contenu de la conversation est dans un objet JavaScript global (`window.appState`, etc.). Si oui, c'est la méthode à privilégier.
    *   **Scénario B (Le plus courant) :** Si les données ne sont pas dans un objet global, adoptez la stratégie **"Partir du Fiable"** :
        1.  Trouvez un bouton unique et stable sur la réponse finalisée (ex: "Copier", "Modifier", "Régénérer").
        2.  Utilisez ce bouton comme point d'ancrage.
        3.  À partir de ce bouton, utilisez `.closest()` pour remonter au conteneur principal du message.
        4.  Une fois le conteneur trouvé, utilisez `.querySelector()` pour trouver l'élément contenant le texte de la réponse.
        5.  Validez cette séquence dans votre script de validation.

#### Phase 2 : Implémentation de la Logique (TypeScript)

1.  **Créer le Fichier du Chatbot :** Créez un nouveau fichier dans `ts_src/chatbots/`, par exemple `chatgpt.ts`.
2.  **Implémenter l'Interface `Chatbot` :** Remplissez les trois fonctions requises en utilisant les sélecteurs et la stratégie validés à l'étape précédente.
    *   `waitForReady()`: Attend un élément qui n'apparaît qu'une fois la page entièrement chargée.
    *   `sendPrompt(prompt)`: Implémente la séquence : trouver le champ, le remplir, trouver le bouton, cliquer.
    *   `extractResponse()`: Implémente la stratégie d'extraction validée. **Utilisez la logique de "blindage"** pour séparer l'extraction de valeur des actions de nettoyage (comme fermer un mode édition) avec des `try...catch` permissifs.

3.  **Ajouter des Délais Stratégiques :** Incorporez des délais très courts (50-100ms) après des actions qui modifient le DOM (comme un clic qui fait apparaître un `textarea`) pour laisser le temps au framework de la page de se stabiliser.

4.  **Mettre à jour `automation_engine.ts` :** Ajoutez le nouveau provider à la liste `SUPPORTED_SITES`.

#### Phase 3 : Orchestration et Communication (Dart)

1.  **Utiliser `callAsyncJavaScript` pour la Stabilité :** C'est la leçon finale et la plus importante. Pour appeler une fonction `async` de votre script JS et attendre son résultat, **n'utilisez pas `evaluateJavascript` avec des `Promise`s manuelles et des délais.** Utilisez `callAsyncJavaScript`.

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

2.  **Gestion d'Erreur Tolérante :** Lors de l'implémentation de `extractAndReturnToHub` pour le nouveau provider, adoptez la structure qui priorise le résultat :
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

3.  **Intégrer le Déclenchement de l'Observateur :** Si le nouveau provider nécessite une attente après l'envoi du prompt, réutilisez le système d'observateur :
    *   Dans `conversation_provider.dart`, après `bridge.startAutomation()`, passez à l'état `.observing()` et appelez `bridge.startResponseObserver()`.
    *   Dans le script JS (`automation_engine.ts`), adaptez la logique de `checkUIState` pour détecter l'indicateur de fin de réponse du nouveau provider (par exemple, l'apparition d'un bouton "Copier").

#### Phase 4 : Débogage Final

1.  **Utiliser les Logs JS :** Gardez les logs JS (`console.log`) sur les étapes clés pendant le développement. Le log `console.log('Target element:', element.outerHTML)` est particulièrement puissant.
2.  **Utiliser l'Inspecteur de DOM :** Si une extraction échoue, utilisez le bouton "Inspect DOM" pour obtenir une "photographie" de l'état de la page au moment de l'échec et comprendre pourquoi les sélecteurs ne correspondent pas.