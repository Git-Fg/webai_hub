# Blueprint V2.0 : Hub d'IA Hybride (Mobile)

**Document V2.0**

## 1. Vision & Principes Fondamentaux

Ce document définit l'architecture et les logiques d'une application mobile conçue pour centraliser l'accès aux interfaces utilisateur Web (WebUI) des services d'IA. L'objectif est de fournir un "Hub" centralisé qui assiste l'utilisateur en automatisant les tâches répétitives (envoi de prompts, extraction de réponses) tout en conservant la transparence et le contrôle manuel.

### 1.1. Philosophie (L'Esprit "Assister, ne pas cacher")

* **Principe 1 : Assister, ne pas cacher.** L'application est un "assistant" ou "connecteur", et non un "bot" automatisé. L'objectif est de reproduire l'action d'un "copier-coller" intelligent (injection de prompt, extraction de réponse) et non de masquer l'interface web du fournisseur de services. L'application n'automatise que le démarrage de nouvelles conversations.

### 1.2. Transparence Totale (Le "Marionnettiste")

* **Principe 2 : L'utilisateur voit toujours ce que fait l'application.** Toute automatisation (injection de prompt, clic de bouton) s'exécute de manière visible, par-dessus la `WebView` du fournisseur. Cette approche "marionnettiste" permet à l'utilisateur de suivre le processus et de renforcer sa confiance, au lieu d'interagir avec une "boîte noire" opaque.

### 1.3. Robustesse (Conception Anti-Fragile)

* **Principe 3 : L'échec d'une automatisation n'est pas fatal.** Le cas d'échec le plus courant (un CAPTCHA, une demande de connexion, ou un changement de sélecteur CSS) est traité comme un *workflow nominal*. L'application est conçue pour détecter cet échec, notifier l'utilisateur, et lui **rendre le contrôle manuel** sur la `WebView`. L'utilisateur peut alors résoudre le problème (ex: se connecter) et reprendre le processus.

### 1.4. Confidentialité (Local-First)

* **Principe 4 : Confidentialité avant tout.** L'application fonctionne à 100% sur l'appareil local. Aucune conversation, ni du Hub, ni des WebViews, n'est envoyée ou stockée sur un serveur tiers appartenant à l'application. Tout reste sur l'appareil, sous le contrôle de l'utilisateur.

### 1.5. Projet de Référence (Inspiration CWC)

* Ce blueprint s'inspire fortement du projet open-source de référence **"Code Web Chat" (CWC)**, une extension pour IDE qui connecte un éditeur de code à des chatbots Web. Nous adoptons sa philosophie et ses logiques d'interaction DOM (Document Object Model) pour le formatage des prompts et l'identification des éléments de page, tout en modernisant l'implémentation technique.

## 2. Architecture & Stack Technique

### 2.1. Stack Technique Prescrite

Pour garantir la modernité, la performance et la maintenabilité, la stack technique suivante est prescrite :

* **Gestion d'état :** **Riverpod**. Sélectionné pour sa modernité, sa "type-safety" au compile-time et son indépendance du `BuildContext`, ce qui simplifie la gestion de l'état global et des interactions complexes entre les onglets.
* **WebView :** **`flutter_inappwebview`**. Sélectionné de préférence à la bibliothèque officielle `webview_flutter`. La raison de ce choix est la puissance supérieure de son pont JavaScript, sa gestion avancée des popups et des certificats SSL, et sa capacité à gérer les interactions complexes requises par notre Contrat d'API (Section 7).
* **Base de Données (Hub) :** **SQLite**. Sélectionné pour sa robustesse et sa compatibilité native pour le stockage local de l'historique des conversations natives de l'onglet "Hub".
* **UI du Hub (Tab 1) :** **Flutter natif**. Implémentation custom pour un contrôle total de l'interface de chat native avec Material 3.
* **Réseau (Maintenance) :** **HTTP**. Package standard suffisant pour la récupération de la configuration distante des sélecteurs (voir Section 10.3).

### 2.2. Template de Base Obligatoire

