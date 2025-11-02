# **Blueprint du MVP : AI Hybrid Hub (Version 1.0)**

## **1. Objectif et Philosophie de ce Document**

**Version :** MVP-1.0  
**Philosophie :** "Prouver la Boucle d'Automatisation"  
**But de ce Document :** Fournir une spécification technique complète et autosuffisante pour la construction d'un Produit Minimum Viable (MVP). L'objectif unique de ce MVP est de valider la faisabilité technique du workflow "Assister & Valider" sur un unique fournisseur d'IA. Ce blueprint privilégie la **vitesse d'implémentation et la clarté fonctionnelle** au détriment de la maintenabilité à long terme, de la performance et de la robustesse multi-fournisseurs.

## **2. Objectif Principal du MVP**

Valider de bout en bout le workflow d'automatisation en 4 phases (Envoi, Observation, Raffinage, Validation) en utilisant une interface native Flutter pour piloter une `WebView` affichant l'interface web de **Google AI Studio**.

## **3. Stack Technique et Versions Précises**

L'application **DOIT** utiliser les versions suivantes pour garantir la reproductibilité.

| Composant | Technologie | Version Précise | Rôle dans le MVP |
| :--- | :--- | :--- | :--- |
| **Framework** | Flutter / Dart | `Flutter >= 3.19.0`, `Dart >= 3.3.0` | Socle de l'application. |
| **Gestion d'État** | `flutter_riverpod` + `riverpod_annotation` | `^2.5.1` / `^2.3.5` | Gestion en mémoire de l'état de la conversation. |
| **Modélisation** | `freezed_annotation` | `^2.4.1` | Création des modèles d'état immuables pour Riverpod. |
| **Vue Web** | `flutter_inappwebview` | `^6.0.0` | **Composant critique.** Fournit la `WebView` et le pont JavaScript. |
| **Qualité du Code** | `flutter_lints` | `^3.0.0` | Analyse statique de base. |
| **Génération Code** | `build_runner`, `riverpod_generator`, `freezed` | `^2.4.9` / `^2.4.0` / `^2.5.2` | Automatisation de la création des providers et modèles. |

### **Configuration `pubspec.yaml` Requise**

```yaml
environment:
  sdk: '>=3.3.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5
  freezed_annotation: ^2.4.1
  flutter_inappwebview: ^6.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.9
  riverpod_generator: ^2.4.0
  freezed: ^2.5.2
  flutter_lints: ^3.0.0
```

## **4. Fournisseur Cible & Configuration "Codée en Dur"**

*   **Fournisseur Cible : Google AI Studio**
    *   **URL :** `https://aistudio.google.com/prompts/new_chat`
    *   **Justification :** Ses sélecteurs semblent basés sur des noms d'éléments personnalisés et des attributs stables, ce qui le rend plus résistant aux changements mineurs et donc idéal pour un MVP avec des sélecteurs codés en dur.

*   **Sélecteurs CSS (à coder en dur dans le fichier TypeScript) :**
    ```typescript
    // Fichier: lib/js/automation_engine.ts
    
    // Sélecteur pour la zone de saisie du prompt
    const PROMPT_INPUT_SELECTOR = "input-area";
    
    // Sélecteur pour le bouton d'envoi
    const SEND_BUTTON_SELECTOR = 'send-button[variant="primary"]';
    
    // Sélecteur pour le conteneur de la dernière réponse de l'assistant
    const RESPONSE_CONTAINER_SELECTOR = "response-container";
    
    // Sélecteur pour l'indicateur de génération (ex: un spinner)
    const GENERATION_INDICATOR_SELECTOR = 'mat-icon[data-mat-icon-name="stop"]';
    ```

## **5. Architecture de l'Application (Simplifiée)**

### **5.1. Structure des Fichiers**

```
lib/
├── main.dart                 # Point d'entrée avec ProviderScope et TabBarView
├── features/
│   ├── hub/
│   │   ├── providers/
│   │   │   └── conversation_provider.dart  # Notifier pour gérer la conversation en mémoire
│   │   └── widgets/
│   │       ├── hub_screen.dart             # UI du chat natif
│   │       └── chat_bubble.dart            # Widget pour les bulles de message
│   └── webview/
│       ├── widgets/
│       │   └── ai_webview_screen.dart      # Contient l'InAppWebView
│       └── bridge/
│           └── javascript_bridge.dart      # Service Dart pour appeler le TS
└── js/
    └── automation_engine.ts      # Le moteur d'automatisation (logique codée en dur)
```

### **5.2. UI/UX et État**

*   **Navigation :** Une `TabBarView` fixe avec 2 onglets : "Hub" et "AI Studio".
*   **Hub UI :** Un `ListView` pour les bulles de conversation. Un `TextField` et un `IconButton` pour l'envoi.
*   **State Management :** Un unique `NotifierProvider` (`conversationProvider`) gère une liste d'objets `Message` en mémoire. **Aucune base de données.** L'état est réinitialisé à chaque fermeture de l'application.

