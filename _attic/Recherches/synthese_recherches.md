### **Synthèse des Résultats de la Recherche 1 : Socle Technologique Natif**

#### **Conclusion Exécutive**

La recherche valide sans ambiguïté l'adoption d'un écosystème technologique synergique et fortement basé sur la génération de code. La stack recommandée est une combinaison non-négociable de **Riverpod (avec générateur), Drift, Freezed, et `very_good_analysis`**. Cette architecture est conçue pour déplacer la détection d'erreurs du runtime vers la compilation, éliminant des classes entières de bugs et réduisant drastiquement le code répétitif ("boilerplate").

---

#### **1. Gestion d'État : Riverpod avec `riverpod_generator`**

*   **Validation et Recommandation :** L'adoption de **Riverpod 3.0+ avec `riverpod_generator`** est validée comme unique solution. L'approche est considérée comme un changement de paradigme qui aligne la gestion d'état avec l'exigence de type-safety du projet. L'utilisation de "legacy providers" (ex: `StateNotifierProvider` écrit manuellement) est proscrite.
*   **Bénéfices Quantifiés :**
    *   **Réduction du Boilerplate :** La syntaxe `@riverpod` réduit le code nécessaire par provider de près de 75%.
    *   **Sécurité de Type Statique :** Le générateur unifie l'API, choisit le bon type de provider automatiquement (ex: `FutureProvider` pour une fonction `async`), et permet des paramètres de fonction typés et nommés, contrairement à l'ancienne API `.family`. 95% des erreurs de type sont détectées à la compilation.
    *   **Testabilité :** L'indépendance du `BuildContext` permet des tests unitaires robustes via le `ProviderContainer`, sans avoir à construire l'arbre de widgets.

#### **2. Base de Données Locale : Drift vs. sqflite**