* **Clarification :** L'approche "Clean Architecture" générique est rejetée **uniquement dans le contexte des templates de démarrage surdimensionnés** (ex: `flutter_clean_architecture`). Cependant, la **philosophie de séparation des modules** est pleinement adoptée avec la structure `lib/features/...` et `lib/core/...`, qui suit les principes d'organisation modulaire et de séparation des préoccupations.
* **Adoption :** Le point de départ du projet **doit** être le template **"Multi-WebView Tab Manager"** (disponible dans les exemples `flutter_inappwebview`).
* **Justification :** Ce template résout nativement le défi technique N°1 du projet : la **persistance des sessions et des cookies sur plusieurs onglets `WebView`**. Utiliser ce template comme base permet à l'équipe de se concentrer sur la logique métier (le workflow "Assister & Valider") plutôt que sur l'infrastructure de bas niveau des `WebView`.

### 2.3. Structure Principale

* L'architecture de l'application est une `TabBarView` (ou équivalent) **fixe à 5 onglets**.
* **Plateforme Cible :** Mobile (iOS et Android).

### 2.4. Onglet 1 : "Hub" (Natif)

* **UI :** Une interface de chat 100% native, construite avec Flutter natif.
* **Composants :**
  * Liste des conversations (bulles de chat).
  * Champ de saisie de texte unique.
  * Sélecteur de "Provider" (AI Studio, Qwen, Z-ai, Kimi).
  * Bouton "Options" (⚙️) pour configurer le provider sélectionné.
  * Boutons "Contexte" (📎, 📋) pour l'ajout de presse-papiers ou de fichiers.
* **État :** Affiche l'historique de la conversation native (géré par SQLite) et l'état de connexion de chaque provider (géré par Riverpod).

### 2.5. Onglets 2-5 : "Providers" (`WebView`)

* **UI :** Une `WebView` (utilisant `flutter_inappwebview`) visible et unique par onglet.
* **Persistance :** Les sessions `WebView` (cookies, stockage local) sont persistantes, comme défini par le template de base (Section 2.2).
* **Onglets (MVP) :**
  * **Tab 2: "AI Studio"** (URL: `https://aistudio.google.com/prompts/new_chat`)
  * **Tab 3: "Qwen"** (URL: `https://chat.qwen.ai/`)
  * **Tab 4: "Z-ai"** (URL: `https://chat.z.ai/`)
  * **Tab 5: "Kimi"** (URL: `https://www.kimi.com/`)

### 2.6. L'Overlay "Compagnon" (Natif)

* **UI :** Un composant d'interface natif (ex: un bandeau flottant) qui est superposé *uniquement* sur les onglets `WebView` (2-5) et *seulement* pendant une automatisation active (Phases 1-3).
* **Composants de l'UI :**
    1. Indicateur de statut (texte, ex: `Génération en cours...`).
    2. Bouton `[ ✅ Valider et envoyer au Hub ]`.
    3. Bouton `[ ❌ Annuler ]`.

## 3. Expérience Utilisateur & Gestion de l'État

### 3.1. Flux de Premier Lancement (Onboarding)

* L'application s'ouvre sur l'onglet "Hub", qui affiche un écran de bienvenue ou un "état vide".
* L'interface guide (visuellement ou textuellement) l'utilisateur pour qu'il visite **manuellement** chaque onglet `WebView` (2-5) afin de s'y **connecter**.

### 3.2. Gestion de l'État de Connexion

* Le "Hub" (Tab 1) doit refléter l'état de connexion de chaque service (ex: "Kimi: ✅ Prêt", "Qwen: ❌ Connexion requise"). L'automatisation depuis le Hub n'est activée que pour les services "Prêts".
* **Logique de Vérification de l'État (`Automation.checkStatus()`):**
  * L'état "Prêt" est déterminé par une fonction (`Automation.checkStatus()`, voir 7.2) appelée au démarrage et lors du changement d'onglet.
  * **Succès (Prêt ✅) :** Le script JS injecté trouve le sélecteur de la zone de saisie de prompt (ex: un `textarea`, voir Section 8).
  * **Échec (Connexion ❌) :** Le script JS ne trouve pas la zone de saisie, mais trouve un sélecteur de page de login (ex: `input[type="password"]` ou `h1` contenant "Sign In").

## 4. Workflow "Assister & Valider" (Le Cœur Dynamique)

C'est le flux principal d'interaction, combinant automatisation et contrôle manuel.

### 4.1. Phase 1 : L'Envoi (Assisté)