### **5.3. WebView & Session**

*   L'onglet "AI Studio" contient un `InAppWebView` qui charge l'URL cible.
*   **Gestion de Session :** L'utilisateur **DOIT** se connecter manuellement à son compte Google dans la `WebView` au premier usage. La persistance de la session est assurée par le comportement par défaut de la `WebView` (cookies). Aucune gestion de session avancée n'est implémentée.

## **6. Contrat du Pont JavaScript (API Dart <-> TypeScript)**

C'est le contrat d'API **critique** qui doit être respecté à la lettre.

*   **Outillage :** Le fichier `automation_engine.ts` est transpilé via **Vite/esbuild** en un bundle unique.
*   **Injection :** Le bundle est injecté via un **`UserScript`** de `flutter_inappwebview` à **`AT_DOCUMENT_START`**.
*   **API Exposée en TypeScript (à appeler depuis Dart) :**
    ```typescript
    // Fonctions globales exposées par le bundle JavaScript

    /**
     * Démarre le workflow d'automatisation.
     * @param prompt Le texte à injecter.
     * @returns Une Promise qui se résout quand l'observation commence, ou est rejetée en cas d'échec.
     */
    function startAutomation(prompt: string): Promise<void>;

    /**
     * Extrait le contenu de la dernière réponse de l'assistant.
     * @returns Une Promise qui se résout avec le texte de la réponse, ou est rejetée en cas d'échec.
     */
    function extractFinalResponse(): Promise<string>;
    ```
*   **API Exposée en Dart (à appeler depuis TypeScript) :**
    Un `JavaScriptHandler` unique est enregistré côté Dart.
    ```dart
    // Dans ai_webview_screen.dart
    controller.addJavaScriptHandler(
      handlerName: 'automationBridge',
      callback: (args) {
        // args[0] est un Map<String, dynamic> représentant l'événement
        final event = args[0];
        // Logique pour gérer les événements 'GENERATION_COMPLETE' ou 'AUTOMATION_FAILED'
      },
    );
    ```

## **7. Logique du Moteur d'Automatisation (TypeScript)**

### **7.1. Implémentation de `startAutomation(prompt)`**

Cette fonction **DOIT** être encapsulée dans un bloc `try/catch`.

1.  **`try` block :**
    a.  Utiliser `await waitForElement(PROMPT_INPUT_SELECTOR)` pour trouver la zone de saisie.
    b.  Y insérer la valeur de `prompt`.
    c.  Utiliser `await waitForElement(SEND_BUTTON_SELECTOR)` pour trouver le bouton d'envoi.
    d.  Le cliquer.
    e.  Démarrer le `MutationObserver` (simplifié) pour surveiller le `GENERATION_INDICATOR_SELECTOR`.
    f.  Une fois que l'indicateur disparaît (ou après un debounce), appeler le handler Dart avec l'événement `GENERATION_COMPLETE`.
2.  **`catch` block (pour toute erreur) :**
    a.  Appeler le handler Dart avec l'événement `AUTOMATION_FAILED`.
    b.  Rejeter la `Promise`.

### **7.2. Implémentation de `extractFinalResponse()`**

Cette fonction **DOIT** être encapsulée dans un bloc `try/catch`.

1.  **`try` block :**
    a.  Utiliser `document.querySelectorAll(RESPONSE_CONTAINER_SELECTOR)` pour obtenir toutes les bulles de réponse.
    b.  Prendre le **dernier** élément de la liste.
    c.  En extraire le `textContent`.
    d.  Retourner (résoudre la `Promise` avec) le texte extrait.
2.  **`catch` block (pour toute erreur) :**
    a.  Appeler le handler Dart avec l'événement `AUTOMATION_FAILED`.
    b.  Rejeter la `Promise` avec un message d'erreur.

## **8. Définition de "Terminé" (MVP Checklist)**

Le MVP est considéré **terminé et validé** lorsque **tous** les points suivants sont fonctionnels :

-   [ ] L'application se compile et se lance sans erreur.
-   [ ] L'utilisateur peut se connecter manuellement à Google AI Studio dans l'onglet `WebView`.
-   [ ] L'envoi d'un message depuis l'onglet "Hub" déclenche l'automatisation.
-   [ ] L'application bascule automatiquement vers l'onglet "AI Studio".
-   [ ] Le prompt est visiblement injecté dans la zone de saisie et la requête est envoyée.
-   [ ] L'overlay compagnon affiche l'état "En cours...".
-   [ ] L'application détecte la fin de la génération de la réponse et met à jour l'overlay à "Prêt pour validation".
-   [ ] Le clic sur le bouton "Valider" de l'overlay déclenche l'extraction.
-   [ ] La réponse extraite est correctement affichée dans une nouvelle bulle de chat dans l'onglet "Hub".
-   [ ] En cas d'échec de l'automatisation (ex: sélecteur cassé), une bulle "Échec" apparaît dans le Hub.