*   **Validation et Recommandation :** **Drift est la seule solution acceptable.** `sqflite` est explicitement rejeté car il est fondamentalement incompatible avec l'exigence de sécurité de type statique.
*   **Analyse Comparative Décisive :**
    *   **Sécurité de Type :** Drift offre une sécurité de type de bout en bout (schéma en Dart, requêtes via un builder typé, résultats sous forme d'objets typés), avec une vérification à la compilation. `sqflite` repose sur des chaînes de caractères (SQL brut) et retourne des `Map<String, dynamic>`, reportant toutes les erreurs de type au runtime.
    *   **Réactivité :** C'est le facteur critique. Drift fournit nativement des requêtes réactives via sa méthode `.watch()`. Cette fonctionnalité crée une synergie parfaite avec les `StreamProvider` de Riverpod, permettant à l'UI de se mettre à jour automatiquement et sans effort lors d'un changement dans la base de données. `sqflite` n'a aucune capacité réactive intégrée.
    *   **Migrations et Performance :** Drift possède un système de migration assisté et testable, bien plus robuste que la gestion manuelle de `sqflite`. Contrairement aux idées reçues, Drift est également plus performant par défaut car il est construit sur les backends FFI les plus rapides.

#### **3. Modélisation de Données : Freezed**

*   **Validation et Recommandation :** **Freezed est adopté** pour la création de tous les modèles de données et états de l'application.
*   **Rôle et Synergie :**
    *   **Immuabilité :** Freezed garantit l'immuabilité des états, un principe fondamental de Riverpod. Il génère automatiquement les méthodes `copyWith`, `==`, `hashCode`, etc.
    *   **Union Types (Sealed Classes) :** Sa capacité à créer des unions est essentielle pour modéliser des états complexes (ex: `initial`, `loading`, `success(data)`, `error(message)`), permettant un pattern matching exhaustif et type-safe dans l'UI avec la méthode `.when()`.
    *   **Séparation des Couches (Point architectural clé) :** La recherche insiste sur une séparation stricte des responsabilités. Les classes générées par **Drift** sont des entités de la couche de données (Data Layer). Les classes générées par **Freezed** sont des modèles de vue pour la couche de présentation (Presentation Layer). Un **"Mapper"** doit être implémenté pour convertir les unes en les autres, garantissant la maintenabilité et le découplage.

#### **4. Qualité et Analyse Statique : `very_good_analysis`**

*   **Validation et Recommandation :** L'adoption de **`very_good_analysis`** est validée comme base, complétée par `riverpod_lint` et les options `strong-mode` les plus strictes de l'analyseur Dart.
*   **Justification :** `very_good_analysis` est un sur-ensemble bien plus strict que les lints par défaut de Flutter. Il impose des règles qui renforcent l'immuabilité (`prefer_final_locals`) et la sécurité de type, s'alignant parfaitement avec les objectifs du projet. La cohérence du code qu'il impose est également un atout majeur pour le développement assisté par IA.

#### **5. Gestion des Angles Morts (Interopérabilité et Performance des Générateurs)**

*   **Problème Identifié :** L'utilisation cumulative de plusieurs générateurs de code (`riverpod_generator`, `drift_dev`, `freezed`) peut considérablement ralentir les temps de compilation et créer des conflits d'interdépendance.
*   **Solution Prescriptive :** L'utilisation d'un fichier **`build.yaml`** à la racine du projet est la solution validée pour maîtriser ces problèmes. Il permet de :
    1.  **"Scoper" les générateurs** (`generate_for`) pour qu'ils ne s'exécutent que sur des répertoires spécifiques, accélérant drastiquement le processus.
    2.  **Forcer l'ordre d'exécution** (`runs_before`) pour résoudre les conflits, en s'assurant par exemple que les modèles de Drift et Freezed sont générés *avant* que Riverpod ne tente de les utiliser.

---

### **Synthèse des Résultats de la Recherche 2 : Architecture Hybride WebView**

#### **Conclusion Exécutive**

La recherche confirme de manière décisive que la librairie **`flutter_inappwebview` (FIW)** est la seule solution techniquement viable pour répondre aux exigences complexes de l'AI Hybrid Hub. La solution officielle, `webview_flutter` (WVF), est éliminée en raison de ses limitations fondamentales sur deux aspects critiques : la puissance du pont JavaScript et la gestion de la persistance de session (notamment le `LocalStorage`). L'architecture recommandée s'articule donc autour de FIW, avec une couche de script robuste en **TypeScript** transpilée par un outil moderne comme **Vite ou esbuild**, et une gestion de session s'appuyant sur les **singletons natifs** (`CookieManager`, `WebStorageManager`) exposés par FIW.

---

#### **1. Choix de la Librairie WebView : `flutter_inappwebview` est Non-Négociable**

*   **Validation et Recommandation :** L'adoption de **`flutter_inappwebview` v6+** est validée. Ce n'est pas une simple préférence, mais une nécessité architecturale.
*   **Justification Technique Clé :**
    *   **Pont JavaScript Supérieur :** FIW propose un pont bi-directionnel, asynchrone et basé sur les **Promises** (`window.flutter_inappwebview.callHandler()`), ce qui permet une architecture de type **RPC (Remote Procedure Call)** propre et moderne. WVF est limité à un `JavascriptChannel` unidirectionnel et de type `void`, ce qui est inadapté pour les interactions complexes requises.
    *   **Gestion de Session Native :** FIW expose des **singletons natifs** pour le `CookieManager` et, de manière cruciale, le `WebStorageManager`. Ce dernier, qui permet un contrôle natif du `LocalStorage`, est **totalement absent de WVF**, ce qui rend impossible une gestion de session fiable et centralisée avec cette librairie.
    *   **Performance :** Les analyses récentes (versions 6+) indiquent que FIW a résolu ses anciens problèmes de performance et est désormais au moins aussi performant, sinon plus, que WVF dans des scénarios complexes, notamment en évitant les surcoûts de la composition hybride de WVF.
*   **Gestion du Risque :** Le risque du "bus factor" (maintenance par un seul développeur) est réel mais jugé inférieur au risque de stagnation et de manque de fonctionnalités de la solution officielle pour ce cas d'usage avancé. La forte adoption communautaire et l'activité de maintenance soutenue de FIW sont des facteurs d'atténuation importants.

#### **2. Persistance de Session : Stratégie Basée sur les Singletons Natifs**

*   **Validation et Recommandation :** L'architecture de persistance de session doit s'appuyer exclusivement sur les singletons **`CookieManager.instance()`** et **`WebStorageManager.instance()`** fournis par FIW.
*   **Implémentation :**
    *   **Cookies (Authentification) :** Toutes les opérations sur les cookies d'authentification doivent être effectuées via le `CookieManager`. Ceci garantit que les cookies sont partagés nativement entre toutes les instances de `WebView` au sein de l'application. Une attention particulière doit être portée à la configuration du `domain` pour le partage entre sous-domaines.
    *   **LocalStorage (Données d'Application) :** Le `WebStorageManager` est l'outil de choix pour gérer le `LocalStorage` de manière centralisée depuis Dart. Il permet de "pré-chauffer" une `WebView` avec des données avant même son chargement.
    *   **Angle Mort - Cookies Tiers :** La recherche identifie un risque critique sur Android : le blocage par défaut des cookies tiers. La solution est d'activer explicitement `controller.android.setAcceptThirdPartyCookies(true)`.

#### **3. Outillage Web : TypeScript + Vite/esbuild pour la Robustesse**

*   **Validation et Recommandation :** Le code du pont JavaScript doit être développé en **TypeScript** et transpilé/bundlé en un **fichier unique** au format **IIFE** (Immediately Invoked Function Expression) via un outil moderne comme **Vite (en mode librairie) ou esbuild**.
*   **Bénéfices :**
    *   **Sécurité de Type :** Le contrat d'API entre Dart et le web est vérifié à la compilation TypeScript, prévenant les erreurs de runtime.
    *   **Maintenabilité :** Le code du pont est structuré, modulaire et facile à refactoriser.
    *   **Performance :** La transpilation et la minification par esbuild sont extrêmement rapides et optimisent le code pour l'injection.
*   **Stratégie d'Injection :** Le bundle JS généré doit être injecté via un **`UserScript`** de FIW avec le temps d'injection **`AT_DOCUMENT_START`**. C'est la seule manière de garantir que l'API du pont est disponible avant l'exécution de tout autre script sur la page web, évitant ainsi les "race conditions".

#### **4. Contrat d'API du Pont : Architecture RPC Asynchrone**

*   **Validation et Recommandation :** L'architecture du pont doit suivre un pattern **RPC (Remote Procedure Call)** asynchrone, et non un simple "message bus".
*   **Implémentation :**
    *   **Côté TypeScript :** Créer une "façade" (ex: `window.nativeAPI`) qui expose une API typée et basée sur des **Promises**. Cette façade encapsule les appels à `window.flutter_inappwebview.callHandler()`.
    *   **Côté Dart :** Enregistrer des **`JavaScriptHandler`** correspondants pour chaque méthode de l'API. Ces handlers doivent retourner des valeurs ou lancer des exceptions, qui résoudront ou rejetteront automatiquement la `Promise` côté JavaScript.
    *   **Standardisation :** Pour les événements non critiques ("fire-and-forget"), un schéma de message standardisé (`event`/`payload`/`timestamp`) peut être utilisé, mais le pattern RPC reste la norme pour les interactions command-response.

---

### **Synthèse des Résultats de la Recherche 3 : Moteur d'Automatisation DOM**

#### **Conclusion Exécutive**

La recherche valide une architecture complète pour le moteur d'automatisation DOM en TypeScript, axée sur une résilience extrême face aux changements d'interface des sites tiers. L'architecture repose sur trois piliers :
1.  Une **configuration des sélecteurs découplée et gérée à distance**, supportant une stratégie de repli ("fallback") multi-niveaux.
2.  Des **patterns d'interaction asynchrones (`async/await`)** qui simulent le comportement humain et attendent que les éléments soient "actionnables" plutôt que de se baser sur des délais fixes.
3.  Une utilisation chirurgicale et optimisée de **`MutationObserver`** pour détecter les changements d'état sans impacter les performances de la batterie mobile.

Un protocole de communication d'erreurs structuré permet une **dégradation gracieuse**, transformant les échecs d'automatisation en états gérés par l'application native.

---

#### **1. Stratégie de Sélecteurs : "Défense en Profondeur" via Configuration Distante**

*   **Validation et Recommandation :** Toute la logique de sélection des éléments DOM sera externalisée dans un **fichier de configuration JSON**. Ce fichier sera récupéré depuis une URL distante, mis en cache localement sur l'appareil (via IndexedDB ou équivalent), et injecté dans la `WebView`.
*   **Structure de "Défense en Profondeur" :** Chaque définition de sélecteur dans le JSON doit inclure un **`primary`** sélecteur (le plus robuste, ex: `[data-testid=...]`) et un tableau ordonné de **`fallbacks`**. Le moteur essaiera séquentiellement chaque sélecteur de cette liste, garantissant une résilience maximale.
*   **Workflow de Gestion de la Configuration :**
    *   La couche **native Dart** est responsable de la récupération et de la mise en cache du JSON.
    *   La récupération utilise les en-têtes `ETag` pour l'efficacité réseau.
    *   Un mécanisme de "guérison" est implémenté : si le moteur TypeScript remonte une erreur critique de type `SELECTOR_NOT_FOUND`, la couche Dart déclenchera une tentative de rafraîchissement de la configuration en arrière-plan.

#### **2. Logique d'Interaction DOM : Asynchrone et Basée sur l'État**

*   **Validation et Recommandation :** Toutes les interactions DOM doivent être implémentées via des fonctions **`async/await`**. L'utilisation de délais fixes (`setTimeout`) pour attendre les éléments est **strictement proscrite**.
*   **Patterns Clés :**
    *   **`findElementWithFallbacks` :** C'est la fonction centrale du moteur. Elle implémente une boucle **`for...of` séquentielle** (et non parallèle) pour itérer sur les sélecteurs primaires et de repli, garantissant que la priorité est respectée.
    *   **`robustQuerySelector` :** Cette primitive ne se contente pas de trouver un élément. Elle attend activement (en utilisant `MutationObserver`) que l'élément soit non seulement présent dans le DOM, mais aussi **"actionnable"** (visible, non-désactivé, avec une taille non nulle). Elle remplace la nécessité de chaînes `await sleep(...)` fragiles.
    *   **Simulation d'Interaction Humaine :** Les actions comme `click` et `typeText` doivent simuler des événements de bas niveau (`mouseover`, `mousedown`, saisie caractère par caractère) pour contourner les protections de certains frameworks web.

#### **3. `MutationObserver` : Stratégie "Observer Éphémère en Deux Étapes"**

*   **Validation et Recommandation :** Pour éviter un impact catastrophique sur la batterie, une stratégie d'observation optimisée est adoptée, rejetant l'idée d'un observateur unique et global.
*   **Architecture "Éphémère en Deux Étapes" :**
    1.  **Observer-Start :** Un premier observateur, peu coûteux (configuré pour `childList: true` uniquement), surveille un large conteneur (ex: l'historique du chat) pour détecter l'**ajout d'un nouveau nœud de réponse**.
    2.  **Observer-End :** Dès que le nouveau nœud est détecté, un **second observateur, temporaire et spécifique**, est attaché *uniquement à ce nouveau nœud*. Il est configuré précisément pour la tâche (ex: `characterData: true` pour du texte en streaming). Une fois sa condition remplie (ex: fin du streaming), il appelle `disconnect()` sur lui-même et se détruit.
*   **Détection de Fin de Streaming :** Pour les réponses en streaming, une technique de **"debounce"** est utilisée. La fin est déclarée seulement après une période de "calme" (ex: 500ms) sans nouvelles mutations, indiquant que le flux de texte est terminé.

#### **4. Protocole de Communication et Dégradation Gracieuse**

*   **Validation et Recommandation :** La communication de TypeScript vers Dart se fera via un **flux d'événements unidirectionnel**. TypeScript ne fait que "rapporter" son état via un `JavaScriptHandler` unique.
*   **Schéma d'Événement :** Un schéma JSON `AutomationEvent` est défini, incluant `eventType` (`STATE_CHANGE`, `FAILURE`, etc.) et un `payload` structuré.
*   **"Triage d'Échec" Heuristique :** Lorsqu'une interaction échoue (ex: `findElement` ne trouve rien), le moteur ne remonte pas une erreur générique. Il exécute une fonction `analyzeFailureHeuristics` qui inspecte la page pour des signatures spécifiques :
    *   **`ERROR_CAPTCHA_DETECTED`** (si un iframe `recaptcha` est trouvé).
    *   **`ERROR_LOGIN_REQUIRED`** (si une URL `login` ou un champ `password` est détecté).
    *   **`ERROR_SELECTOR_EXHAUSTED`** (le cas par défaut, indiquant une configuration obsolète).
*   **Dégradation Gracieuse (Responsabilité de Dart) :** La couche native Dart reçoit ces codes d'erreur spécifiques et orchestre la réponse de l'application : mettre en pause l'automatisation et afficher un overlay pour un CAPTCHA, annuler le workflow pour un login, ou informer l'utilisateur et logger l'erreur pour un sélecteur obsolète.

#### **5. Solutions pour les "Angles Morts"**

*   **Shadow DOM :**
    *   **`open` mode :** Le moteur implémente une fonction de recherche **récursive** qui traverse les `shadowRoot` ouverts.
    *   **`closed` mode :** Une stratégie agressive de **"monkey-patching"** de `Element.prototype.attachShadow` est recommandée. Elle est injectée à `AT_DOCUMENT_START` pour forcer toutes les nouvelles racines fantômes en mode `open`.
*   **Performance Batterie :** En plus de la stratégie `MutationObserver`, la couche native Dart doit informer la `WebView` du cycle de vie de l'application. Lorsque l'application passe en arrière-plan, tous les observateurs doivent être déconnectés, puis réactivés lorsqu'elle revient au premier plan.

---


---


# **Blueprint V3.0 : AI Hybrid Hub - Architecture de Référence Technique**

## **1. Vision & Principes Fondamentaux (Inchangés)**

Ce document définit l'architecture finale de l'application, en s'appuyant sur les résultats des recherches techniques approfondies. La philosophie fondamentale reste inchangée : **"Assister, ne pas cacher"**. L'application est un **"Assistant Marionnettiste Hybride"** qui fusionne une interface native avec les Web UIs existantes des fournisseurs d'IA, en automatisant les tâches répétitives de manière transparente et résiliente, tout en laissant le contrôle final à l'utilisateur.

## **2. Stack Technique Prescrite (Socle Natif Flutter)**

La fondation native de l'application est conçue pour une **sécurité de type statique absolue** à la compilation, une maintenabilité maximale et une productivité élevée grâce à la génération de code.

| Composant | Technologie Choisie | Justification Fondamentale |
| :--- | :--- | :--- |
| **Gestion d'État** | **Riverpod 3.0+** avec `riverpod_generator` | Sécurité de type statique, réduction drastique du code répétitif, testabilité hors de l'arbre de widgets. L'approche `@riverpod` est la seule validée. |
| **Base de Données** | **Drift** (anciennement Moor) | Sécurité de type de bout en bout (schéma, requêtes, résultats). Les **requêtes réactives (`.watch()`)** s'intègrent parfaitement avec Riverpod. `sqflite` est rejeté. |
| **Modélisation** | **Freezed** | Garantit l'**immuabilité** des modèles de données et des états. Les **Union Types** sont essentiels pour modéliser les états complexes (ex: `loading`, `success`, `error`) de manière type-safe. |
| **Qualité du Code** | **`very_good_analysis`** + `riverpod_lint` | Impose un ensemble de règles de linting strictes, alignées sur les meilleures pratiques de l'industrie, renforçant la cohérence et la robustesse du code. |
| **Optimisation Build**| Fichier **`build.yaml`** personnalisé | Indispensable pour gérer l'**interopérabilité** et la **performance** des multiples générateurs de code (`riverpod`, `drift`, `freezed`) via le "scoping" et la définition de l'ordre d'exécution. |

## **3. Architecture Hybride (Couche de Connexion Web)**

Cette couche assure la communication et la persistance de l'état entre le monde natif et les `WebView`.

### **3.1. Librairie WebView : `flutter_inappwebview` (Décision Critique)**

*   **Recommandation Définitive :** **`flutter_inappwebview` v6+** est la seule librairie adoptée.
*   **Justification :** Ses fonctionnalités sont des prérequis non-négociables pour ce projet :
    1.  **Pont JavaScript Supérieur :** Propose un pont bi-directionnel et asynchrone basé sur les **Promises** (`callHandler`), permettant une architecture de type **RPC (Remote Procedure Call)** propre et robuste.
    2.  **Gestion de Session Native :** Expose les singletons natifs **`CookieManager`** et **`WebStorageManager`**, offrant un contrôle total sur les cookies et le `LocalStorage`, ce qui est impossible avec la solution officielle.

### **3.2. Persistance de Session Cross-`WebView`**

*   **Stratégie :** Utiliser les singletons natifs de `flutter_inappwebview` pour gérer un conteneur de données partagé par toutes les instances `WebView`.
*   **Implémentation :**
    *   **Cookies :** Gérer l'authentification via `CookieManager.instance()`.
    *   **LocalStorage :** Gérer les données d'application web via `WebStorageManager.instance()`.
    *   **Risques Mitigés :** Activer explicitement les cookies tiers sur Android (`controller.android.setAcceptThirdPartyCookies(true)`) pour gérer les flux d'authentification externes.

### **3.3. Outillage (Toolchain) TypeScript**

*   **Technologie :** Le code du pont sera développé en **TypeScript** pour la sécurité de type et la maintenabilité.
*   **Build :** Un outil moderne comme **Vite (en mode librairie) ou esbuild** sera utilisé pour transpiler et bundler tout le code TypeScript en un **fichier JavaScript unique** au format **IIFE** (Immediately Invoked Function Expression).

### **3.4. Stratégie d'Injection du Pont**

*   **Méthode :** Le bundle JavaScript généré sera injecté via un **`UserScript`** de `flutter_inappwebview`.
*   **Timing Crucial :** L'injection doit se faire à **`AT_DOCUMENT_START`**. Cela garantit que l'API du pont est disponible pour les scripts de la page web dès leur exécution, évitant toute "race condition".

## **4. Moteur d'Automatisation DOM (Le Cœur en TypeScript)**

Ce moteur est conçu pour une résilience maximale face à des DOM imprévisibles.

### **4.1. Stratégie de Sélecteurs "Défense en Profondeur"**

*   **Configuration Externalisée :** Les sélecteurs ne sont **jamais codés en dur**. Ils sont définis dans un fichier **JSON distant**, qui est récupéré et mis en cache par la couche native Dart.
*   **Structure de Repli (Fallback) :** Chaque définition de sélecteur dans le JSON contient un sélecteur `primary` (le plus robuste) et un tableau ordonné de `fallbacks`. Le moteur les essaie séquentiellement.
*   **Auto-Guérison :** En cas d'échec critique (tous les sélecteurs échouent), le moteur remonte une erreur spécifique qui signale à la couche Dart de tenter de rafraîchir la configuration JSON.

### **4.2. Logique d'Interaction Asynchrone et Basée sur l'État**

*   **Primitives `async/await` :** Toutes les interactions sont asynchrones. L'utilisation de délais fixes (`setTimeout`) pour attendre des éléments est **proscrite**.
*   **Attente d' "Actionnabilité" :** Le moteur n'attend pas seulement qu'un élément *existe*, mais qu'il soit **"actionnable"** (visible, non-désactivé, de taille non-nulle), en s'inspirant des meilleures pratiques des outils de test modernes.

### **4.3. Détection d'État avec `MutationObserver` (Optimisé pour Mobile)**

*   **Stratégie "Observer Éphémère en Deux Étapes" :** Pour préserver la batterie, une approche chirurgicale est adoptée. Un premier observateur léger détecte l'ajout d'un nouveau nœud de réponse, puis un second observateur, temporaire et spécifique, est attaché à ce seul nœud pour surveiller la fin de la génération. Une fois sa tâche accomplie, il se déconnecte immédiatement.
*   **Détection de Fin de Streaming :** Une technique de **"debounce"** est utilisée. La fin de la génération n'est confirmée qu'après une courte période de "calme" sans nouvelles mutations du DOM.

## **5. Contrat d'API & Communication (Le Pont)**

### **5.1. Pattern RPC (Remote Procedure Call) Asynchrone**

*   Le pont est conçu comme une API RPC. Le code TypeScript expose une "façade" typée (ex: `window.nativeAPI.auth.getToken()`) qui retourne des **Promises**. Côté Dart, des **`JavaScriptHandler`** correspondants retournent des valeurs qui résolvent ces `Promises`.

### **5.2. Protocole d'Événements Unidirectionnel**

*   Pour rapporter son état, le moteur TypeScript utilise un **flux d'événements unidirectionnel** vers Dart. Il envoie des objets JSON structurés (`AutomationEvent`) pour chaque étape, succès ou échec, offrant une transparence totale sur son exécution.

## **6. Gestion des Erreurs & Dégradation Gracieuse**

C'est la clé de voûte de l'expérience utilisateur et de la robustesse de l'application.

### **6.1. Triage d'Échec Heuristique (Côté TypeScript)**

*   En cas d'échec de localisation d'un élément, le moteur ne remonte pas une erreur générique. Il effectue une analyse heuristique de la page pour identifier la cause la plus probable et envoie un code d'erreur spécifique :
    *   **`ERROR_CAPTCHA_DETECTED`**
    *   **`ERROR_LOGIN_REQUIRED`**
    *   **`ERROR_BOT_BLOCK_DETECTED`** (ex: Cloudflare)
    *   **`ERROR_SELECTOR_EXHAUSTED`** (le fallback, indiquant une config obsolète)

### **6.2. Orchestration de la Réponse (Côté Dart)**

*   La couche native Dart est le "chef d'orchestre" de la dégradation gracieuse. Elle reçoit ces codes d'erreur spécifiques et déclenche la réponse UI/UX appropriée :
    *   **Pour un CAPTCHA :** Met en pause l'automatisation et affiche un overlay natif demandant à l'utilisateur de résoudre le CAPTCHA.
    *   **Pour un Login :** Annule le workflow et affiche un message clair indiquant que la reconnexion est nécessaire.
    *   **Pour un Sélecteur Obsolète :** Annule le workflow, informe l'utilisateur de l'indisponibilité temporaire, et logue l'erreur pour alerter l'équipe de maintenance.

## **7. Solutions aux Angles Morts Avancés**

### **7.1. Gestion du Shadow DOM**

*   **Mode `open` :** Implémentation d'une fonction de recherche **récursive** qui traverse les `shadowRoot` ouverts.
*   **Mode `closed` :** Utilisation d'une stratégie de **"monkey-patching"** de `Element.prototype.attachShadow`, injectée à `AT_DOCUMENT_START`, pour forcer l'ouverture des nouvelles racines fantômes.

### **7.2. Optimisation des Performances et de la Batterie**

*   Le moteur TypeScript s'adapte dynamiquement au mode d'économie d'énergie de l'appareil (détecté ou notifié par Dart), en ajustant les intervalles de polling et les délais de debounce.
*   La couche Dart doit notifier la `WebView` des changements de cycle de vie de l'application (passage en arrière-plan/premier plan) pour déconnecter/reconnecter les `MutationObserver` et préserver la batterie.

---
## **Synthèse Finale**

Ce blueprint V3.0 définit une architecture complète, moderne et exceptionnellement robuste. En combinant un socle natif Flutter rigoureusement type-safe avec un moteur d'automatisation DOM résilient et intelligent en TypeScript, le projet est techniquement armé pour atteindre sa vision d'un "Assistant Marionnettiste Hybride" performant et maintenable à l'horizon 2025.