1. **Utilisateur :** Sur l'onglet **"Hub"**, sélectionne "Kimi", configure les "Options" (⚙️), ajoute du "Contexte" (ex: un fichier) et envoie le prompt.
2. **App (Action) :** L'application formate le prompt en utilisant la structure définie en Section 5.3.
3. **Hub (UI) :** Affiche une bulle de chat `[Envoi vers Kimi...]`.
4. **App (Action) :** Bascule **automatiquement** l'utilisateur vers l'onglet **"Kimi" (Tab 5)**.
5. **Overlay (UI) :** L'overlay "Compagnon" apparaît sur Tab 5, affichant `[Automatisation en cours...]` (Bouton "Annuler" visible).
6. **App (Action) :** Exécute le script `Automation.start(promptFormaté, options)` dans la `WebView` Kimi.

### 4.2. Phase 2 : L'Observation (L'Attente)

1. **JS (Action) :** Le script `Automation.start` s'exécute dans la `WebView` :
   a.  Attend que la page soit prête (logique `wait_until_ready`, voir Section 6.1).
   b.  Applique les configurations (logique `set_options` / `set_model`, si `options` fournies, voir Section 5.1).
   c.  Injecte le `promptFormaté` dans le `textarea` et clique sur le bouton d'envoi (logique `enter_message_and_send`).
2. **JS (Observation) :** Un `MutationObserver` (logique `observe_for_responses`) surveille le DOM.
3. **JS (Détection) :** L'observateur attend que la génération de la réponse soit terminée (en se basant sur la *disparition* du sélecteur `is_generating` de Kimi, voir Section 8.1).
4. **JS (Callback) :** Le script envoie l'événement `Bridge.onGenerationComplete()` à la couche native.

### 4.3. Phase 3 : Le Raffinage (Contrôle Manuel)

1. **App (Réaction) :** L'application native reçoit `Bridge.onGenerationComplete()`.
2. **Overlay (UI) :** L'overlay "Compagnon" change son état : `[Prêt pour raffinage]` et affiche le bouton `[ ✅ Valider et envoyer au Hub ]`.
3. **Utilisateur (Action) :** L'utilisateur est maintenant libre. Il peut interagir manuellement avec la `WebView` Kimi (poser des questions de suivi, "raccourcis ce texte", etc.) autant de fois qu'il le souhaite.

### 4.4. Phase 4 : La Validation (L'Extraction)

1. **Utilisateur (Action) :** Une fois satisfait de la réponse affichée dans la `WebView`, il clique sur le bouton natif `[ ✅ Valider et envoyer au Hub ]`.
2. **App (Action) :** Exécute le script `Extraction.getFinalResponse()` dans la `WebView`.
3. **JS (Action) :** Le script localise la **dernière bulle de réponse de l'assistant** (voir Section 8.2), en extrait le contenu (HTML/texte), et envoie le résultat via `Bridge.onExtractionResult(htmlContent)`.
4. **App (Réaction) :** L'application native reçoit le contenu, bascule **automatiquement** l'utilisateur vers l'onglet **"Hub" (Tab 1)**, et remplace le message `[Envoi vers Kimi...]` par la réponse finale et validée.

## 5. Gestion du Contexte & Formatage des Prompts

L'intelligence de l'application réside dans le formatage des prompts, directement inspiré de CWC.

### 5.1. Logique de Configuration (via "Options" ⚙️)

* Le bouton "Options" (⚙️) dans le Hub doit afficher les configurations disponibles pour le provider sélectionné (ex: "Modèle", "Options de chat").
* Ces choix sont passés dans l'objet `optionsJSON` à `Automation.start` (Phase 1) et exécutés (via la logique `set_options` / `set_model` CWC) avant l'injection du prompt.

### 5.2. Types de Contexte (MVP V1.0)

* Pour la version 1.0, l'ajout de contexte (via les boutons "Contexte" 📎) est limité au **texte uniquement** (presse-papiers, fichiers .txt, .md, .js, .py, .html).
* Les fichiers binaires (images, PDF) ne sont **pas** supportés dans ce flux, car leur gestion est complexe et spécifique à chaque provider. L'utilisateur peut cependant les utiliser manuellement dans les onglets `WebView`.

### 5.3. Formatage du Prompt (Structure CWC)

* Le `promptFormaté` injecté (Phase 1) doit suivre la structure CWC pour une précision maximale, incluant la **répétition** de l'instruction après le contexte :

```text

[PROMPT UTILISATEUR]
\<system\>
[INSTRUCTIONS SYSTÈME (ex: "Réponds en français")]
\</system\>

[CONTEXTE FORMATÉ (voir 5.4)]

[PROMPT UTILISATEUR (RÉPÉTÉ)]
\<system\>
[INSTRUCTIONS SYSTÈME (RÉPÉTÉES)]
\</system\>

```

### 5.4. Formatage des Fichiers (Contexte)

* Lorsque l'utilisateur ajoute du contexte, il doit être formaté en utilisant les balises XML de CWC. L'utilisation de `<![CDATA[...]]>` est essentielle pour que le contenu du fichier (qui peut contenir du XML/HTML) n'invalide pas le formatage XML du prompt lui-même.

```xml
<files>
  <file path="nom_du_fichier.txt">
  <![CDATA[
  ...Contenu du fichier ou du presse-papiers...
  ]]>
  </file>
</files>
```

## 6\. Logiques d'Interaction DOM (Moteur JavaScript)

Le pont JS injecté doit implémenter les logiques suivantes, basées sur les scripts CWC :

### 6.1. Logiques CWC (`wait_until_ready`, `set_options`, `enter_message_and_send`, `observe_for_responses`)

* Description des actions :
  * **`wait_until_ready` :** Attend qu'un sélecteur (ex: `textarea`) soit présent avant de continuer.
  * **`set_options` :** Simule les clics pour configurer l'interface web (ex: changer de modèle).
  * **`enter_message_and_send` :** Insère le `promptFormaté` dans le `textarea` et clique sur le bouton d'envoi.
  * **`observe_for_responses` :** Utilise un `MutationObserver` pour surveiller le DOM et détecter la *présence* du sélecteur `is_generating`. La fin est détectée lorsque ce sélecteur *disparaît*.

### 6.2. Logique d'Extraction (`get_final_assistant_response`)

* Description de l'action :
  * **`get_final_assistant_response` :** Trouve *tous* les éléments correspondant au `assistant_response_selector`, prend le **dernier** de la liste, et extrait son contenu.

### 6.3. Logique de "Défense en Profondeur"

* **Stratégie :** Les logiques JS (6.1, 6.2) ne doivent pas utiliser un sélecteur unique (chaîne). Elles doivent accepter un **tableau de sélecteurs (`List<String>`)** (défini en 8.1) et **itérer** sur ce tableau jusqu'à ce qu'un sélecteur fonctionnel soit trouvé. Cela renforce drastiquement la robustesse de l'application face aux mises à jour mineures du DOM.

## 7\. Contrat d'API (Pont Natif \<-\> JavaScript)

### 7.1. Implémentation du Pont JS

* Le pont JS (ex: `bridge.js`) **doit** être implémenté sous la forme d'une **classe `async/await`** (ex: `HubBridge`). Cette approche moderne remplace l'implémentation `Promise.then` datée du projet CWC de référence.
* La classe **doit** inclure une **file d'attente de messages (`messageQueue`)**. Cela garantit que les appels `postMessage` (JS vers Natif) survenant avant que le canal `flutter_inappwebview` ne soit pleinement initialisé ne sont pas perdus, mais mis en file d'attente et traités dès que le pont est prêt.

### 7.2. Fonctions JS (Appelées par le Natif)

* `Automation.start(promptFormaté, optionsJSON)`
  * **Description :** Déclenche les Phases 1 (Injection) et 2 (Observation).
  * **`optionsJSON` :** Un objet JSON contenant les configurations (ex: `{ "model": "opus" }`).
* `Automation.cancel()`
  * **Description :** Annule toute `MutationObserver` ou boucle d'attente JS en cours.
* `Extraction.getFinalResponse()`
  * **Description :** Déclenche la Phase 4 (Validation).
* `Automation.checkStatus()`
  * **Description :** Déclenche la vérification d'état non-intrusive (voir Section 3.2).

### 7.3. Événements JS (Envoyés au Natif)

* Les messages doivent être une **chaîne JSON sérialisée** unique.
* `[BridgeName].postMessage(JSON.stringify({ event: 'onStatusResult', payload: { status: 'ready' | 'login' } }))`
* `[BridgeName].postMessage(JSON.stringify({ event: 'onInjectionFailed', payload: { error: 'Raison de l'échec (ex: Sélecteur non trouvé)' } }))`
* `[BridgeName].postMessage(JSON.stringify({ event: 'onGenerationComplete' }))`
* `[BridgeName].postMessage(JSON.stringify({ event: 'onExtractionResult', payload: { content: '...html ou texte extrait...' } }))`

## 8\. Dictionnaire des Sélecteurs

### 8.1. Tableau des Sélecteurs (MVP)

* **Stratégie :** Les colonnes de sélecteurs sont de type **`List<String>` (tableau)** pour implémenter la "Défense en Profondeur" (Section 6.3). Le script JS essaiera le premier sélecteur ; s'il échoue, il essaiera le suivant.

| Provider | `wait_until_ready` (Attente) | `enter_message_and_send` (Clic) | `is_generating` (Génération) | `assistant_response_selector` (Extraction) | `login_check` (Statut) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **AI Studio** | [`'input-area'`] | [`'send-button[variant="primary"]'`] | [`'mat-icon[data-mat-icon-name="stop"]'`] | [`'response-container'`] | [`'input[type="password"]'`] |
| **Qwen** | [`'textarea'`] | [`'button[class*="Button_button_"][class*="Button_primary_"]'`] | [`'button[class*="Button_danger_"]'`] | [`'div[class*="Message_messageItem_"]'`] | [`'input[type="password"]'`] |
| **Z-ai** | [`'textarea'`] | [`'button[class*="ChatInput_sendButton_"]'`] | [`'button[aria-label="Stop generating"]'`] | [`'div[class*="ConversationItem_conversationItem_"]'`] | [`'input[type="password"]'`] |
| **Kimi** | [`'textarea[placeholder*="Kimi"]'`] | [`'button > svg[class*="Icon_icon_"]'`, `'button[data-testid="send-button"]'`] | [`'div[class*="ChatInterlude_stopBtn_"]'`] | [`'div[data-message-role="assistant"]'`] | [`'input[type="password"]'`] |

### 8.2. Logique d'Extraction (Précision Phase 4)

* Pour garantir que la réponse correcte est extraite, le script `Extraction.getFinalResponse()` **doit** :
    1. Utiliser le tableau `assistant_response_selector` (ex: `['div[data-message-role="assistant"]']` pour Kimi).
    2. Itérer sur ce tableau pour trouver un sélecteur valide.
    3. Exécuter `document.querySelectorAll(...)` avec le sélecteur valide.
    4. Prendre le **dernier** élément (`Node`) de la `NodeList` résultante.
    5. Extraire son contenu (`innerHTML` pour conserver le formatage).

### 8.3. Internationalisation (i18n) et Fragilité des Sélecteurs

* **Avertissement :** Les sélecteurs basés sur du texte (ex: `textarea[placeholder*="Kimi"]` ou `button[aria-label="Stop generating"]`) sont extrêmement fragiles et sensibles à la langue de l'interface.
* **Stratégie :** La maintenance (Section 10.3) doit prioriser activement le remplacement de ces sélecteurs par des attributs `data-testid`, `aria-label` (stables) ou des classes structurelles non-stylisées.

## 9\. Gestion des Erreurs & Cycle de Vie

### 9.1. Cycle de Vie de l'Overlay "Compagnon"

* **État 1 (Inactif) :** Caché.
* **État 2 (En cours) :** Visible pendant les Phases 1 & 2. Affiche `[Automatisation en cours...]`. Seul le bouton "Annuler" est visible/actif.
* **État 3 (En attente) :** Visible pendant la Phase 3. Affiche `[Prêt pour raffinage]`. Les boutons "Valider" et "Annuler" sont visibles/actifs.

### 9.2. Gestion des Erreurs (Robustesse)

* **Cas : Échec d'injection (Login/CAPTCHA)**
    1. `Automation.start` échoue (ex: `textarea` non trouvé après avoir itéré sur le tableau de sélecteurs).
    2. Le script JS envoie `Bridge.onInjectionFailed("Sélecteur 'textarea' non trouvé")`.
    3. L'application native **ne retourne pas** au Hub.
    4. L'overlay "Compagnon" (État 2) affiche l'erreur : `[ ⚠️ Automatisation échouée. Veuillez vous connecter ou résoudre le CAPTCHA manuellement. ]` puis se cache (État 1).
    5. Le message dans le Hub (Tab 1) est mis à jour de `[Envoi...]` à `[Échec de l'envoi]`.
* **Cas : Annulation Utilisateur (Clic Bouton)**
    1. L'utilisateur clique sur "Annuler" (pendant l'État 2 ou 3).
    2. L'application exécute `Automation.cancel()` (pour arrêter tout `MutationObserver` ou boucle JS).
    3. L'overlay "Compagnon" est caché (État 1).
    4. L'application **ne retourne pas** au Hub.
    5. Le message dans le Hub est mis à jour : `[Annulé par l'utilisateur]`.
* **Cas : Annulation (Navigation Manuelle)**
  * Si l'utilisateur quitte manuellement l'onglet `WebView` (ex: Kimi) pendant que l'automatisation est en État 2 ou 3, cela doit être traité comme une "Annulation" (voir 9.2, Cas : Annulation Utilisateur).

## 10\. Persistance, Sécurité & Maintenance

### 10.1. Persistance des Données

* **Hub (Natif) :** L'historique de l'onglet "Hub" (Tab 1) est stocké dans une base de données **SQLite** sur l'appareil.
* **`WebView` (Web) :** Les `WebView` (Tabs 2-5) doivent avoir la **persistance des cookies et des sessions** activée (ce qui est géré par le template de base `Multi-WebView Tab Manager`).

### 10.2. Sécurité & Confidentialité

* **Isolation :** La couche native (le "Hub") **n'a pas** le droit de lire les cookies, le `localStorage`, ou les identifiants des `WebView`. L'interaction est *strictement* limitée au Contrat d'API (Section 7).
* **Clés API (Fonctionnalité Future) :** Si, à l'avenir, des API directes sont ajoutées (similaires aux "API Tools" de CWC), leurs clés *doivent* être stockées dans le **stockage sécurisé et chiffré** de l'appareil (Keychain/Keystore) et jamais en clair.
* **Aucune Collecte :** Le blueprint affirme qu'aucune donnée de conversation n'est collectée par l'application elle-même.

### 10.3. Stratégie de Maintenance des Sélecteurs

* **Problème :** Les sélecteurs DOM (Section 8) sont le point de défaillance le plus probable.
* **Stratégie :** Les sélecteurs ne seront **pas codés en dur** dans l'application.
    1. Au premier démarrage, l'application récupérera (via **HTTP**) un fichier de configuration JSON (le "Dictionnaire des Sélecteurs") depuis une **URL de maintenance distante** (ex: un bucket GCS, GitHub Pages).
    2. Ce fichier JSON sera mis en cache localement sur l'appareil.
    3. L'application tentera de rafraîchir ce cache périodiquement (ex: une fois par jour).
    4. Toute la logique JS (Section 6) utilisera les sélecteurs de ce fichier JSON en cache.
    5. Ce fichier JSON *doit* suivre la structure de "Défense en Profondeur" (Section 8.1), utilisant des **tableaux de sélecteurs de repli** (`List<String>`) pour chaque action.
* **Bénéfice :** Permet à l'équipe de maintenance de mettre à jour les sélecteurs (ex: si Kimi change son DOM) sans avoir à redéployer une nouvelle version de l'application sur les stores.

## **11. Stratégie de Tests & Assurance Qualité**

### **11.1. Philosophie de Testing**

L'approche de testing privilégie la **simplicité et l'efficacité** avec une hiérarchie claire :

1. **🥇 Objets Réels** (toujours préférable)
   * Modèles simples ✅
   * Providers avec ProviderContainer ✅

2. **🥈 Riverpod Overrides** (pour état/logique métier)
   * Tests widget ✅
   * Remplacement de providers ✅

3. **🥉 Fakes** (pour dépendances)
   * JavaScriptBridge ✅
   * Implémentations simplifiées ✅

4. **⚠️ Mocks** (dernier recours uniquement)
   * Seulement si Fakes ne suffisent pas
   * Dépendances externes très complexes

**Principe clé** : Moins de mocks = Tests plus simples = Maintenance plus facile

### **11.2. Stack Technique de Tests**

**Déjà Utilisés (Correct) :**
* ✅ `flutter_test` - Framework de test standard
* ✅ `ProviderContainer` - Pour tester Riverpod isolément
* ✅ Objets réels pour les modèles

**Patterns de Test :**
* **Arrange-Act-Assert** : Structure claire pour chaque test
* **Edge cases** : Tests pour cas limites et erreurs
* **State transitions** : Tests complets des transitions d'état
* **Isolation** : Chaque test est indépendant

### **11.3. État Actuel des Tests**

**✅ Tests Unitaires Complets (Phase 1 complétée) :**

1. **Tests des modèles** (bien couverts)
   * `AIProvider` - Tests complets pour enum, URLs, conversions
   * `AutomationState` - Tests pour état, transitions, propriétés
   * `Conversation` - Tests pour création, sérialisation, messages
   * `SelectorDictionary` - Tests pour validation, sélecteurs, conversion JS

2. **Tests des Providers Riverpod** ✅
   * `conversation_provider_test.dart` (18 tests)
   * `automation_provider_test.dart` (27 tests)
   * `provider_status_provider_test.dart` (13 tests)

3. **Tests des Utilitaires** ✅
   * `prompt_formatter_test.dart` (30 tests)

**Total : 109 tests unitaires**

### **11.4. Techniques de Testing Modernes**

#### **Tests de Providers Riverpod - SANS MOCKS ✅**

```dart
final container = ProviderContainer();
final notifier = container.read(conversationProvider.notifier);
// Tests...
container.dispose();
```

**Pourquoi c'est optimal** : Utilise les objets réels avec ProviderContainer, pas de complexité de mocks.

#### **Tests Widget avec Riverpod Overrides ✅**

```dart
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      conversationProvider.overrideWith((ref) {
        return ConversationNotifier(ref)
          ..startNewConversation(AIProvider.aistudio);
      }),
    ],
    child: HubScreen(),
  ),
);
```

**Pourquoi c'est optimal** : Plus simple que les mocks, type-safe, intégré à Riverpod.

#### **Tests d'Intégration avec Fakes ✅**

```dart
class FakeJavaScriptBridge implements JavaScriptBridge {
  final List<String> _calls = [];

  @override
  Future<void> startAutomation(String prompt) async {
    _calls.add('startAutomation:$prompt');
  }

  @override
  Future<String?> extractResponse() async {
    return 'Fake response';
  }

  List<String> get calls => _calls;
}
```

**Pourquoi c'est optimal** : Plus maintenable que les mocks, comportement réel simplifié.

### **11.5. Métriques de Qualité**

**Tests Devraient Être :**
* **Rapides** : Exécution < 1 seconde pour tests unitaires
* **Indépendants** : Pas de dépendances entre tests
* **Répétables** : Même résultat à chaque exécution
* **Auto-validants** : Pass/Fail clair
* **Opportunément écrits** : Écrits au bon moment (TDD quand approprié)

**Objectifs :**
* **Couverture de code** : > 80% pour la logique métier
* **Réduction des tests manuels** : < 10% des fonctionnalités nécessitent tests manuels
* **Détection précoce** : > 90% des bugs détectés avant production

### **11.6. Impact sur les Tests Manuels**

**Réduction estimée : ~60-70%**

* ✅ **Logique métier** : Détectée automatiquement par les tests unitaires
* ✅ **Formatage de prompts** : Couvert par 30 tests dédiés
* ✅ **Gestion d'état** : Toutes les transitions testées automatiquement

### **11.7. Plan d'Implémentation**

#### **✅ Phase 1 - CRITIQUE (Complétée)**

1. ✅ Tests des providers Riverpod (58 tests)
2. ✅ Tests des utilitaires (30 tests)

#### **⏳ Phase 2 - IMPORTANT (Recommandé)**

3. **Tests widget plus complets**
   * `test/widget/hub_screen_test.dart`
   * `test/widget/prompt_input_test.dart`
   * `test/widget/provider_selector_test.dart`
   * Utiliser Riverpod overrides (pas de mocks)

4. **Tests d'intégration avec Fakes**
   * `test/integration/workflow_orchestrator_test.dart`
   * Utiliser `FakeJavaScriptBridge` (pas de mocks complexes)

#### **🔄 Phase 3 - OPTIONNEL**

5. **Tests E2E** (avec `integration_test` package)
   * Tests sur device/emulator
   * Tests avec WebViews réelles

### **11.8. Commandes de Tests**

```bash
# Exécuter tous les tests
flutter test

# Tests avec couverture
flutter test --coverage

# Tests spécifiques
flutter test test/unit/provider_tests/
flutter test test/unit/conversation_test.dart
```

---

**Statut** : Phase 1 complétée ✅ | Phase 2 recommandée ⏳
