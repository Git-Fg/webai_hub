Résultats de la seconde recherche selon plusieurs agents isolés : 

```
[CONTEXT]
Le projet est une application mobile Android AI Hybrid Hub développée en Flutter, prévue pour fin 2025. Un composant central de l'application est sa capacité à interagir de manière complexe et bi-directionnelle avec des instances `WebView` embarquées. Cette recherche vise à définir l'architecture la plus robuste, performante et maintenable pour ce pont de communication natif-web, en partant de zéro et sans dépendre d'un template existant. L'objectif est de garantir une communication fiable et une persistance de session transparente pour l'utilisateur.

Périmètre de la recherche :
- Librairie WebView : Analyse comparative approfondie entre `flutter_inappwebview` (maintenue par la communauté) et `webview_flutter` (maintenue officiellement par l'équipe Flutter), en se projetant sur leurs versions et capacités attendues fin 2025.
- Persistance de session : Stratégies pour implémenter une gestion partagée des cookies et du `LocalStorage` entre plusieurs instances de `WebView` au sein de la même application, afin de maintenir les sessions utilisateur.
- Pont de communication (Bridge) : Conception d'un contrat d'API robuste entre le code Dart et le code exécuté dans la `WebView`.
- Langage et outillage côté Web : Utilisation de TypeScript pour la sécurité de type du code injecté et d'un bundler moderne (comme `esbuild` ou `Vite` en mode librairie) pour transpiler et minifier le code en un seul script injectable.

Définitions techniques critiques :
- Pont JavaScript (JavaScript Bridge) : Mécanisme de communication bi-directionnelle permettant au code Dart d'appeler des fonctions JavaScript dans une `WebView` et inversement.
- Persistance de session : Capacité de l'application à conserver l'état de connexion d'un utilisateur sur un site web à travers les redémarrages de l'application et entre différentes `WebView`.
- Transpilation : Processus de compilation qui transforme un code source écrit dans un langage (TypeScript) en un code équivalent dans un autre langage (JavaScript).

Hiérarchie des sources privilégiées :
1.  Documentation officielle et exemples de code des librairies `flutter_inappwebview` et `webview_flutter`.
2.  Benchmarks de performance comparant les deux librairies sur des tâches critiques (temps de chargement, latence du pont JS).
3.  Discussions techniques approfondies et *issues* sur GitHub relatives aux limitations de chaque librairie, notamment sur la gestion des sessions et les spécificités par plateforme (Android/iOS).
4.  Tutoriels et articles techniques détaillant des implémentations complexes de ponts JavaScript dans des applications Flutter de production.

Exclusions méthodologiques strictes :
- Solutions qui ne permettent pas une communication bi-directionnelle asynchrone.
- Approches qui reposent sur l'ouverture d'un navigateur externe à l'application.
- Analyses basées sur des versions des librairies antérieures à 2024.

Angles morts à investiguer :
- Le risque de maintenance associé à `flutter_inappwebview` étant principalement porté par un seul développeur, versus la potentielle lenteur d'évolution de la solution officielle.
- Les subtilités et différences de comportement des `WebView` entre les différentes versions d'Android (API levels).
- La complexité réelle de la gestion manuelle du `CookieManager` et du `WebStorageManager` pour assurer une persistance de session sans faille.

[OBJECTIFS]
Architecturer la solution technique la plus fiable et pérenne pour l'intégration et la communication avec les `WebView` au sein de l'application AI Hybrid Hub. Le résultat doit être une spécification technique claire pour cette couche hybride.
1.  Produire une recommandation argumentée pour le choix entre `flutter_inappwebview` et `webview_flutter`, basée sur une évaluation multi-critères : puissance du pont JavaScript, maturité de la gestion de session, performance, dynamique de maintenance et support communautaire projeté pour 2025.
2.  Détailler une stratégie d'implémentation concrète pour la persistance de session cross-`WebView`, incluant la gestion des cookies et du stockage local, qui soit indépendante de tout template de projet.
3.  Valider l'approche consistant à utiliser TypeScript transpilé via `esbuild` ou `Vite` pour le développement des scripts injectés, en démontrant les gains en termes de robustesse, de maintenabilité et de sécurité de type.
4.  Définir la structure du contrat d'API du pont JavaScript, en spécifiant le format des messages échangés (ex: JSON avec un schéma `event`/`payload`) et les conventions de nommage pour garantir une communication claire et sans ambiguïté entre Dart et TypeScript.
```

RECHERCHE 1 : 



Je vais commencer par effectuer une recherche pour identifier les sources les plus pertinentes concernant les librairies WebView Flutter, leur comparaison, et les stratégies de persistance de session.

Je vais maintenant examiner la documentation officielle de flutter_inappwebview pour comprendre ses capacités en matière de pont JavaScript et de gestion de session.

Je vais maintenant consulter la documentation officielle détaillée de flutter_inappwebview pour comprendre ses capacités techniques spécifiques.

Je vais continuer à explorer la documentation pour trouver les sections spécifiques sur le pont JavaScript et la gestion de session.

Je vais continuer à faire défiler pour trouver les sections techniques sur le pont JavaScript et la gestion de session.

Je vais continuer à faire défiler pour trouver les sections techniques sur le pont JavaScript et la gestion de session.

Je vais faire une dernière tentative de défilement pour trouver les sections techniques, puis je chercherai directement les informations sur le pont JavaScript.

Je vais maintenant chercher spécifiquement des informations sur le pont JavaScript dans flutter_inappwebview en utilisant une recherche ciblée.

Je vais maintenant consulter la documentation officielle sur la communication JavaScript dans flutter_inappwebview.

Je vais essayer l'URL de la documentation pour la version 5.x.x qui semblait plus complète dans les résultats de recherche.

Je vais maintenant consulter la documentation API sur pub.dev pour flutter_inappwebview pour obtenir des informations détaillées sur les classes JavaScript et de gestion de stockage.

Je vais faire défiler la page pour trouver les classes liées à la communication JavaScript et à la gestion du stockage.

Je vais continuer à faire défiler pour trouver plus de classes pertinentes liées à la communication JavaScript et à la gestion du stockage.

Je vais continuer à faire défiler pour trouver les classes clés comme JavaScriptHandler, CookieManager et WebStorageManager.

Je vais faire une dernière tentative de défilement pour trouver les classes principales de communication JavaScript et de gestion de stockage.

Je vais maintenant chercher spécifiquement la classe JavaScriptHandler dans la documentation.

Je vais maintenant chercher la classe WebStorageManager dans la documentation.

Je vais maintenant chercher la classe LocalStorage dans la documentation.

Je vais visiter directement la page de documentation de la classe LocalStorage.

Je vais maintenant visiter la documentation du WebStorageManager mentionnée dans les résultats de recherche.

Je vais maintenant chercher des informations sur la communication JavaScript entre Flutter et WebView dans flutter_inappwebview.

Je vais maintenant consulter le gist qui montre un exemple concret d'utilisation de addJavaScriptHandler dans flutter_inappwebview.

Je vais maintenant consulter la documentation sur la communication JavaScript pour la version 5.x.x.

Je vais maintenant consulter l'article Medium sur la communication JavaScript dans InAppWebView 5.

Je vais continuer à lire cet article pour obtenir plus de détails sur l'implémentation de la communication JavaScript.

Je vais maintenant chercher des informations sur webview_flutter pour pouvoir faire une comparaison approfondie entre les deux librairies.

Je vais faire défiler pour voir s'il y a plus d'informations sur la communication JavaScript et la gestion des cookies dans webview_flutter.

Je vais continuer à faire défiler pour chercher des informations sur la communication JavaScript et la gestion des cookies.

Je vais continuer à faire défiler pour chercher des informations sur la communication JavaScript bidirectionnelle et la gestion des cookies.

Je vais maintenant chercher des informations détaillées sur l'implémentation des JavaScriptChannels dans webview_flutter.

Je vais maintenant consulter l'article sur l'implémentation des JavaScriptChannels dans webview_flutter.

Je vais continuer à lire cet article pour voir l'implémentation concrète des JavaScriptChannels.

Je vais continuer à lire pour voir la partie JavaScript et comment envoyer des messages depuis le web vers Flutter.

Je vais maintenant consulter la documentation de WebViewCookieManager pour comprendre la gestion des cookies dans webview_flutter.

Je vais maintenant chercher un exemple concret d'utilisation de WebViewCookieManager.

Je vais maintenant chercher des informations sur l'utilisation de TypeScript avec esbuild ou Vite pour l'injection de scripts dans Flutter WebView.

Je vais maintenant consulter le guide complet sur l'injection JavaScript dans Flutter WebView.

Je vais continuer à lire cet article pour voir s'il y a des informations sur l'utilisation de TypeScript et les meilleures pratiques.

Je vais maintenant consulter la réponse Stack Overflow sur TypeScript dans Flutter WebView.

Je vais maintenant consulter l'article sur l'injection JavaScript avec User Scripts dans flutter_inappwebview.

Je vais continuer à lire cet article pour comprendre comment fonctionnent les UserScripts dans flutter_inappwebview.

Je vais continuer à lire pour voir des exemples plus concrets d'utilisation des UserScripts.

Je vais continuer à lire pour voir la partie Flutter qui gère ces communications.

Maintenant que j'ai recueilli suffisamment d'informations techniques, je vais synthétiser mes recherches pour fournir une recommandation argumentée et une spécification technique complète pour le projet AI Hybrid Hub.

# Spécification Technique : Architecture WebView pour AI Hybrid Hub

## Synthèse des Recherches et Recommandations

### 1. Recommandation Argumentée : Choix de la Librairie WebView

#### **Recommandation : flutter_inappwebview**

Après une analyse approfondie des deux librairies, je recommande **flutter_inappwebview** pour le projet AI Hybrid Hub pour les raisons suivantes :

##### **Avantages Techniques de flutter_inappwebview :**

1. **Pont JavaScript Plus Puissant et Flexible** :
   - **Mécanisme avancé** : `addJavaScriptHandler()` avec support des Promises pour retour asynchrone
   - **UserScripts** : Permet d'injecter du JavaScript avant (`AT_DOCUMENT_START`) ou après (`AT_DOCUMENT_END`) le chargement du DOM
   - **Content Worlds** : Isolation d'exécution pour éviter les conflits entre scripts
   - **Communication bidirectionnelle native** : `window.flutter_inappwebview.callHandler()` plus élégant que les canaux nommés

2. **Gestion de Session Supérieure** :
   - **WebStorageManager** : Singleton complet pour gérer localStorage, sessionStorage, WebSQL, IndexedDB
   - **CookieManager** : Gestion fine des cookies avec persistance cross-instances
   - **Partage d'état** : Les instances WebView peuvent partager le même contexte de stockage

3. **Fonctionnalités Avancées** :
   - Support des WebMessageChannels et WebMessageListeners
   - Gestion des headers HTTP personnalisés
   - Support des Service Workers
   - Debugging intégré

##### **Comparaison avec webview_flutter :**

| Critère | flutter_inappwebview | webview_flutter |
|---------|----------------------|-----------------|
| **Pont JavaScript** | ✅ addJavaScriptHandler avec Promises | ⚠️ JavaScriptChannel basique |
| **Injection Scripts** | ✅ UserScripts (timing précis) | ⚠️ runJavaScript uniquement |
| **Gestion Session** | ✅ WebStorageManager complet | ⚠️ WebViewCookieManager limité |
| **Persistance** | ✅ Cross-instances native | ❌ Manuel et complexe |
| **Performance** | ✅ Version 6.0+ optimisée | ⚠️ Variable selon plateforme |
| **Maintenance** | ⚠️ Développeur principal unique | ✅ Support officiel Flutter |

##### **Analyse des Risques :**

1. **Risque Maintenance flutter_inappwebview** :
   - **Risque réel** : Principalement maintenu par un seul développeur (Lorenzo Pichilli)
   - **Atténuation** : La version 6.0+ a montré une amélioration significative des performances et une communauté active
   - **Projection 2025** : Le rythme de développement est soutenu et la librairie est largement adoptée

2. **Risque Lenteur webview_flutter** :
   - **Risque réel** : L'évolution est plus lente et dépend des priorités de l'équipe Flutter
   - **Projection 2025** : Les fonctionnalités avancées pourraient ne pas être disponibles à temps

### 2. Stratégie d'Implémentation pour la Persistance de Session

#### **Architecture de Persistance Cross-WebView**

```dart
// Service centralisé de gestion de session
class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  late final CookieManager _cookieManager;
  late final WebStorageManager _webStorageManager;

  Future<void> initialize() async {
    _cookieManager = CookieManager.instance();
    _webStorageManager = WebStorageManager.instance();
  }

  // Persister les cookies entre instances
  Future<void> shareCookiesBetweenWebViews() async {
    final cookies = await _cookieManager.getCookies(url: WebUri("https://votre-domaine.com"));
    // Logique de partage entre instances
  }

  // Synchroniser le localStorage
  Future<void> synchronizeLocalStorage() async {
    // Utiliser WebStorageManager pour la persistance
  }
}
```

#### **Implémentation Concrète :**

1. **Configuration Initiale** :
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SessionManager().initialize();
  runApp(AIHybridHubApp());
}
```

2. **Création de WebView avec Session Partagée** :
```dart
InAppWebView(
  initialUrlRequest: URLRequest(url: WebUri('https://votre-app.com')),
  initialSettings: InAppWebViewSettings(
    javaScriptEnabled: true,
    domStorageEnabled: true, // Activer localStorage
    javaScriptCanOpenWindowsAutomatically: true,
  ),
  onWebViewCreated: (controller) async {
    // Configurer la gestion de session
    await _setupSessionPersistence(controller);
  },
)
```

3. **Gestion des Cookies** :
```dart
Future<void> _setupSessionPersistence(InAppWebViewController controller) async {
  // Récupérer et partager les cookies
  final cookieManager = CookieManager.instance();
  await cookieManager.setCookie(
    url: WebUri('https://votre-app.com'),
    name: 'session_token',
    value: 'votre_token',
    expiresDate: DateTime.now().add(Duration(days: 30)).millisecondsSinceEpoch,
    isSecure: true,
    isHttpOnly: true,
  );
}
```

### 3. Validation de l'Approche TypeScript + esbuild/Vite

#### **Architecture de Développement TypeScript**

```typescript
// bridge.ts - Contrat d'API typé
interface BridgeMessage {
  event: string;
  payload: unknown;
  timestamp: number;
}

interface BridgeResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: string;
}

class FlutterBridge {
  // Appel depuis TypeScript vers Flutter
  static async callHandler<T>(
    handlerName: string, 
    payload: unknown
  ): Promise<BridgeResponse<T>> {
    try {
      const result = await window.flutter_inappwebview.callHandler(
        handlerName, 
        payload
      );
      return {
        success: true,
        data: result as T
      };
    } catch (error) {
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error'
      };
    }
  }

  // Écoute des événements depuis Flutter
  static onEvent<T>(
    eventName: string, 
    callback: (payload: T) => void
  ): void {
    window.addEventListener(`flutter:${eventName}`, (event) => {
      const customEvent = event as CustomEvent<T>;
      callback(customEvent.detail);
    });
  }
}
```

#### **Configuration esbuild/Vite** :

```javascript
// vite.config.js
import { defineConfig } from 'vite';
import { resolve } from 'path';

export default defineConfig({
  build: {
    lib: {
      entry: resolve(__dirname, 'src/bridge.ts'),
      name: 'FlutterBridge',
      fileName: 'bridge',
      formats: ['iife'] // Immediately Invoked Function Expression
    },
    rollupOptions: {
      output: {
        // Exporter globalement pour l'injection dans WebView
        globals: {
          'flutter-bridge': 'FlutterBridge'
        }
      }
    },
    minify: 'terser',
    sourcemap: true
  },
  esbuild: {
    target: 'es2020' // Compatible avec les WebView modernes
  }
});
```

#### **Processus de Build et Injection** :

1. **Développement** :
```bash
# Développement avec hot-reload
npm run dev
```

2. **Production** :
```bash
# Build pour production
npm run build

# Génère : dist/bridge.iife.js (minifié et optimisé)
```

3. **Injection dans Flutter** :
```dart
Future<void> _injectBridgeScript(InAppWebViewController controller) async {
  final script = await rootBundle.loadString('assets/bridge.iife.js');
  await controller.evaluateJavascript(source: script);
}
```

#### **Avantages de cette Approche** :

1. **Sécurité de Type** : TypeScript garantit la cohérence des interfaces
2. **Maintenabilité** : Code structuré et auto-documenté
3. **Performance** : esbuild/Vite optimise le code pour les WebView
4. **Débogage** : Source maps pour le débogage en développement
5. **Intégration** : Le bundle IIFE s'intègre parfaitement dans les WebView

### 4. Structure du Contrat d'API du Pont JavaScript

#### **Format des Messages Échangés**

```typescript
// Format standard des messages
interface StandardMessage<T = unknown> {
  // Identifiant unique du message
  id: string;
  // Type d'événement
  event: string;
  // Données payload
  payload: T;
  // Timestamp pour le traçage
  timestamp: number;
  // Version du contrat
  version: string;
}

// Format des réponses
interface StandardResponse<T = unknown> {
  // Référence au message d'origine
  messageId: string;
  // Statut de la réponse
  success: boolean;
  // Données de réponse
  data?: T;
  // Message d'erreur si échec
  error?: {
    code: string;
    message: string;
    details?: unknown;
  };
}
```

#### **Convention de Nommage**

```typescript
// Préfixes pour organiser les événements
enum EventPrefix {
  // Événements du système
  SYSTEM = 'system',
  // Événements de l'application
  APP = 'app',
  // Événements de l'UI
  UI = 'ui',
  // Événements de données
  DATA = 'data',
  // Événements de navigation
  NAV = 'nav'
}

// Convention de nommage : prefix:action:entity
const EventNames = {
  // Système
  [EventPrefix.SYSTEM]: {
    READY: 'system:ready',
    ERROR: 'system:error',
    LOG: 'system:log'
  },
  // Application
  [EventPrefix.APP]: {
    INIT: 'app:init',
    CONFIG: 'app:config:get',
    STATE: 'app:state:update'
  },
  // UI
  [EventPrefix.UI]: {
    ACTION: 'ui:action:trigger',
    MODAL: 'ui:modal:show',
    TOAST: 'ui:toast:display'
  },
  // Données
  [EventPrefix.DATA]: {
    FETCH: 'data:fetch:request',
    SAVE: 'data:save:request',
    SYNC: 'data:sync:start'
  },
  // Navigation
  [EventPrefix.NAV]: {
    NAVIGATE: 'nav:navigate:to',
    BACK: 'nav:navigate:back',
    REFRESH: 'nav:page:refresh'
  }
} as const;
```

#### **Implémentation du Pont en Dart**

```dart
class JavaScriptBridge {
  final InAppWebViewController _controller;
  final Map<String, Function> _handlers = {};
  final Map<String, Completer> _pendingResponses = {};

  JavaScriptBridge(this._controller) {
    _initializeBridge();
  }

  void _initializeBridge() {
    // Handler pour les réponses asynchrones
    _controller.addJavaScriptHandler(
      handlerName: '__bridge_response',
      callback: (args) {
        final response = StandardResponse.fromJson(args[0]);
        final completer = _pendingResponses[response.messageId];
        if (completer != null) {
          if (response.success) {
            completer.complete(response.data);
          } else {
            completer.completeError(response.error);
          }
          _pendingResponses.remove(response.messageId);
        }
      },
    );
  }

  // Envoi d'un message vers JavaScript
  Future<T?> sendMessage<T>(
    String event, {
    dynamic payload,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final messageId = const Uuid().v4();
    final message = StandardMessage(
      id: messageId,
      event: event,
      payload: payload,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      version: '1.0.0',
    );

    final completer = Completer<T?>();
    _pendingResponses[messageId] = completer;

    await _controller.evaluateJavascript(source: '''
      window.FlutterBridge.receiveMessage(${jsonEncode(message.toJson())});
    ''');

    return completer.future.timeout(timeout);
  }

  // Enregistrement d'un handler pour les événements JavaScript
  void registerHandler(String eventName, Function handler) {
    _handlers[eventName] = handler;
    _controller.addJavaScriptHandler(
      handlerName: eventName,
      callback: (args) {
        return handler(args);
      },
    );
  }
}
```

#### **Exemple d'Utilisation**

```dart
// Côté Flutter
final bridge = JavaScriptBridge(controller);

// Enregistrement des handlers
bridge.registerHandler(EventNames.APP.INIT, (args) {
  print('Application initialisée avec: $args');
  return {'status': 'ready', 'version': '1.0.0'};
});

// Envoi d'un message vers JavaScript
final userData = await bridge.sendMessage(
  EventNames.DATA.FETCH,
  payload: {'endpoint': '/user/profile'},
);

// Côté TypeScript
// Réception des événements
FlutterBridge.onEvent(EventNames.APP.INIT, (payload) => {
  console.log('App initialisée:', payload);
});

// Envoi vers Flutter
const result = await FlutterBridge.callHandler(
  EventNames.UI.ACTION,
  { action: 'button_click', elementId: 'submit-btn' }
);
```

## Conclusion

Cette architecture fournit une base solide et pérenne pour l'intégration WebView dans AI Hybrid Hub :

1. **Choix Technique** : flutter_inappwebview offre les fonctionnalités nécessaires pour une communication complexe et une persistance de session robuste
2. **Persistance** : Le WebStorageManager et CookieManager permettent une gestion centralisée et fiable des sessions
3. **TypeScript** : L'approche avec esbuild/Vite garantit la qualité et la maintenabilité du code injecté
4. **Contrat d'API** : La structure normalisée des messages assure une communication claire et sans ambiguïté

Cette architecture est prête pour les évolutions futures de l'application et pourra supporter les besoins complexes d'AI Hybrid Hub jusqu'en 2025 et au-delà.

---

RECHERCHE 2 :

# Architecture Spécification Hybride : WebView Flutter & JavaScript Bridge
## Couche de Communication Native-Web pour AI Hybrid Hub

**Version:** 1.0  
**Date:** Novembre 2025  
**Contexte:** Application mobile Android Flutter développée fin 2025  
**Environnement de développement:** MacBook Pro M1 (MPS), VSCode, Claude Code

---

## Table des Matières

1. [Recommandation Librairie](#1-recommandation-librairie)
2. [Architecture du Pont JavaScript](#2-architecture-du-pont-javascript)
3. [Persistance de Session Cross-WebView](#3-persistance-de-session-cross-webview)
4. [Stratégie TypeScript & Transpilation](#4-stratégie-typescript--transpilation)
5. [Contrat API du Pont](#5-contrat-api-du-pont)
6. [Considérations Platform](#6-considérations-platform)
7. [Implémentation Recommandée](#7-implémentation-recommandée)

---

## 1. Recommandation Librairie

### Synthèse Multi-Critères

| Critère | flutter_inappwebview | webview_flutter |
|---------|----------------------|-----------------|
| **Puissance JavaScript Bridge** | ⭐⭐⭐⭐⭐ Complète (handlers, channels, listeners) | ⭐⭐⭐⭐ Adéquate (JavascriptChannels) |
| **Maturité Session Management** | ⭐⭐⭐⭐ Robuste mais quirks | ⭐⭐⭐⭐ Standard (limité) |
| **Performance** | ⭐⭐⭐⭐ Bonne, hybrid composition optional | ⭐⭐⭐⭐⭐ Optimale (official) |
| **Support Officiel** | ⭐⭐⭐ Communauté, développeur unique | ⭐⭐⭐⭐⭐ Flutter Team |
| **Dynamique Maintenance 2025** | ⭐⭐⭐ Actif (v6.2.0-beta.2 Oct 2024) | ⭐⭐⭐⭐⭐ Actif (v4.13.0 Mai 2025) |
| **Documentation** | ⭐⭐⭐⭐⭐ Exemplaire (inappwebview.dev) | ⭐⭐⭐⭐ Officielle |
| **Fonctionnalités Avancées** | ⭐⭐⭐⭐⭐ Headless, In-App Browser, Desktop | ⭐⭐⭐ Core-only |
| **Cross-Platform** | ⭐⭐⭐⭐ Android, iOS, macOS, Windows, Web | ⭐⭐⭐⭐ Android, iOS, macOS |
| **Risque de Dépendance** | ⭐⭐⭐ Risque d'abandon (1 dev) | ⭐⭐⭐⭐⭐ Garanti (infrastructure Google) |

### **✅ Recommandation : flutter_inappwebview 6.x+ (avec stratégie de mitigation)**

**Justification :**

1. **Pont JavaScript Supérieur** : API riche avec `addJavaScriptHandler`, `WebMessageChannel`, et `WebMessageListener` offre flexibilité maximale pour architecture bi-directionnelle complexe requise par AI Hybrid Hub.

2. **Gestion de Session Robuste** : `CookieManager` singleton et `WebStorageManager` fournissent contrôle granulaire sur persistance de session cross-WebView, avec workarounds documentés pour iOS/Android quirks.

3. **Documentation Exemplaire** : inappwebview.dev offre API reference complète, exemples production-ready et blog technique détaillé, réduisant courbe d'apprentissage.

4. **Headless & Multi-Instance** : Capacité à gérer multiple instances WebView avec sessions isolées ou partagées selon besoin.

5. **Mitigation du Risque Unique Développeur** :
   - Forker le repository si maintenance devient critique
   - Abstraire interface WebView dans couche service dédiée
   - Maintenir fork lean de dépendances critiques
   - Monitorer évolution webview_flutter comme fallback

### Raisons de Ne Pas Choisir webview_flutter (pour ce projet)

- **JavaScript Bridge Limité** : JavascriptChannels one-way style, sans support natif pour Web Message Channels requis pour architectures complexes.
- **Session Persistence Minimal** : Pas d'équivalent `WebStorageManager`, gestion de cookies moins granulaire.
- **Non-Optimal pour Headless** : Pas de support WebView headless natif.
- **Inflexibilité API** : Bien qu'officiel, API strictement focalise sur cas simples.

---

## 2. Architecture du Pont JavaScript

### 2.1 Modèle de Communication Bi-Directionnelle

```
┌─────────────────────────────────────────────────────────────┐
│ Flutter/Dart Application Layer                              │
│  ├─ WebViewController Management                           │
│  ├─ State Management (BLoC/Riverpod)                       │
│  └─ Business Logic                                          │
└────────────────┬──────────────────────────────────────────┘
                 │
         ┌───────▼────────┐
         │ JavaScript     │
         │ Bridge Layer   │
         │ (json/events)  │
         └───────┬────────┘
                 │
┌────────────────▼──────────────────────────────────────────┐
│ WebView Native Container                                  │
│  ├─ InAppWebViewController (singleton per session)        │
│  ├─ CookieManager (shared across instances)               │
│  └─ WebStorageManager (LocalStorage/SessionStorage)       │
└────────────────┬──────────────────────────────────────────┘
                 │
         ┌───────▼────────┐
         │ TypeScript     │
         │ Runtime        │
         │ (transpiled)   │
         └───────┬────────┘
                 │
┌────────────────▼──────────────────────────────────────────┐
│ Web Application / HTML + CSS + JavaScript                 │
│  ├─ DOM Rendering                                         │
│  ├─ Event Listeners                                       │
│  └─ API Calls (via injected TypeScript bridge)           │
└───────────────────────────────────────────────────────────┘
```

### 2.2 Mécanismes de Communication Triés par Cas d'Usage

#### **A) JavaScript Handlers (Synchrone/Promise-based)**
**Cas d'usage** : Appels légers, fréquents, avec réponse attendue.

*Dart → JavaScript :*
```dart
await controller.evaluateJavascript(
  source: "window.flutter_inappwebview.callHandler('methodName', arg1, arg2)"
);
```

*JavaScript → Dart :*
```javascript
window.addEventListener("flutterInAppWebViewPlatformReady", function(event) {
  window.flutter_inappwebview.callHandler('getSessionToken')
    .then(result => console.log(result));
});
```

**Avantages** : Simple, type-safe promise-based, pas de configuration.  
**Inconvénients** : Latence réseau courte, pas idéal pour flux streams.

#### **B) Web Message Channels (Full-Duplex)**
**Cas d'usage** : Communication persistante bidirectionnelle, event streaming, real-time updates.

*Dart initialization :*
```dart
onLoadStop: (controller, url) async {
  var channel = await controller.createWebMessageChannel();
  await channel.port1.setWebMessageCallback((message) async {
    // Handle message from JS
    await channel.port1.postMessage(WebMessage(data: 'response'));
  });
  await controller.postWebMessage(
    message: WebMessage(data: 'init', ports: [channel.port2]),
    targetOrigin: WebUri('*')
  );
}
```

*JavaScript listener :*
```javascript
window.addEventListener('message', (event) => {
  if (event.data === 'init') {
    port = event.ports[0];
    port.onmessage = (msg) => console.log('From Dart:', msg.data);
    port.postMessage('Ready');
  }
});
```

**Avantages** : Full-duplex, low-latency, event-driven, persistent.  
**Inconvénients** : Configuration initiale plus complexe, Android API 21+ requis.

#### **C) Web Message Listeners (Injection Directe)**
**Cas d'usage** : Accès aux fonctionnalités natives sans attendre initialis WebView.

*Dart setup (avant load) :*
```dart
await controller.addWebMessageListener(WebMessageListener(
  jsObjectName: 'hybridAPI',
  allowedOriginRules: Set.from(['https://yourdomain.com']),
  onPostMessage: (message, sourceOrigin, isMainFrame, replyProxy) {
    replyProxy.postMessage('Got it!');
  },
));
```

*JavaScript usage :*
```javascript
hybridAPI.postMessage('action:getUserData');
hybridAPI.onmessage = (event) => console.log(event.data);
```

**Avantages** : Injection immédiate, pas d'event listener setup, origin checking.  
**Inconvénients** : Android uniquement (API 21+), moins flexible que channels.

### 2.3 Architecture Recommandée pour AI Hybrid Hub

**Approche Hybride :**

```
┌─────────────────────────────────────────────┐
│ TypeScript Bridge Wrapper (injected)        │
│  ├─ Event Router (forward to Dart)         │
│  ├─ Command Queue (buffer during init)     │
│  ├─ Promise Handlers (request/response)    │
│  └─ Port Manager (Web Message Channels)    │
└──────────────────┬────────────────────────┘
                   │
        ┌──────────┴──────────┐
        │                     │
    ┌───▼──────┐       ┌─────▼────┐
    │ Channel  │       │ Handlers  │
    │ (streams)│       │ (RPC)     │
    └───┬──────┘       └─────┬────┘
        │                    │
┌───────▼────────────────────▼──────────────┐
│ flutter_inappwebview Bridge                │
│ (native platform implementations)          │
└────────────────────────────────────────────┘
```

**Rationale :**
- **Web Message Channels** pour flux critiques (session updates, user actions stream).
- **JavaScript Handlers** pour RPC légers (get user profile, validate input).
- **TypeScript Wrapper** centralise routing, masque complexité platform differences.

---

## 3. Persistance de Session Cross-WebView

### 3.1 Architecture de Stockage Partagé

```
Application Lifecycle:
│
├─ app_start()
│  ├─ CookieManager.instance().flush() [workaround iOS]
│  └─ CookieManager.instance().getAllCookies()
│
├─ webview1_load()
│  ├─ Load domain1.com
│  ├─ CookieManager handles persistence automatically
│  └─ LocalStorage available via JavaScript
│
├─ webview2_load()
│  ├─ Load domain2.com
│  ├─ CookieManager auto-retrieves domain1 cookies if cross-domain
│  └─ Shared WebStorageManager for offline state
│
└─ app_close()
   ├─ CookieManager.instance().flush() [iOS fix]
   └─ WebStorageManager auto-syncs to disk
```

### 3.2 Gestion Détaillée des Cookies

#### **Initialization (App Start)**

```dart
Future<void> initializeSessionPersistence() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Workaround for iOS/Android cookie flush issue
  // (See GitHub issue #2355 flutter_inappwebview)
  final cookieManager = CookieManager.instance();
  
  // Force cookie sync at app start
  await cookieManager.setCookie(
    url: WebUri('https://google.fr'),
    name: 'flush_flag',
    value: 'true',
  );
  
  // Retrieve existing session cookies
  final existingCookies = await cookieManager.getCookies(
    url: WebUri('https://yourdomain.com'),
  );
  
  logger.info('Loaded ${existingCookies.length} persisted cookies');
}
```

**Pourquoi ce workaround ?**
- Historiquement (v6.0.0), cookies ne se relisaient pas correctement après app restart sur iOS/Android.
- Setting un dummy cookie force le gestionnaire à synchroniser l'état.
- v6.2.0+ améliore cela, mais backward-compatible workaround reste prudent.

#### **Setup WebView Avec Persistence**

```dart
InAppWebView(
  initialUrlRequest: URLRequest(
    url: WebUri('https://yourdomain.com'),
    headers: _buildAuthHeaders(), // Custom auth if needed
  ),
  initialSettings: InAppWebViewSettings(
    // Crucially: Do NOT clear cookies/storage on load
    cacheEnabled: true,
    databaseEnabled: true,
    domStorageEnabled: true,
    localStorage Enabled: true,
  ),
  onWebViewCreated: (controller) {
    // Inject session token if available
    _injectSessionToken(controller);
  },
)
```

#### **Multi-WebView Session Sharing**

```dart
class SessionManager {
  static final _instance = SessionManager._internal();
  final CookieManager _cookieManager = CookieManager.instance();
  final WebStorageManager _storageManager = WebStorageManager.instance();
  
  factory SessionManager() => _instance;
  SessionManager._internal();
  
  /// Sync session across all WebView instances
  Future<void> syncSessionToDomain(String domain) async {
    final cookies = await _cookieManager.getCookies(
      url: WebUri(domain),
    );
    
    // Verify session-critical cookies present
    final sessionCookie = cookies.firstWhere(
      (c) => c.name == 'session_id',
      orElse: () => throw Exception('Session expired'),
    );
    
    logger.info('Session synced for $domain: ${sessionCookie.value}');
  }
  
  /// Persist application state to LocalStorage
  Future<void> saveAppState(
    InAppWebViewController controller,
    Map<String, dynamic> state,
  ) async {
    final jsonState = jsonEncode(state);
    
    await controller.evaluateJavascript(
      source: '''
        localStorage.setItem('app_state', JSON.stringify($jsonState));
      '''
    );
  }
  
  /// Retrieve persisted state
  Future<Map<String, dynamic>> loadAppState(
    InAppWebViewController controller,
  ) async {
    final result = await controller.evaluateJavascript(
      source: 'localStorage.getItem("app_state")'
    );
    
    return jsonDecode(result ?? '{}');
  }
}
```

### 3.3 Problèmes Platform Spécifiques & Solutions

#### **Android (API Levels Variance)**

| Issue | API Levels | Solution |
|-------|-----------|----------|
| Cookie isolation per-process | 28+ | Use `WebView.setDataDirectorySuffix()` pour separate WebViews |
| Limited CookieManager | < 21 | Upgrade minSdkVersion to 21+ (legacy support discontinued) |
| Cleartext traffic blocked | 28+ | Require HTTPS, or allow cleartext in Network Security Config |
| HttpAuthCredentials reset | All | Manually manage via CookieManager post-auth |

**Implémentation** :
```dart
// For Android 28+, ensure data directory separation if multi-process
final cookieManager = CookieManager.instance();
// Already handles isolation, but be aware in multi-process apps
```

#### **iOS (WKWebView Quirks)**

| Issue | Solution |
|-------|----------|
| Cookies not persisting after app restart | Call `CookieManager.flush()` on app exit + at startup |
| Session cookies lost on cold start | Set explicit expiry date on session cookies (not relative) |
| WKHTTPCookieStore isolation | CookieManager abstracts, but iOS 11.0+ required for full support |

**Implémentation** :
```dart
Future<void> persistSessionCookie() async {
  final cookieManager = CookieManager.instance();
  
  // Ensure session cookie has explicit far-future expiry (not just session)
  final expiryDate = DateTime.now().add(Duration(days: 365)).millisecondsSinceEpoch;
  
  await cookieManager.setCookie(
    url: WebUri('https://yourdomain.com'),
    name: 'session_id',
    value: 'abc123...',
    expiresDate: expiryDate, // NOT omitted
    isHttpOnly: true,
    isSecure: true,
  );
}
```

### 3.4 WebStorageManager (LocalStorage/SessionStorage)

```dart
class LocalStorageManager {
  static final _instance = LocalStorageManager._internal();
  factory LocalStorageManager() => _instance;
  LocalStorageManager._internal();
  
  /// Save complex state to browser localStorage
  Future<void> save(
    InAppWebViewController controller,
    String key,
    Map<String, dynamic> value,
  ) async {
    final script = '''
      (function() {
        const data = ${jsonEncode(value)};
        localStorage.setItem('$key', JSON.stringify(data));
        console.log('Saved: $key');
      })();
    ''';
    
    await controller.evaluateJavascript(source: script);
  }
  
  /// Retrieve from localStorage with fallback
  Future<Map<String, dynamic>?> load(
    InAppWebViewController controller,
    String key,
  ) async {
    final result = await controller.evaluateJavascript(
      source: 'localStorage.getItem("$key")'
    );
    
    if (result == null) return null;
    return jsonDecode(result);
  }
  
  /// Clear on logout
  Future<void> clear(
    InAppWebViewController controller,
    String key,
  ) async {
    await controller.evaluateJavascript(
      source: 'localStorage.removeItem("$key")'
    );
  }
}
```

---

## 4. Stratégie TypeScript & Transpilation

### 4.1 Approche Architecture

**Workflow :**

```
src/typescript/
├─ types.ts              (Shared types/interfaces)
├─ bridge.ts             (Main bridge implementation)
├─ handlers.ts           (Exported handler functions)
├─ messages.ts           (Message protocol definitions)
└─ config.ts             (Configuration constants)
         │
         ├─ npm run build
         │
         ▼
dist/
├─ bridge.min.js         (Minified single bundle)
└─ bridge.js.map         (Source map for debugging)
         │
         ├─ Copy to Flutter assets
         │
         ▼
flutter/assets/js/
└─ bridge.min.js
         │
         ├─ Load in WebView via injectJavascriptFileFromAsset
         │
         ▼
WebView Runtime
```

### 4.2 Build Configuration (esbuild)

**File: `build.js` (ESBuild setup)**

```javascript
import * as esbuild from 'esbuild';

await esbuild.build({
  entryPoints: ['src/typescript/bridge.ts'],
  bundle: true,
  minify: true,
  sourcemap: true,
  target: ['es2018', 'chrome58'], // Target Android WebView Chrome 58+
  outfile: 'dist/bridge.min.js',
  platform: 'browser',
  format: 'iife', // Immediately Invoked Function Expression
  globalName: 'HybridBridge', // Exposes window.HybridBridge
  define: {
    'process.env.DEBUG': 'false',
    'process.env.BRIDGE_VERSION': '"1.0.0"',
  },
  logLevel: 'info',
});
```

**Why esbuild over Vite?**
- esbuild significantly faster (~10-40x than terser) for single-file bundles
- Minimal configuration for library mode
- Perfect for WebView script injection (library = single JS file)
- Vite optimized for complex multi-file apps; overkill here

### 4.3 TypeScript Source

**File: `src/typescript/types.ts`**

```typescript
// Shared type definitions between Dart and TypeScript

export interface BridgeMessage {
  id: string;
  type: 'request' | 'response' | 'event';
  action: string;
  payload: unknown;
  timestamp: number;
  source: 'dart' | 'javascript';
}

export interface BridgeRequest extends BridgeMessage {
  type: 'request';
}

export interface BridgeResponse extends BridgeMessage {
  type: 'response';
  error?: string;
  result?: unknown;
}

export interface BridgeEvent extends BridgeMessage {
  type: 'event';
  data: unknown;
}

export interface SessionContext {
  sessionId: string;
  userId: string;
  isAuthenticated: boolean;
  expiresAt: number;
}

export type BridgeHandler<T = unknown> = (payload: T) => Promise<unknown> | unknown;
```

**File: `src/typescript/bridge.ts` (Main Implementation)**

```typescript
import { BridgeMessage, BridgeRequest, BridgeResponse, BridgeHandler } from './types';

class HybridBridge {
  private handlers: Map<string, BridgeHandler> = new Map();
  private requestQueue: BridgeRequest[] = [];
  private isReady: boolean = false;
  private messageId: number = 0;

  constructor() {
    this.initialize();
  }

  private initialize(): void {
    // Wait for Dart bridge to be ready
    if (typeof window !== 'undefined') {
      window.addEventListener('flutterInAppWebViewPlatformReady', () => {
        this.isReady = true;
        this.processQueuedRequests();
      });

      // Fallback for faster initialization
      setTimeout(() => {
        if (!this.isReady && (window as any).flutter_inappwebview) {
          this.isReady = true;
          this.processQueuedRequests();
        }
      }, 100);
    }
  }

  private generateId(): string {
    return `msg_${++this.messageId}_${Date.now()}`;
  }

  /**
   * Register a handler that can be called from Dart
   */
  public registerHandler<T = unknown>(
    action: string,
    handler: BridgeHandler<T>
  ): void {
    this.handlers.set(action, handler);
  }

  /**
   * Send request to Dart and await response
   */
  public async request<T = unknown>(
    action: string,
    payload?: unknown
  ): Promise<T> {
    if (!this.isReady) {
      return new Promise((resolve) => {
        const messageId = this.generateId();
        this.requestQueue.push({
          id: messageId,
          type: 'request',
          action,
          payload,
          timestamp: Date.now(),
          source: 'javascript',
        });
        
        // Re-check after queue added
        if (this.isReady) {
          this.processQueuedRequests();
        }
      });
    }

    try {
      const result = await (window as any).flutter_inappwebview.callHandler(
        action,
        payload
      );
      return result as T;
    } catch (error) {
      throw new Error(`Bridge request failed: ${action} - ${error}`);
    }
  }

  /**
   * Emit event to Dart (fire-and-forget)
   */
  public emit(action: string, data: unknown): void {
    if (!this.isReady) {
      console.warn(`Bridge not ready, queuing event: ${action}`);
      return;
    }

    try {
      (window as any).flutter_inappwebview.callHandler(
        `event:${action}`,
        data
      );
    } catch (error) {
      console.error(`Bridge emit failed: ${action}`, error);
    }
  }

  /**
   * Process queued requests after bridge ready
   */
  private processQueuedRequests(): void {
    while (this.requestQueue.length > 0) {
      const msg = this.requestQueue.shift();
      if (msg) {
        this.request(msg.action, msg.payload).catch((err) => {
          console.error(`Queued request failed: ${msg.action}`, err);
        });
      }
    }
  }

  /**
   * Get version for debugging
   */
  public getVersion(): string {
    return '1.0.0';
  }
}

// Export singleton instance
export const bridge = new HybridBridge();

// Expose globally
(window as any).HybridBridge = bridge;
```

**File: `src/typescript/handlers.ts` (Business Logic)**

```typescript
import { bridge } from './bridge';
import { SessionContext } from './types';

// Register handlers for Dart to call

bridge.registerHandler<{ userId: string }>(
  'getUserSession',
  async (payload) => {
    const sessionId = localStorage.getItem('session_id');
    return {
      sessionId,
      userId: payload.userId,
      isAuthenticated: !!sessionId,
      expiresAt: Date.now() + 3600000,
    } as SessionContext;
  }
);

bridge.registerHandler<string>(
  'validateInput',
  (input) => {
    const isValid = input.length > 0 && input.length < 1000;
    return { valid: isValid };
  }
);

bridge.registerHandler<{ token: string }>(
  'setAuthToken',
  (payload) => {
    localStorage.setItem('auth_token', payload.token);
    bridge.emit('authTokenChanged', { token: payload.token });
    return { success: true };
  }
);

// Export for testing
export function initializeHandlers(): void {
  console.log('[Bridge] Handlers initialized');
}
```

### 4.4 Injection dans Flutter

```dart
// In your WebView creation widget

onLoadStop: (controller, url) async {
  // Inject the compiled TypeScript bundle
  await controller.injectJavascriptFileFromAsset(
    assetFilePath: 'assets/js/bridge.min.js'
  );

  // Verify bridge is available
  final bridgeVersion = await controller.evaluateJavascript(
    source: 'window.HybridBridge.getVersion()'
  );
  
  logger.info('Injected HybridBridge v$bridgeVersion');
},

// Now you can use the bridge from Dart:
onWebViewCreated: (controller) {
  controller.addJavaScriptHandler(
    handlerName: 'getUserSession',
    callback: (JavaScriptHandlerFunctionData data) {
      // Dart handler called from TypeScript
      return {
        'userId': '12345',
        'sessionId': getStoredSessionId(),
      };
    }
  );
}
```

### 4.5 Avantages de Cette Approche

| Aspect | Bénéfice |
|--------|----------|
| **Type Safety** | TypeScript compile-time checks, moins de bugs runtime |
| **Single Bundle** | 1 fichier injected = latency réduite, caching optimal |
| **Minification** | esbuild produit ~5-10KB minified, significativement optimisé |
| **Source Maps** | Debugging facile en dev (stack traces map back to .ts) |
| **Séparation Concerns** | Bridge code isolé du code métier, réutilisable |
| **Testing** | TypeScript testable en isolation (Jest/Vitest) |

### 4.6 Préparation Assets Flutter

**File: `pubspec.yaml`**

```yaml
flutter:
  assets:
    - assets/js/bridge.min.js
    - assets/js/bridge.js.map  # Optional, for debugging
```

**Build Setup** :
```bash
# Copy transpiled output to Flutter assets
cp dist/bridge.min.js ./flutter/assets/js/
cp dist/bridge.js.map ./flutter/assets/js/
```

---

## 5. Contrat API du Pont

### 5.1 Format de Messages Standard

```typescript
// All messages follow this envelope for consistency

interface MessageEnvelope {
  // Globally unique message identifier
  id: string;                    // Format: "msg_{counter}_{timestamp}"
  
  // Message type for routing
  type: 'request' | 'response' | 'event';
  
  // Action/handler name (snake_case)
  action: string;                // e.g., "get_user_profile", "auth:login"
  
  // Payload (can be null)
  payload: Record<string, unknown> | null;
  
  // ISO 8601 timestamp
  timestamp: string;             // e.g., "2025-11-02T14:30:00.123Z"
  
  // Origin of message
  source: 'dart' | 'javascript';
  
  // For responses only
  success?: boolean;
  result?: unknown;
  error?: {
    code: string;               // e.g., "AUTH_FAILED", "NETWORK_ERROR"
    message: string;
    details?: Record<string, unknown>;
  };
}
```

### 5.2 Conventions de Nommage

#### **Action Names**
```
format: {namespace}:{operation}  or  {namespace}_{operation}

Examples:
✓ "auth:login"
✓ "auth:logout"
✓ "user:get_profile"
✓ "session:refresh_token"
✓ "ui:show_loading"
✓ "analytics:track_event"

Namespaces (suggested):
- auth (authentication)
- user (user profile/data)
- session (session management)
- ui (user interface commands)
- analytics (event tracking)
- error (error reporting)
```

#### **Field Names in Payload**
```
Use camelCase for consistency with JavaScript conventions

✓ { userId: "123", isActive: true }
✗ { user_id: "123", is_active: true }
```

### 5.3 Handlers du Pont Clés

#### **Session Management Handlers**

```typescript
// Request session info
bridge.registerHandler<{}>(
  'session:get_info',
  async () => {
    return {
      sessionId: localStorage.getItem('session_id'),
      userId: localStorage.getItem('user_id'),
      expiresAt: parseInt(localStorage.getItem('session_expiry') || '0'),
    };
  }
);

// Refresh session (call before expiry)
bridge.registerHandler<{ refreshToken: string }>(
  'session:refresh',
  async (payload) => {
    // Call backend API
    const response = await fetch('/api/session/refresh', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken: payload.refreshToken }),
    });
    
    const data = await response.json();
    localStorage.setItem('session_id', data.sessionId);
    localStorage.setItem('session_expiry', data.expiresAt.toString());
    
    return { success: true };
  }
);

// Logout
bridge.registerHandler<{}>(
  'auth:logout',
  async () => {
    localStorage.clear();
    sessionStorage.clear();
    return { success: true };
  }
);
```

#### **Event Broadcasting Handlers**

```typescript
// Dart notifies JS of app state changes
bridge.registerHandler<{ state: string }>(
  'app:state_changed',
  (payload) => {
    console.log('App state changed:', payload.state);
    document.dispatchEvent(
      new CustomEvent('app-state-changed', { detail: payload })
    );
    return { acknowledged: true };
  }
);

// JS notifies Dart of user actions
bridge.emit('user:action_triggered', {
  actionId: 'submit_form',
  timestamp: new Date().toISOString(),
  metadata: { formId: 'contact-form' },
});
```

#### **Error Handling Handler**

```typescript
bridge.registerHandler<{ 
  code: string; 
  message: string; 
  stackTrace?: string;
}>(
  'error:report',
  async (payload) => {
    // Send error to logging service
    console.error(`[${payload.code}] ${payload.message}`);
    
    if (payload.stackTrace) {
      console.error(payload.stackTrace);
    }
    
    // Optionally send to backend error tracker
    // await sendToSentry(payload);
    
    return { received: true };
  }
);
```

### 5.4 Exemple de Flux Complet

```
User clicks "Login" button in WebView
    │
    ▼
JavaScript: bridge.emit('auth:login_requested', { username, password })
    │
    ▼
Dart receives via addJavaScriptHandler('auth:login_requested')
    │
    ▼
Dart calls backend API
    │
    ▼
Dart: window.flutter_inappwebview.callHandler(
        'auth:login_success',
        { sessionId, token }
      )
    │
    ▼
JavaScript: bridge.registerHandler('auth:login_success', (payload) => {
  localStorage.setItem('session_id', payload.sessionId);
  localStorage.setItem('auth_token', payload.token);
  navigateToHome();
})
    │
    ▼
UI updated in WebView
```

---

## 6. Considérations Platform

### 6.1 Android (API 21+)

**Minimum SDK** : API 21 (Android 5.0)  
**Target SDK** : API 34+ (required for Google Play August 2025)

**Spécificités :**

```dart
InAppWebViewSettings(
  // Android hybrid composition: affects performance
  useHybridComposition: false,  // If animation performance critical
  
  // Cookie isolation for multi-process apps (API 28+)
  // Not needed for single-process standard app
  
  // Media playback requires user gesture on some API levels
  mediaPlaybackRequiresUserGesture: false,
  
  // Enable web inspector for debugging
  isInspectable: kDebugMode,
)
```

**Cookie Behavior** :
- **API 21-27** : Standard persistence, works reliably
- **API 28+** : Stricter cleartext policy, requires HTTPS
- **All** : CookieManager is process-wide singleton

**Testing** :
```bash
# Chrome DevTools access for WebView debugging
chrome://inspect
```

### 6.2 iOS (12.0+)

**Minimum iOS** : 12.0  
**Xcode Version** : 15.0+

**Spécificités** :

```dart
InAppWebViewSettings(
  // iOS requires Xcode 15+
  // Embedded views preview still needed in older setups
  // (Already handled by flutter_inappwebview)
  
  // Inline media playback
  allowsInlineMediaPlayback: true,
  
  // iFrame permissions
  iframeAllow: 'camera; microphone',
  iframeAllowFullscreen: true,
)
```

**Cookie Behavior** :
- **iOS 11.0+** : WKHTTPCookieStore, full support
- **iOS < 11.0** : Limited support via JavaScript
- **Quirk** : Cookies sometimes don't persist after cold start → use flush workaround

**JavaScript Bridge** :
- `flutterInAppWebViewPlatformReady` event fires reliably
- No need for `AT_DOCUMENT_START` hacks (unlike Android)

### 6.3 Differences Dart/Kotlin/Swift

```dart
// Dart side
await controller.addJavaScriptHandler(
  handlerName: 'myHandler',
  callback: (JavaScriptHandlerFunctionData data) {
    // data.args: List<dynamic>
    // data.isMainFrame: bool
    // data.origin: WebUri
    return { 'result': 'value' };  // Auto JSON encoded
  }
);

// TypeScript side
window.flutter_inappwebview.callHandler(
  'myHandler',
  arg1,
  arg2
).then(result => {
  // result automatically JSON decoded
  console.log(result);
});
```

---

## 7. Implémentation Recommandée

### 7.1 Project Structure

```
flutter_app/
├── pubspec.yaml
├── assets/
│   └── js/
│       ├── bridge.min.js
│       └── bridge.js.map
│
├── lib/
│   ├── services/
│   │   ├── webview_service.dart          # Main WebView abstraction
│   │   ├── session_manager.dart          # Session persistence
│   │   ├── javascript_bridge.dart        # Bridge interface
│   │   └── cookie_persistence.dart       # Cookie management
│   │
│   ├── models/
│   │   ├── bridge_message.dart           # Type definitions
│   │   └── session.dart
│   │
│   └── screens/
│       └── webview_screen.dart           # UI implementation
│
└── typescript/
    ├── package.json
    ├── tsconfig.json
    ├── esbuild.config.js
    ├── src/
    │   ├── types.ts
    │   ├── bridge.ts
    │   ├── handlers.ts
    │   └── config.ts
    └── dist/
        └── bridge.min.js
```

### 7.2 Core Dart Implementation

```dart
// lib/services/webview_service.dart

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:async';

class WebViewService {
  static final _instance = WebViewService._internal();
  
  late InAppWebViewController _controller;
  final _bridgeReadyCompleter = Completer<void>();
  final _messageHandlers = <String, Function>{};
  
  factory WebViewService() => _instance;
  WebViewService._internal();
  
  /// Initialize WebView controller
  Future<void> initializeController(InAppWebViewController controller) async {
    _controller = controller;
    
    // Inject TypeScript bridge
    await _controller.injectJavascriptFileFromAsset(
      assetFilePath: 'assets/js/bridge.min.js'
    );
    
    // Setup message handlers
    _setupHandlers();
    
    _bridgeReadyCompleter.complete();
  }
  
  /// Wait for bridge ready
  Future<void> waitForBridge() => _bridgeReadyCompleter.future;
  
  /// Call JavaScript handler and await response
  Future<T> callJavaScript<T>(
    String action,
    [Map<String, dynamic>? payload]
  ) async {
    await waitForBridge();
    
    try {
      final result = await _controller.evaluateJavascript(
        source: '''
          (async () => {
            return await window.HybridBridge.request('$action', ${jsonEncode(payload ?? {})});
          })()
        '''
      );
      return result as T;
    } catch (e) {
      throw Exception('Bridge call failed: $action - $e');
    }
  }
  
  /// Emit event to JavaScript
  void emitEvent(String action, Map<String, dynamic> data) {
    _controller.evaluateJavascript(
      source: '''
        window.HybridBridge.emit('$action', ${jsonEncode(data)});
      '''
    );
  }
  
  /// Register handler for messages from JavaScript
  void registerHandler(String action, Function handler) {
    _messageHandlers[action] = handler;
    
    _controller.addJavaScriptHandler(
      handlerName: action,
      callback: (JavaScriptHandlerFunctionData data) {
        return handler(data.args.isNotEmpty ? data.args[0] : null);
      }
    );
  }
  
  void _setupHandlers() {
    // Example: Handle session refresh
    registerHandler('session:refresh', (payload) {
      return _refreshSession(payload);
    });
  }
  
  Future<Map<String, dynamic>> _refreshSession(dynamic payload) async {
    // Call backend, update cookies, etc.
    return { 'success': true };
  }
}
```

### 7.3 Production Checklist

- ✅ **minSdkVersion** = 21 or higher (Google Play requirement 2025)
- ✅ **TypeScript transpilation** via esbuild, minified
- ✅ **Cookie flush workaround** on app start + exit
- ✅ **CookieManager** singleton properly initialized
- ✅ **Error handling** in bridge with try-catch
- ✅ **Session token injection** after authentication
- ✅ **Test on API 21, 28, 34** (min, medium, target)
- ✅ **Test on iOS 12, 14, 17** (representative versions)
- ✅ **Source maps** bundled for debugging production issues
- ✅ **Analytics** for bridge latency/errors

---

## 8. Conclusion

**Recommandation Finale** :

L'utilisation de **flutter_inappwebview 6.x+** avec une architecture TypeScript transpilée en bundle unique, couplée à la **gestion centralisée du CookieManager/WebStorageManager** pour la persistance de session cross-WebView, fournit la base la plus robuste et pérenne pour l'AI Hybrid Hub fin 2025.

**Stratégies de Mitigation de Risque Unique Développeur** :
1. Abstraire interface WebView dans couche service isolée
2. Monitorer `webview_flutter` officiel comme fallback potentiel
3. Maintenir fork lean du repository critique
4. Documentation complète des workarounds platform spécifiques
5. Tests d'intégration automatisés sur multiple API levels

Cette spécification offre guidance complète pour implémentation production-ready.

---

**Document Version:** 1.0  
**Date de Révision Recommandée:** Novembre 2025 (ou quand flutter_inappwebview v7.0 est annoncé)

---

Recherche 3 : 


# **Spécification d'Architecture : Couche Hybride et Pont de Communication Natif-Web pour "AI Hybrid Hub"**

## **Résumé Exécutif (Executive Summary)**

Le projet "AI Hybrid Hub", une application mobile Android basée sur Flutter prévue pour fin 2025, exige une couche d'interaction hybride native-web d'une robustesse et d'une performance exceptionnelles. Les exigences fondamentales incluent une communication bi-directionnelle asynchrone, une gestion de session utilisateur transparente et persistante à travers de multiples instances $WebView$, et une maintenabilité à long terme.

Cette spécification d'architecture établit un plan technique complet pour la conception et l'implémentation de cette couche hybride. L'analyse prospective des librairies disponibles, des risques de plateformes et des besoins de l'API mène à une recommandation centrale et définitive.

**Recommandation Centrale :** L'architecture sera intégralement basée sur la librairie communautaire $flutter\\\_inappwebview$ (FIW), dans sa version 6 ou ultérieure. Ce choix est motivé par sa supériorité fonctionnelle écrasante sur la solution officielle $webview\\\_flutter$ (WVF). FIW est la seule librairie offrant un accès natif de bas niveau aux gestionnaires de session (Cookies et $LocalStorage$) et un pont de communication ($JavaScript Bridge$) bi-directionnel et asynchrone. Ces fonctionnalités ne sont pas des améliorations, mais des prérequis stricts pour atteindre les objectifs du projet.

L'architecture de persistance de session s'appuiera sur les singletons natifs $CookieManager$ et $WebStorageManager$ exposés par $flutter\\\_inappwebview$. La couche de script $WebView$ sera développée en $TypeScript$ et transpilée via $Vite$ en mode librairie, garantissant la robustesse et la sécurité de type du pont. Ce dernier sera conçu comme une interface RPC (Remote Procedure Call) asynchrone, basée sur les $Promise$, en exploitant les $JavaScriptHandler$ de $flutter\\\_inappwebview$.

Ce document détaille la justification de ces choix et fournit le plan d'implémentation technique pour l'équipe de développement.

## **I. Recommandation Stratégique : Sélection de la Librairie WebView**

### **A. Contexte et Enjeux de la Décision**

Le choix de la librairie $WebView$ est la décision architecturale la plus fondamentale pour l'AI Hybrid Hub. Elle dicte les capacités, les limites de performance et la complexité d'implémentation de l'intégralité de la couche hybride. La sélection ne peut se baser uniquement sur l'état actuel (2024), mais doit se projeter sur la trajectoire de développement et la pertinence estimée pour 2025\.1

Les critères d'évaluation critiques sont :

1. La puissance et la flexibilité du pont de communication JavaScript.  
2. La maturité et la granularité de l'API de gestion de session (Cookies et $LocalStorage$).  
3. La performance de rendu et la consommation de ressources.  
4. Le risque de maintenance et la dynamique de développement (communautaire vs. officielle).

### **B. Analyse Comparative : $flutter\\\_inappwebview$ vs. $webview\\\_flutter$**

Une analyse approfondie des deux solutions leaders mène à un constat sans équivoque.

**1\. Puissance et Flexibilité du Pont JavaScript (Bridge)**

* **$webview\\\_flutter$ (WVF) :** La solution officielle propose une communication depuis JavaScript vers Dart via des $JavascriptChannel$.3 Ce mécanisme, bien que simple à mettre en œuvre, est fondamentalement limité. Il est unidirectionnel (pour l'inverse, Dart vers JS, il faut utiliser $runJavaScript$ 6) et asynchrone de type $void$ : il ne gère pas nativement les retours de valeur.7 L'implémentation d'un appel JS attendant une réponse de Dart nécessite la mise en place manuelle d'un système complexe de *callbacks* et d'identifiants de corrélation, ce qui alourdit considérablement l'API.  
* **$flutter\\\_inappwebview$ (FIW) :** La solution communautaire propose un pont bi-directionnel natif, asynchrone et basé sur les $Promise$.8  
  * **JS \-\> Dart :** L'API $window.flutter\\\_inappwebview.callHandler('nomHandler',...args)$ retourne une $Promise$ JavaScript.9 Cette $Promise$ se résout (ou est rejetée) avec la valeur (ou l'erreur) retournée par le $handler$ Dart.8  
  * **Dart \-\> JS :** La méthode $controller.callAsyncJavaScript(...)$ permet d'appeler une fonction JavaScript qui retourne elle-même une $Promise$, et d'$await$ son résultat directement dans le code Dart.12

*Conclusion (Pont) :* $flutter\\\_inappwebview$ est architecturalement supérieur. Il permet une conception d'API propre et moderne de type RPC (Remote Procedure Call), essentielle pour les interactions complexes de l'AI Hub. $webview\\\_flutter$ impose une architecture d'Event Bus manuelle, fragile et inadaptée.

**2\. Maturité de la Gestion de Session (Cookies & Storage)**

* $webview\\\_flutter$ (WVF) : L'accès à la gestion de session est partiel. Bien qu'il expose un $WebViewCookieManager$ 14, la gestion du $LocalStorage$ est quasiment inexistante au niveau natif.14 Pour interagir avec le $LocalStorage$, le développeur est contraint d'injecter et d'exécuter du JavaScript ad-hoc (ex: $window.localStorage.setItem(...)  
  $).15 Cette approche est fragile, sujette aux "race conditions" et ne permet pas une gestion de session fiable en dehors du contexte d'une page chargée.  
* **$flutter\\\_inappwebview$ (FIW) :** Fournit un accès direct et de bas niveau aux gestionnaires singletons natifs sous-jacents 17 :  
  * $CookieManager.instance()$ : Une API complète pour gérer les cookies de l'application (lecture, écriture, suppression) au niveau natif.18  
  * $WebStorageManager.instance()$ : Une API pour gérer $LocalStorage$ et $SessionStorage$ au niveau natif, par origine.22 Cette fonctionnalité est totalement absente de WVF.17

*Conclusion (Session) :* L'exigence de persistance de session, notamment pour $LocalStorage$, *élimine* de fait $webview\\\_flutter$. $flutter\\\_inappwebview$ est la seule solution viable permettant une gestion de session native, transparente et fiable à travers plusieurs instances $WebView$.

**3\. Performance et Stabilité (Projection 2025\)**

* Historiquement, les versions 5 de FIW ont pu souffrir de signalements de saccades ($jank$) au défilement par rapport à WVF.2  
* Cependant, des rapports communautaires récents (fin 2023-2024) indiquent que $flutter\\\_inappwebview$ **version 6** est désormais "très rapide" et a résolu ces anciens problèmes de performance.2  
* Inversement, $webview\\\_flutter$ est maintenant lui-même sujet à des signalements de problèmes de performance (stutter, lag) dans des scénarios d'animations lourdes ou sur des appareils bas de gamme.25  
* L'explication est architecturale : WVF utilise $PlatformView$ pour permettre la superposition de widgets Flutter sur la $WebView$.25 Cette composition hybride ($Hybrid Composition$) a un coût de performance non négligeable. $flutter\\\_inappwebview$ privilégie la performance de la vue web elle-même.  
* De plus, FIW offre des fonctionnalités avancées cruciales pour la performance, telles que $HeadlessInAppWebView$ (vues web en arrière-plan), permettant le pré-chargement de sessions ou l'exécution de tâches IA sans interface utilisateur.28

**4\. Analyse des Risques de Maintenance (Angle Mort)**

* **Risque $flutter\\\_inappwebview$ :** Le risque identifié est le "bus factor" de 1, la maintenance reposant principalement sur un seul développeur.29 Des inquiétudes communautaires ont déjà été soulevées par le passé.31  
* **Atténuation :** Ce risque est atténué par plusieurs facteurs. L'activité du dépôt est extrêmement élevée et constante, avec des correctifs déployés pour des versions bêtas d'OS (ex: Android 15 32) et d'outils (ex: Xcode 16 33). Le plugin est massivement adopté (utilisé par plus de 40 000 projets 29) et dispose d'une documentation et d'un catalogue d'exemples 29 largement supérieurs à ceux de la solution officielle.  
* **Risque $webview\\\_flutter$ :** La maintenance est "officielle" (Google).2 Cependant, l'analyse des roadmaps publiques de Flutter 36 montre que l'accent stratégique est mis sur le moteur de rendu Impeller, le Web (WASM) et le Desktop. $webview\\\_flutter$ est un composant mature mais à faible priorité stratégique.  
* *Conclusion (Risque) :* Pour un projet complexe comme l'AI Hybrid Hub, le risque de **stagnation** et de **lenteur d'évolution** de $webview\\\_flutter$ est un risque technique *supérieur* au "bus factor" de $flutter\\\_inappwebview$. FIW évolue au rythme des besoins complexes de la communauté 17, ce qui est aligné avec les besoins du projet.

### **C. Tableau Récapitulatif et Verdict**

**Tableau 1.1 : Tableau Comparatif : $flutter\\\_inappwebview$ (v6+) vs. $webview\\\_flutter$ (v5+)**

| Critère | flutter\_inappwebview (v6+) | webview\_flutter (v5+) | Analyse de Risque/Opportunité pour AI Hub |
| :---- | :---- | :---- | :---- |
| **Pont JavaScript** | Bi-directionnel, Asynchrone ($Promise$), RPC-ready.8 | Unidirectionnel ($JavascriptChannel$), $void$.\[3, 4\] | **Critique.** FIW est le seul à permettre l'API complexe requise. |
| **Gestion Cookies** | Accès natif au singleton $CookieManager$.\[18, 20\] | Accès natif au $WebViewCookieManager$.14 | FIW offre une API plus riche et plus standard. |
| **Gestion $LocalStorage$** | Accès natif au singleton $WebStorageManager$.22 | **Aucun accès natif.** Repose sur l'injection JS.\[15\] | **Critique.** La gestion de session $LocalStorage$ est impossible avec WVF. |
| **Performance (2025)** | v6 signalée comme "très rapide", optimisée.2 | Signalements de *jank* (saccades) dus à $PlatformView$.25 | FIW est plus adapté aux contenus web complexes et lourds. |
| **Fonctionnalités Av. ($Headless$)** | Supporté ($HeadlessInAppWebView$).\[28\] | Non supporté. | **Opportunité.** FIW permet le pré-chargement et les tâches de fond. |
| **Maintenance & Risque** | "Bus factor" de 1, mais très haute vélocité.\[29, 32\] | "Officiel" (Google), mais faible priorité stratégique, évolution lente.\[36, 38\] | Le risque de stagnation de WVF est supérieur au risque de maintenance de FIW. |

---

**Verdict Stratégique : $flutter\\\_inappwebview$ (FIW)**

Pour le projet AI Hybrid Hub, l'adoption de $flutter\\\_inappwebview$ (v6+) est la seule décision architecturale viable. Les exigences de pont bi-directionnel complexe et de persistance de session $LocalStorage$ *éliminent* $webview\\\_flutter$ de la sélection, car ce dernier ne dispose tout simplement pas des API natives requises pour répondre au cahier des charges.

## **II. Architecture de la Persistance de Session Cross-WebView**

### **A. Fondations Techniques : Les Singletons Natifs**

L'architecture de persistance repose sur un fait technique fondamental : sur Android, toutes les instances de $WebView$ au sein d'une même application partagent, par défaut, un unique conteneur de données (profil).39 La gestion de session "cross-$WebView$" n'est donc pas un problème de *création* de partage, mais de *gestion* correcte de ce conteneur partagé.

$flutter\\\_inappwebview$ excelle en exposant les gestionnaires natifs singletons pour ce conteneur.18

1. **$CookieManager$ :** Gère les cookies. L'instance $CookieManager.instance()$ est un singleton qui opère sur le $CookieManager$ natif d'Android.20  
2. **$WebStorageManager$ :** Gère le $LocalStorage$ et le $SessionStorage$. L'instance $WebStorageManager.instance()$ est un singleton qui opère sur la classe $WebStorage$ native d'Android.22

Toute écriture effectuée via ces managers sera *immédiatement* disponible pour toute nouvelle $WebView$ instanciée.

### **B. Stratégie d'Implémentation des Cookies (Authentification)**

**1\. Le $CookieManager$ Singleton**

Toutes les opérations de cookies (lecture, écriture, suppression) doivent *exclusivement* passer par l'instance singleton $CookieManager cookieManager \= CookieManager.instance();$.18 Ce manager opère au niveau natif de l'application, indépendamment de toute instance de $WebView$.40

Exemple d'injection de cookie de session 18 :

Dart

// Récupération de l'instance singleton  
final CookieManager cookieManager \= CookieManager.instance();

// Injection du cookie d'authentification après un login natif  
await cookieManager.setCookie(  
  url: WebUri("https://auth.ai-hub.com"), // Domaine d'authentification  
  domain: ".ai-hub.com", // Important: le domaine parent pour le partage entre sous-domaines (ex: app.ai-hub.com)  
  name: "session\_token",  
  value: "TOKEN\_JWT\_OU\_OPAQUE\_RECU",  
  expiresDate: DateTime.now().add(Duration(days: 30)).millisecondsSinceEpoch,  
  isSecure: true,  
  sameSite: SameSitePolicy.LAX, // Utiliser LAX ou STRICT. Éviter NONE si possible.  
);

Une fois ce code exécuté, toute $WebView$ chargeant une page depuis $\*.ai-hub.com$ inclura automatiquement ce cookie.

**2\. Analyse des Risques Android (Angles Morts)**

* **Risque 1 : Cookies Tiers (Third-Party Cookies)**  
  * *Problème :* Android, en particulier depuis $Lollipop$ (API 21+), désactive par défaut l'acceptation des cookies tiers dans les $WebView$.41 Si la $WebView$ principale (ex: $app.ai-hub.com$) charge un $iframe$ ou initie une redirection vers un autre domaine (ex: $auth.ai-hub.com$ ou un fournisseur d'identité) qui doit déposer un cookie, cette opération échouera silencieusement.  
  * *Solution :* $flutter\\\_inappwebview$ permet un contrôle fin par $WebView$. Il est impératif d'activer programmatiquement l'acceptation des cookies tiers sur l'instance du contrôleur Android.43  
  * *Code (via $AndroidInAppWebViewController$) :*  
    Dart  
    InAppWebView(  
      onWebViewCreated: (controller) {  
        // Permet à la WebView d'accepter les cookies de domaines tiers  
        controller.android.setAcceptThirdPartyCookies(true);  
      },  
      //...  
    )

  * *Projection 2025 :* Bien que Google Chrome supprime activement les cookies tiers sur le web ouvert, cette politique, à ce jour, n'affecte pas $WebView$.46 $WebView$ reste sous le contrôle de l'application embarquée, qui peut explicitement autoriser ce comportement.  
* **Risque 2 : Disparités des Niveaux d'API (Angle Mort)**  
  * *Problème :* Le comportement de $WebView$ n'est pas monolithique ; il évolue avec les niveaux d'API Android.47 Par exemple, la gestion du mode sombre via $setForceDark()$ est dépréciée à l'API 33 en faveur de la *media query* $prefers-color-scheme$.47 Des bugs de rendu, de performance ou de clavier peuvent apparaître spécifiquement sur certaines versions.32  
  * *Solution :* L'utilisation de $flutter\\\_inappwebview$ v6+ est la première ligne de défense, car sa communauté active maintient des correctifs pour les versions Android récentes.32 L'architecture doit cependant prévoir des tests de régression automatisés et manuels sur les API cibles minimales (ex: 29\) et cibles (ex: 33+). Les problèmes de compatibilité de $CookieManager$ 52 sont souvent liés à des configurations de $build$ Android (Gradle) plutôt qu'à la librairie elle-même.

### **C. Stratégie d'Implémentation du $LocalStorage$ (Données d'Application Web)**

**1\. Le $WebStorageManager$ Singleton**

* *Principe :* $LocalStorage$ est, par définition de la spécification web, lié à une **origine** (schéma \+ domaine \+ port). Il ne peut pas être "partagé" entre $domainA.com$ et $domainB.com$.  
* *Objectif :* L'objectif n'est pas de *partager* le $LocalStorage$ (ce qui est impossible), mais de le *gérer* et de le *persister* de manière centralisée depuis Dart.  
* *Solution :* $flutter\\\_inappwebview$ est la seule librairie à offrir cette capacité via $WebStorageManager.instance()$.22 $webview\\\_flutter$ ne le permet pas.14  
* Cette API permet à Dart (l'application native) de lire et écrire dans le $LocalStorage$ de n'importe quelle origine, contournant ainsi la "Same-Origin Policy" depuis la couche native.

*Exemple (FIW) :*

Dart

// Récupération de l'instance singleton  
final WebStorageManager webStorageManager \= WebStorageManager.instance();  
final String targetOrigin \= "https://feature1.ai-hub.com";

// Écriture de données dans le LocalStorage d'une origine spécifique DEPUIS DART  
// Permet de "pré-chauffer" une WebView  
await webStorageManager.android.setLocalStorageItem(  
  origin: targetOrigin,  
  key: "user-preferences",  
  value: '{"theme":"dark", "featureFlags": \["beta"\]}'  
);

// Lecture des données d'une origine spécifique  
String? prefs \= await webStorageManager.android.getLocalStorageItem(  
  origin: targetOrigin,  
  key: "user-preferences"  
);

**2\. Cas d'Usage : Synchronisation de Données (Proxy via Bridge)**

Si un partage de données *non-cookie* entre *différentes* origines est requis (ex: un état d'interface partagé entre $featureA.ai-hub.com$ et $featureB.ai-hub.com$), $LocalStorage$ est le mauvais outil.

*Solution :* L'application Flutter (Dart) doit agir comme un "proxy de données" ou un "bus d'état" central.

*Flux :*

1. **$WebView$ A ($domainA.com$)** veut partager une donnée $data$.  
2. **JS (WebView A) :** $window.native.storage.setItem('sharedKey', data)$ \-\> Appel $callHandler$ (voir Section IV).  
3. **Dart :** Le $handler$ $storage:setItem$ reçoit $data$ et le stocke dans une variable Dart (ex: dans un $ChangeNotifier$, $Bloc$, ou $Riverpod Provider$).  
4. **Dart :** L'état étant mis à jour, l'application peut notifier $WebView$ B (si elle est active) : $controllerB.callAsyncJavaScript('window.web.storage.receiveUpdate('sharedKey', data)')$.  
5. **JS (WebView B) :** Reçoit $data$ et le stocke dans son *propre* $LocalStorage$ ou met à jour son état React/Vue/etc.

Cette architecture est robuste, explicite, et n'est possible qu'avec le pont RPC asynchrone de $flutter\\\_inappwebview$.

## **III. Blueprint de l'Outillage (Toolchain) Web Hybride**

### **A. Validation de l'Approche $TypeScript$**

Le code injecté dans la $WebView$ n'est pas un simple script ; il constitue une *API* à part entière.

* Problème : L'injection de chaînes de caractères JavaScript (ex: $controller.runJavaScript(...)  
  $) 54 ou même de $UserScript$ non gérés 55 est fragile, non typée, et devient rapidement inmaintenable.  
* *Solution :* $TypeScript$ (TS).56 Le code du pont sera écrit en $TypeScript$ puis transpilé en JavaScript avant d'être injecté.  
* *Avantages :*  
  1. **Sécurité de Type :** Le contrat d'API (ex: $window.native.auth.getToken(): Promise\<string\>$) est défini et vérifié statiquement à la compilation.57  
  2. **Robustesse :** Réduit drastiquement les erreurs d'exécution ($runtime errors$) dans la $WebView$.59  
  3. **Maintenabilité :** Permet une refactorisation sûre, l'auto-complétion et une meilleure intégration des développeurs.59  
  4. **Design-First :** Permet de définir l'API du pont (les interfaces TS) avant même l'implémentation native, servant de contrat.62

### **B. Configuration de Référence : $Vite$ en Mode Librairie**

* *Objectif :* Transpiler et bundler tout le code $TypeScript$ du pont en un **fichier JavaScript unique, minifié et auto-exécutable** (format IIFE).  
* *Outil :* $Vite$ en "Mode Librairie" ($build.lib$) 63 est l'outil moderne de référence pour cet usage. Il utilise $esbuild$ 61 pour une transpilation quasi-instantanée.

*Exemple de configuration $vite.config.ts$ pour le projet de pont :*

TypeScript

import { defineConfig } from 'vite';  
import { resolve } from 'path';

// \[71, 72, 73, 74\]  
export default defineConfig({  
  build: {  
    // Configuration du mode librairie   
    lib: {  
      // Point d'entrée de notre API TypeScript (ex: src/main.ts)  
      entry: resolve(\_\_dirname, 'src/main.ts'),   
        
      // Nom de la variable globale exposée  
      // (ex: window.AIHubNativeBridge)  
      name: 'AIHubNativeBridge',   
        
      // 'iife' (Immediately Invoked Function Expression)   
      // est le format idéal pour l'injection via UserScript.  
      formats: \['iife'\],   
        
      // Nom du fichier de sortie (ex: dist/bridge-bundle.js)  
      fileName: 'bridge-bundle',   
    },  
    outDir: 'dist',  
    // Utiliser esbuild pour la minification (plus rapide que terser)  
    minify: 'esbuild',   
    emptyOutDir: true,  
    rollupOptions: {  
      // S'assurer qu'aucune dépendance (ex: lodash)   
      // n'est externalisée. Tout doit être dans le bundle.  
      external:,  
        
      output: {  
        // Garantit un fichier unique en désactivant   
        // le "code splitting" de Rollup \[64\]  
        manualChunks: undefined,   
      },  
    },  
  },  
});

Ce fichier de configuration générera un unique $dist/bridge-bundle.js$ prêt à être injecté.

### **C. Stratégie d'Injection : $UserScript$ à $AT\\\_DOCUMENT\\\_START$**

* *Problème :* Le pont de communication doit être disponible *immédiatement* pour le code JavaScript de la page web. Attendre l'événement $onLoadStop$ (chargement complet de la page) 65 est trop tardif et créera une "race condition".  
* *Solution :* $flutter\\\_inappwebview$ fournit la classe $UserScript$.55  
* *Implémentation :* Le $bridge-bundle.js$ généré par $Vite$ sera chargé depuis les *assets* Flutter et injecté via un $UserScript$ avec le temps d'injection $UserScriptInjectionTime.AT\\\_DOCUMENT\\\_START$.  
* *Flux d'implémentation :*  
  1. **Bundling :** $vite build$ génère $dist/bridge-bundle.js$.  
  2. **Assets :** Ce fichier est copié dans le répertoire $assets/js/bridge-bundle.js$ du projet Flutter et déclaré dans $pubspec.yaml$.  
  3. **Injection (Dart) :**

Dart  
import 'package:flutter/services.dart' show rootBundle;  
import 'package:flutter\_inappwebview/flutter\_inappwebview.dart';

// Cette opération doit être faite au démarrage de l'application   
// ou avant la création de la WebView pour éviter les délais.  
final String bridgeScriptSource \= await rootBundle.loadString('assets/js/bridge-bundle.js');

// Créer l'objet UserScript  
final UserScript bridgeUserScript \= UserScript(  
  source: bridgeScriptSource,  
  // Injection au début de la création du document   
  injectionTime: UserScriptInjectionTime.AT\_DOCUMENT\_START,   
  // S'assurer que le script n'est injecté que dans le frame principal \[67\]  
  forMainFrameOnly: true   
);

//... Dans le widget...

InAppWebView(  
  // Injecter le script  
  initialUserScripts: UnmodifiableListView\<UserScript\>(),  
  //... autres options  
);

* *Résultat :* $window.AIHubNativeBridge$ (ou tout ce qui est exposé dans $src/main.ts$) est garanti d'exister avant l'exécution de tout autre script sur la page web.

## **IV. Conception du Contrat d'API et du Pont de Communication (Bridge)**

### **A. Principes de Conception : RPC Asynchrone**

L'architecture du pont *ne doit pas* être un simple "message bus" 6 où Dart et JS échangent des objets JSON génériques avec une clé $type: "eventName"$. Cette approche est verbeuse, non typée et difficile à maintenir.

Nous adoptons un pattern **RPC (Remote Procedure Call)**.62 Le code Dart et le code $TypeScript$ s'appellent mutuellement comme s'ils appelaient des fonctions locales asynchrones.

* La communication est **bi-directionnelle**.  
* La communication est **asynchrone** (basée sur les $Promise$ / $Future$).  
* La gestion des erreurs est explicite (utilisation de $try/catch$ sur les $Promise$ JS et les $Future$ Dart).

### **B. Implémentation du Pont (Pattern RPC)**

**1\. Côté Web (TypeScript \- $src/main.ts$)**

Le code $TypeScript$ expose une API propre et typée sur l'objet $window$. Cette API sert de "façade" et encapsule la logique d'appel $callHandler$ de $flutter\\\_inappwebview$.8

TypeScript

// src/api/types.ts  
// Définition du contrat d'API (JS \-\> Dart)  
interface INativeAPI {  
  auth: {  
    /\*\*  
     \* Récupère un token d'authentification pour une audience donnée.  
     \* @param audience L'identifiant de l'audience (ex: 'ai-processor')  
     \* @returns Une Promise qui se résout avec le token JWT.  
     \*/  
    getAuthToken: (audience: string) \=\> Promise\<string\>;  
      
    /\*\*  
     \* Force le rafraîchissement de la session native.  
     \* @returns Une Promise qui se résout avec un booléen de succès.  
     \*/  
    refreshSession: () \=\> Promise\<boolean\>;  
  };  
  ai: {  
    /\*\*  
     \* Envoie un chunk de données à l'IA native pour traitement.  
     \* @param chunk Les données brutes.  
     \* @returns Une Promise qui se résout avec le chunk traité.  
     \*/  
    processChunk: (chunk: ArrayBuffer) \=\> Promise\<ArrayBuffer\>;  
  };  
  storage: { // Implémentation du proxy de stockage (voir II.C.2)  
    setItem: (key: string, value: string) \=\> Promise\<void\>;  
    getItem: (key: string) \=\> Promise\<string | null\>;  
  };  
}

// src/api/implementation.ts  
// Implémentation de la façade RPC  
const nativeAPI: INativeAPI \= {  
  auth: {  
    getAuthToken: (audience) \=\> {  
      // 'auth:getAuthToken' est le nom du handler côté Dart.  
      // callHandler retourne une Promise   
      return window.flutter\_inappwebview.callHandler('auth:getAuthToken', audience);  
    },  
    refreshSession: () \=\> {  
      return window.flutter\_inappwebview.callHandler('auth:refreshSession');  
    },  
  },  
  ai: {  
    processChunk: (chunk) \=\> {  
      // FIW gère la sérialisation des types de base comme ArrayBuffer  
      return window.flutter\_inappwebview.callHandler('ai:processChunk', chunk);  
    },  
  },  
  storage: {  
    setItem: (key, value) \=\> {  
      return window.flutter\_inappwebview.callHandler('storage:setItem', key, value);  
    },  
    getItem: (key) \=\> {  
      return window.flutter\_inappwebview.callHandler('storage:getItem', key);  
    },  
  }  
};

// src/main.ts (Point d'entrée du bundle)  
// Attendre que la plateforme FIW soit prête \[5, 10\]  
window.addEventListener("flutterInAppWebViewPlatformReady", function(event) {  
    
  // Exposer l'API globale et typée  
  (window as any).native \= nativeAPI;  
    
  // (Optionnel) Envoyer un événement pour signaler au code web   
  // que le pont TS spécifique est prêt.  
  window.dispatchEvent(new CustomEvent('nativeBridgeReady'));  
});

**2\. Côté Natif (Dart \- Flutter)**

Côté Dart, nous enregistrons les $handlers$ correspondants pour chaque action définie dans l'interface $TypeScript$. Nous utilisons le $JavaScriptHandlerFunctionData$ pour une gestion avancée des arguments.9

Dart

// Dans un service ou manager qui configure le contrôleur WebView

//   
void setupJavaScriptHandlers(InAppWebViewController controller) {  
    
  // \--- Groupe AUTH \---  
    
  controller.addJavaScriptHandler(  
    handlerName: 'auth:getAuthToken',  
    callback: (JavaScriptHandlerFunctionData data) async {  
      // data.args contient les arguments de callHandler, ici \[audience\]  
      try {  
        final String audience \= data.args as String;  
        final String token \= await \_authService.getToken(audience);  
        return token; // Cette valeur résoudra la Promise JS  
      } catch (e) {  
        // Propage l'erreur à la Promise JS, qui sera "rejetée" \[12\]  
        throw Exception('Failed to get token: $e');  
      }  
    }  
  );

  controller.addJavaScriptHandler(  
    handlerName: 'auth:refreshSession',  
    callback: (\_) async \=\> await \_authService.refreshSession()  
  );

  // \--- Groupe AI \---  
    
  controller.addJavaScriptHandler(  
    handlerName: 'ai:processChunk',  
    callback: (JavaScriptHandlerFunctionData data) async {  
      // data.args sera un Uint8List (conversion automatique de ArrayBuffer)  
      final Uint8List chunk \= data.args as Uint8List;  
      final Uint8List result \= await \_aiService.process(chunk);  
      return result; // Retourne le buffer traité  
    }  
  );

  // \--- Groupe STORAGE PROXY \---  
    
  controller.addJavaScriptHandler(  
    handlerName: 'storage:getItem',  
    callback: (JavaScriptHandlerFunctionData data) async {  
      final String key \= data.args as String;  
      return await \_secureStorage.read(key: key);  
    }  
  );  
    
  controller.addJavaScriptHandler(  
    handlerName: 'storage:setItem',  
    callback: (JavaScriptHandlerFunctionData data) async {  
      final String key \= data.args as String;  
      final String value \= data.args as String;  
      await \_secureStorage.write(key: key, value: value);  
    }  
  );  
}

//... Dans le widget InAppWebView...  
InAppWebView(  
  //...  
  initialUserScripts: UnmodifiableListView\<UserScript\>(),  
  onWebViewCreated: (controller) {  
    \_webViewController \= controller;  
    // Enregistrer tous les handlers dès la création du contrôleur  
    setupJavaScriptHandlers(controller);  
  },  
  //...  
)

### **C. Gestion des Appels Asynchrones Dart \-\> JS**

Le même pattern s'applique dans la direction Dart \-\> JS, en utilisant $callAsyncJavaScript$. Le code $TypeScript$ doit exposer une API (ex: $window.web$) que Dart peut appeler.

*Exemple (TypeScript \- à inclure dans $src/main.ts$) :*

TypeScript

// Interface pour les appels Dart \-\> JS  
interface IWebAppAPI {  
  ui: {  
    /\*\*  
     \* Affiche une modale dans le DOM de la WebView.  
     \* @returns Promise\<boolean\> (true si 'OK', false si 'Annuler')  
     \*/  
    showModal: (title: string, message: string) \=\> Promise\<boolean\>;  
  };  
}

const webAppAPI: IWebAppAPI \= {  
  ui: {  
    showModal: (title, message) \=\> {  
      // L'implémentation retourne une nouvelle Promise que la   
      // logique web (ex: un dialogue React/Vue) résoudra.  
      return new Promise((resolve) \=\> {  
        //... logique pour afficher une modale HTML...  
        //...  
        // const userClickedOK \=...;  
        // resolve(userClickedOK);  
      });  
    }  
  }  
};

// Exposer cette API sur window, dans le même listener   
// "flutterInAppWebViewPlatformReady"  
(window as any).web \= webAppAPI;

*Exemple (Dart) :*

Dart

// \[12\]  
Future\<bool\> showWebModal(String title, String message) async {  
  if (\_webViewController \== null) return false;  
    
  try {  
    // "web.ui.showModal" est le nom de la fonction globale JS  
    // "functionBody" est le script complet à exécuter  
    // Il EST CRUCIAL que functionBody retourne la Promise \[12\]  
    final String functionBody \= """  
      // arguments est 'title', arguments est 'message'  
      return window.web.ui.showModal(arguments, arguments);  
    """;  
      
    final CallAsyncJavaScriptResult? result \= await \_webViewController\!.callAsyncJavaScript(  
      functionBody: functionBody,  
      arguments: \<String, dynamic\>{'0': title, '1': message}  
    );  
      
    // result.value sera 'true' ou 'false', résolu par la Promise JS  
    return result?.value \== true;  
      
  } catch (e) {  
    // Gérer les erreurs d'exécution JS  
    print("Erreur callAsyncJavaScript: $e");  
    return false;  
  }  
}

### **D. Standardisation du Schéma de Message (Plan de Secours)**

Bien que l'approche RPC soit supérieure pour les API, un "event bus" reste utile pour les événements non critiques et "fire-and-forget" (ex: logs, analytics). Pour cela, un $handler$ unique (ex: $event:log$) peut être utilisé, mais doit adhérer à un schéma strict.69

**Tableau 4.1 : Définition du Schéma de Message Événementiel (Optionnel)**

| Clé | Type | Obligatoire | Description |
| :---- | :---- | :---- | :---- |
| $type$ | $string$ | Oui | Nom de l'événement (ex: $log$, $analytics:event$). |
| $payload$ | $any$ | Oui | La donnée JSON associée à l'événement. |
| $timestamp$ | $number$ | Oui | $Date.now()$ pour l'horodatage. |
| $requestId$ | $string$ | Non | ID de corrélation (utilisé si une réponse est attendue hors-bande). |

## **V. Synthèse Architecturale et Prochaines Étapes**

### **A. Résumé des Choix Technologiques**

Cette spécification définit une architecture hybride robuste et pérenne pour l'AI Hybrid Hub, basée sur les choix suivants :

1. **Librairie WebView :** $flutter\\\_inappwebview$ (v6+).2  
2. **Persistance de Session :** Singletons natifs $CookieManager$ 18 et $WebStorageManager$.22  
3. **Outillage (Toolchain) :** $TypeScript$ 59 \+ $Vite$ (Mode Librairie, format IIFE).71  
4. **Stratégie d'Injection :** $UserScript$ à $AT\\\_DOCUMENT\\\_START$.55  
5. **Pattern de Communication :** RPC bi-directionnel et asynchrone 8 via $callHandler$ / $callAsyncJavaScript$.

### **B. Checklist d'Intégration et Prochaines Étapes**

L'équipe de développement doit procéder comme suit :

1. **Configuration du Projet :**  
   * Intégrer $flutter\\\_inappwebview$ dans $pubspec.yaml$.  
   * Mettre à jour la configuration $build.gradle$ Android (ex: $minSdkVersion$ \>= 19, $compileSdk$ \>= 34\) conformément aux exigences.30  
2. **Mise en Place de la Toolchain Web :**  
   * Créer un sous-répertoire (ex: $webview\\\_bridge/$) pour le code $TypeScript$ du pont.  
   * Implémenter $vite.config.ts$ (selon la section III.B).  
   * Configurer $pubspec.yaml$ pour inclure le bundle JS généré (ex: $assets/js/bridge-bundle.js$).  
3. **Implémentation du Pont (Phase 1 : Contrat)**  
   * Définir les interfaces $INativeAPI$ et $IWebAppAPI$ dans un fichier $types.ts$.  
4. **Implémentation du Pont (Phase 2 : Squelette)**  
   * Implémenter les wrappers $window.native$ (en $TypeScript$) (Section IV.B.1).  
   * Implémenter les $handlers$ $addJavaScriptHandler$ (en Dart) (Section IV.B.2), en retournant des données fictives ("mocks").  
   * Valider le chargement du $UserScript$ et la disponibilité de $window.native$ dans la $WebView$.  
5. **Tests de Persistance (POC) :**  
   * Implémenter un POC avec deux $WebView$ distinctes.  
   * Scénario 1 : Écrire un cookie via $CookieManager.instance()$ 18, le lire dans les deux $WebView$.  
   * Scénario 2 : Écrire une donnée via $WebStorageManager.instance().android.setLocalStorageItem$ 23 pour $originA$, et valider sa présence au chargement de $originA$.  
6. **Tests des Risques (Angles Morts) :**  
   * Valider le scénario de cookie tiers (iframe) et l'efficacité de $setAcceptThirdPartyCookies(true)$.43  
   * Tester le POC de persistance sur des émulateurs Android avec des niveaux d'API distincts (ex: API 29 et API 33+) pour identifier tout comportement divergent.48

#### **Sources des citations**

1. Which WebView package do you prefer for your Flutter projects? : r/FlutterDev \- Reddit, consulté le novembre 2, 2025, [https://www.reddit.com/r/FlutterDev/comments/1ly1awi/which\_webview\_package\_do\_you\_prefer\_for\_your/](https://www.reddit.com/r/FlutterDev/comments/1ly1awi/which_webview_package_do_you_prefer_for_your/)  
2. webview\_flutter vs flutter\_inappwebview · Issue \#1730 \- GitHub, consulté le novembre 2, 2025, [https://github.com/pichillilorenzo/flutter\_inappwebview/issues/1730](https://github.com/pichillilorenzo/flutter_inappwebview/issues/1730)  
3. Injecting JavaScript in Flutter WebView — A Complete Guide | by KEERTHIVASAN S | NammaFlutter | Sep, 2025 | Medium, consulté le novembre 2, 2025, [https://medium.com/nammaflutter/injecting-javascript-in-flutter-webview-a-complete-guide-b7a4b4286705](https://medium.com/nammaflutter/injecting-javascript-in-flutter-webview-a-complete-guide-b7a4b4286705)  
4. Flutter WebView Bridge Integration, consulté le novembre 2, 2025, [https://docs.sauce.im/v1.1/docs/flutter-webview-integration](https://docs.sauce.im/v1.1/docs/flutter-webview-integration)  
5. Flutter Webview two way communication with Javascript \- Stack Overflow, consulté le novembre 2, 2025, [https://stackoverflow.com/questions/53689662/flutter-webview-two-way-communication-with-javascript](https://stackoverflow.com/questions/53689662/flutter-webview-two-way-communication-with-javascript)  
6. Two-Way Communication Between Flutter and WebView | by ANUPAM GUPTA \- Medium, consulté le novembre 2, 2025, [https://medium.com/wheelseye-engineering/two-way-communication-between-flutter-and-webview-730377f36f83](https://medium.com/wheelseye-engineering/two-way-communication-between-flutter-and-webview-730377f36f83)  
7. Using the JavaScript Channel in Flutter WebView to Pass Several Parameters from JavaScript to Dart | by Denis Bélanger | Medium, consulté le novembre 2, 2025, [https://medium.com/@python-javascript-php-html-css/using-the-javascript-channel-in-flutter-webview-to-pass-several-parameters-from-javascript-to-dart-049687e8e94e](https://medium.com/@python-javascript-php-html-css/using-the-javascript-channel-in-flutter-webview-to-pass-several-parameters-from-javascript-to-dart-049687e8e94e)  
8. Flutter WebView JavaScript Communication — InAppWebView 5 \- Medium, consulté le novembre 2, 2025, [https://medium.com/flutter-community/flutter-webview-javascript-communication-inappwebview-5-403088610949](https://medium.com/flutter-community/flutter-webview-javascript-communication-inappwebview-5-403088610949)  
9. Javascript WebView Communication \- InAppWebView, consulté le novembre 2, 2025, [https://inappwebview.dev/docs/webview/javascript/communication/](https://inappwebview.dev/docs/webview/javascript/communication/)  
10. Javascript WebView Communication \- InAppWebView, consulté le novembre 2, 2025, [https://inappwebview.dev/docs/5.x.x/webview/javascript/communication/](https://inappwebview.dev/docs/5.x.x/webview/javascript/communication/)  
11. \[iOS\] JS method handler doesn't resolve when InAppWebView is used with window ID · Issue \#2623 · pichillilorenzo/flutter\_inappwebview \- GitHub, consulté le novembre 2, 2025, [https://github.com/pichillilorenzo/flutter\_inappwebview/issues/2623](https://github.com/pichillilorenzo/flutter_inappwebview/issues/2623)  
12. Javascript Injection \- InAppWebView, consulté le novembre 2, 2025, [https://inappwebview.dev/docs/5.x.x/webview/javascript/injection/](https://inappwebview.dev/docs/5.x.x/webview/javascript/injection/)  
13. InAppWebViewController class \- flutter\_inappwebview library \- Dart API \- Pub.dev, consulté le novembre 2, 2025, [https://pub.dev/documentation/flutter\_inappwebview/latest/flutter\_inappwebview/InAppWebViewController-class.html](https://pub.dev/documentation/flutter_inappwebview/latest/flutter_inappwebview/InAppWebViewController-class.html)  
14. webview\_flutter | Flutter package \- Pub.dev, consulté le novembre 2, 2025, [https://pub.dev/packages/webview\_flutter](https://pub.dev/packages/webview_flutter)  
15. \[WebView\] Provide webview\_flutter a way to enable localStorage · Issue \#146274 \- GitHub, consulté le novembre 2, 2025, [https://github.com/flutter/flutter/issues/146274](https://github.com/flutter/flutter/issues/146274)  
16. android webview \- Flutter webivew how to set local storage \- Stack Overflow, consulté le novembre 2, 2025, [https://stackoverflow.com/questions/50960945/flutter-webivew-how-to-set-local-storage](https://stackoverflow.com/questions/50960945/flutter-webivew-how-to-set-local-storage)  
17. Exploring the Flutter InAppWebView Package: A Powerful Tool for Web Content Integration, consulté le novembre 2, 2025, [https://www.dhiwise.com/post/exploring-the-flutter-inappwebview-package](https://www.dhiwise.com/post/exploring-the-flutter-inappwebview-package)  
18. InAppWebView: The Real Power of WebViews in Flutter | by Lorenzo Pichilli \- Medium, consulté le novembre 2, 2025, [https://medium.com/flutter-community/inappwebview-the-real-power-of-webviews-in-flutter-c6d52374209d](https://medium.com/flutter-community/inappwebview-the-real-power-of-webviews-in-flutter-c6d52374209d)  
19. Passing cookie and session storage values to an in-app webview in Flutter \- Medium, consulté le novembre 2, 2025, [https://medium.com/@sonawanedipak111/passing-cookie-and-session-storage-values-to-an-in-app-webview-in-flutter-276cb19a2f7a](https://medium.com/@sonawanedipak111/passing-cookie-and-session-storage-values-to-an-in-app-webview-in-flutter-276cb19a2f7a)  
20. Cookie Manager \- InAppWebView, consulté le novembre 2, 2025, [https://inappwebview.dev/docs/5.x.x/cookie-manager/](https://inappwebview.dev/docs/5.x.x/cookie-manager/)  
21. Cookie Manager \- InAppWebView, consulté le novembre 2, 2025, [https://inappwebview.dev/docs/cookie-manager/](https://inappwebview.dev/docs/cookie-manager/)  
22. Web Storage Manager \- InAppWebView, consulté le novembre 2, 2025, [https://inappwebview.dev/docs/5.x.x/web-storage-manager/](https://inappwebview.dev/docs/5.x.x/web-storage-manager/)  
23. Web Storage Manager | InAppWebView, consulté le novembre 2, 2025, [https://inappwebview.dev/docs/web-storage-manager/](https://inappwebview.dev/docs/web-storage-manager/)  
24. Compare to webview\_flutter, inappwebview is significant frame dropped while page scrolling · Issue \#1386 · pichillilorenzo/flutter\_inappwebview \- GitHub, consulté le novembre 2, 2025, [https://github.com/pichillilorenzo/flutter\_inappwebview/issues/1386](https://github.com/pichillilorenzo/flutter_inappwebview/issues/1386)  
25. Flutter WebView performance issues : r/flutterhelp \- Reddit, consulté le novembre 2, 2025, [https://www.reddit.com/r/flutterhelp/comments/1mpvwj8/flutter\_webview\_performance\_issues/](https://www.reddit.com/r/flutterhelp/comments/1mpvwj8/flutter_webview_performance_issues/)  
26. Which is better between webview\_flutter vs flutter\_webview\_plugin \- Stack Overflow, consulté le novembre 2, 2025, [https://stackoverflow.com/questions/55949409/which-is-better-between-webview-flutter-vs-flutter-webview-plugin](https://stackoverflow.com/questions/55949409/which-is-better-between-webview-flutter-vs-flutter-webview-plugin)  
27. Adding WebView to your Flutter app \- Google Codelabs, consulté le novembre 2, 2025, [https://codelabs.developers.google.com/codelabs/flutter-webview](https://codelabs.developers.google.com/codelabs/flutter-webview)  
28. cropsly/flutter\_inappwebview \- GitHub, consulté le novembre 2, 2025, [https://github.com/cropsly/flutter\_inappwebview](https://github.com/cropsly/flutter_inappwebview)  
29. pichillilorenzo/flutter\_inappwebview: A Flutter plugin that allows you to add an inline webview, to use a headless webview, and to open an in-app browser window. \- GitHub, consulté le novembre 2, 2025, [https://github.com/pichillilorenzo/flutter\_inappwebview](https://github.com/pichillilorenzo/flutter_inappwebview)  
30. flutter\_inappwebview | Flutter package \- Pub.dev, consulté le novembre 2, 2025, [https://pub.dev/packages/flutter\_inappwebview](https://pub.dev/packages/flutter_inappwebview)  
31. Has development stopped? · Issue \#1589 · pichillilorenzo/flutter\_inappwebview \- GitHub, consulté le novembre 2, 2025, [https://github.com/pichillilorenzo/flutter\_inappwebview/issues/1589](https://github.com/pichillilorenzo/flutter_inappwebview/issues/1589)  
32. Issues · pichillilorenzo/flutter\_inappwebview \- GitHub, consulté le novembre 2, 2025, [https://github.com/pichillilorenzo/flutter\_inappwebview/issues](https://github.com/pichillilorenzo/flutter_inappwebview/issues)  
33. Fixing Xcode 16 Issue: Forked flutter\_inappwebview and my\_fatoorah as Workarounds | by Mahmoud El Shenawy | Medium, consulté le novembre 2, 2025, [https://medium.com/@dev-mahmoud-elshenawy/fixing-xcode-16-issue-forked-flutter-inappwebview-and-my-fatoorah-as-workarounds-bcb96d97f601](https://medium.com/@dev-mahmoud-elshenawy/fixing-xcode-16-issue-forked-flutter-inappwebview-and-my-fatoorah-as-workarounds-bcb96d97f601)  
34. InAppWebView: The Real Power of WebViews in Flutter \- DEV Community, consulté le novembre 2, 2025, [https://dev.to/pichillilorenzo/inappwebview-the-real-power-of-webviews-in-flutter-h9o](https://dev.to/pichillilorenzo/inappwebview-the-real-power-of-webviews-in-flutter-h9o)  
35. pichillilorenzo/flutter\_inappwebview\_examples: A ... \- GitHub, consulté le novembre 2, 2025, [https://github.com/pichillilorenzo/flutter\_inappwebview\_examples](https://github.com/pichillilorenzo/flutter_inappwebview_examples)  
36. Flutter 2025 Roadmap: Everything You Need to Know About the Future of Flutter \- Medium, consulté le novembre 2, 2025, [https://medium.com/@heshamerfan97/flutter-2025-roadmap-everything-you-need-to-know-about-the-future-of-flutter-2d9b7934dc00](https://medium.com/@heshamerfan97/flutter-2025-roadmap-everything-you-need-to-know-about-the-future-of-flutter-2d9b7934dc00)  
37. Roadmap \- Flutter Wiki \- GitHub, consulté le novembre 2, 2025, [https://github.com/flutter/flutter/wiki/roadmap](https://github.com/flutter/flutter/wiki/roadmap)  
38. Flutter 2025 roadmap update. Transparency is a core goal of the… | by Michael Thomsen, consulté le novembre 2, 2025, [https://blog.flutter.dev/flutter-2025-roadmap-update-f127882b117f](https://blog.flutter.dev/flutter-2025-roadmap-update-f127882b117f)  
39. Synchronization of native and WebView sessions with iOS | by Paul Hackenberger | Axel Springer Tech | Medium, consulté le novembre 2, 2025, [https://medium.com/axel-springer-tech/synchronization-of-native-and-webview-sessions-with-ios-9fe2199b44c9](https://medium.com/axel-springer-tech/synchronization-of-native-and-webview-sessions-with-ios-9fe2199b44c9)  
40. CookieManager Class (Android.Webkit) \- Microsoft Learn, consulté le novembre 2, 2025, [https://learn.microsoft.com/en-us/dotnet/api/android.webkit.cookiemanager?view=net-android-35.0](https://learn.microsoft.com/en-us/dotnet/api/android.webkit.cookiemanager?view=net-android-35.0)  
41. android.webkit.CookieManager \- Documentation \- HCL Software Open Source, consulté le novembre 2, 2025, [http://opensource.hcltechsw.com/volt-mx-native-function-docs/Android/android.webkit-Android-10.0/\#\!/api/android.webkit.CookieManager](http://opensource.hcltechsw.com/volt-mx-native-function-docs/Android/android.webkit-Android-10.0/#!/api/android.webkit.CookieManager)  
42. Enable Third party cookies for Android WebView \- Stack Overflow, consulté le novembre 2, 2025, [https://stackoverflow.com/questions/35200243/enable-third-party-cookies-for-android-webview](https://stackoverflow.com/questions/35200243/enable-third-party-cookies-for-android-webview)  
43. \[webview\_flutter\]\[android\] Support CookieManager.setAcceptThirdPartyCookies on webview\_flutter · Issue \#97365 · flutter/flutter \- GitHub, consulté le novembre 2, 2025, [https://github.com/flutter/flutter/issues/97365](https://github.com/flutter/flutter/issues/97365)  
44. CookieManager.SetAcceptThirdPartyCookies(WebView, Boolean) Method (Android.Webkit), consulté le novembre 2, 2025, [https://learn.microsoft.com/en-us/dotnet/api/android.webkit.cookiemanager.setacceptthirdpartycookies?view=net-android-35.0](https://learn.microsoft.com/en-us/dotnet/api/android.webkit.cookiemanager.setacceptthirdpartycookies?view=net-android-35.0)  
45. WebView and Cookies on Android \- Stack Overflow, consulté le novembre 2, 2025, [https://stackoverflow.com/questions/2566485/webview-and-cookies-on-android](https://stackoverflow.com/questions/2566485/webview-and-cookies-on-android)  
46. Android Web View \- 3rd party cookie testing · Issue \#388 · privacysandbox/privacy-sandbox-dev-support \- GitHub, consulté le novembre 2, 2025, [https://github.com/privacysandbox/privacy-sandbox-dev-support/issues/388](https://github.com/privacysandbox/privacy-sandbox-dev-support/issues/388)  
47. Behavior changes: Apps targeting Android 13 or higher, consulté le novembre 2, 2025, [https://developer.android.com/about/versions/13/behavior-changes-13](https://developer.android.com/about/versions/13/behavior-changes-13)  
48. App working as expected in API 29, but not in API 33 \- Stack Overflow, consulté le novembre 2, 2025, [https://stackoverflow.com/questions/75418890/app-working-as-expected-in-api-29-but-not-in-api-33](https://stackoverflow.com/questions/75418890/app-working-as-expected-in-api-29-but-not-in-api-33)  
49. How do you deal with google play making api 33 a required target? : r/androiddev \- Reddit, consulté le novembre 2, 2025, [https://www.reddit.com/r/androiddev/comments/1buc3b9/how\_do\_you\_deal\_with\_google\_play\_making\_api\_33\_a/](https://www.reddit.com/r/androiddev/comments/1buc3b9/how_do_you_deal_with_google_play_making_api_33_a/)  
50. \[Android\] Webview was very slow in flutter SDK 3.27.x · Issue \#2468 · pichillilorenzo/flutter\_inappwebview \- GitHub, consulté le novembre 2, 2025, [https://github.com/pichillilorenzo/flutter\_inappwebview/issues/2468](https://github.com/pichillilorenzo/flutter_inappwebview/issues/2468)  
51. flutter\_inappwebview changelog | Flutter package \- Pub.dev, consulté le novembre 2, 2025, [https://pub.dev/packages/flutter\_inappwebview/changelog](https://pub.dev/packages/flutter_inappwebview/changelog)  
52. Error using Flutter Webview Cookie Manager \- Stack Overflow, consulté le novembre 2, 2025, [https://stackoverflow.com/questions/79422120/error-using-flutter-webview-cookie-manager](https://stackoverflow.com/questions/79422120/error-using-flutter-webview-cookie-manager)  
53. Flutter Webview 4.0.2's WebViewCookieManager.setCoookie does not work for IOS apps \#123179 \- GitHub, consulté le novembre 2, 2025, [https://github.com/flutter/flutter/issues/123179](https://github.com/flutter/flutter/issues/123179)  
54. JS Injection to Flutter via WebView \- javascript \- Stack Overflow, consulté le novembre 2, 2025, [https://stackoverflow.com/questions/79413909/js-injection-to-flutter-via-webview](https://stackoverflow.com/questions/79413909/js-injection-to-flutter-via-webview)  
55. Javascript User Scripts | InAppWebView, consulté le novembre 2, 2025, [https://inappwebview.dev/docs/5.x.x/webview/javascript/user-scripts/](https://inappwebview.dev/docs/5.x.x/webview/javascript/user-scripts/)  
56. TypeScript in Flutter WebView \- javascript \- Stack Overflow, consulté le novembre 2, 2025, [https://stackoverflow.com/questions/74859017/typescript-in-flutter-webview](https://stackoverflow.com/questions/74859017/typescript-in-flutter-webview)  
57. Why TypeScript is Better Than Vanilla JavaScript: A Technical Deep Dive 🛠️, consulté le novembre 2, 2025, [https://dev.to/hamzakhan/why-typescript-is-better-than-vanilla-javascript-a-technical-deep-dive-1h4h](https://dev.to/hamzakhan/why-typescript-is-better-than-vanilla-javascript-a-technical-deep-dive-1h4h)  
58. What is TypeScript and why should I use it instead of JavaScript? \[closed\] \- Stack Overflow, consulté le novembre 2, 2025, [https://stackoverflow.com/questions/12694530/what-is-typescript-and-why-should-i-use-it-instead-of-javascript](https://stackoverflow.com/questions/12694530/what-is-typescript-and-why-should-i-use-it-instead-of-javascript)  
59. Exploring the Benefits of TypeScript for Large-Scale JavaScript Projects \- Blue Coding, consulté le novembre 2, 2025, [https://www.bluecoding.com/post/exploring-the-benefits-of-typescript-for-large-scale-javascript-projects](https://www.bluecoding.com/post/exploring-the-benefits-of-typescript-for-large-scale-javascript-projects)  
60. TypeScript vs JavaScript Differences \- 2025 \- Aalpha Information Systems, consulté le novembre 2, 2025, [https://www.aalpha.net/blog/typescript-vs-javascript-differences/](https://www.aalpha.net/blog/typescript-vs-javascript-differences/)  
61. An ESBuild Setup for TypeScript \- EisenbergEffect \- Medium, consulté le novembre 2, 2025, [https://eisenbergeffect.medium.com/an-esbuild-setup-for-typescript-3b24852479fe](https://eisenbergeffect.medium.com/an-esbuild-setup-for-typescript-3b24852479fe)  
62. How I Use TypeScript to Design Reliable APIs (Before Writing a Single Line of Backend Code) | by Kavindu Kokila (Kavi Castelo) | JavaScript in Plain English, consulté le novembre 2, 2025, [https://javascript.plainenglish.io/how-i-use-typescript-to-design-reliable-apis-before-writing-a-single-line-of-backend-code-1f3e5f3d2e30](https://javascript.plainenglish.io/how-i-use-typescript-to-design-reliable-apis-before-writing-a-single-line-of-backend-code-1f3e5f3d2e30)  
63. Building for Production \- Vite, consulté le novembre 2, 2025, [https://vite.dev/guide/build](https://vite.dev/guide/build)  
64. Run some Javascript in Flutter Webview \- Stack Overflow, consulté le novembre 2, 2025, [https://stackoverflow.com/questions/50350001/run-some-javascript-in-flutter-webview](https://stackoverflow.com/questions/50350001/run-some-javascript-in-flutter-webview)  
65. Local Storage property does not work in Flutter Webview Plug-in \- Stack Overflow, consulté le novembre 2, 2025, [https://stackoverflow.com/questions/60335677/local-storage-property-does-not-work-in-flutter-webview-plug-in](https://stackoverflow.com/questions/60335677/local-storage-property-does-not-work-in-flutter-webview-plug-in)  
66. Injecting JavaScript in Flutter Web View With User Scripts \- Better Programming, consulté le novembre 2, 2025, [https://betterprogramming.pub/webview-javascript-injection-with-user-scripts-flutter-inappwebview-6-46d9969353a4](https://betterprogramming.pub/webview-javascript-injection-with-user-scripts-flutter-inappwebview-6-46d9969353a4)  
67. Javascript User Scripts | InAppWebView, consulté le novembre 2, 2025, [https://inappwebview.dev/docs/webview/javascript/user-scripts/](https://inappwebview.dev/docs/webview/javascript/user-scripts/)  
68. Building a robust mobile to webview bridge with RxJS and Redux \- GoDaddy Blog, consulté le novembre 2, 2025, [https://www.godaddy.com/resources/news/mobile-to-webview-bridge-with-rxjs-and-redux](https://www.godaddy.com/resources/news/mobile-to-webview-bridge-with-rxjs-and-redux)  
69. The Bridge Pattern in Modern JavaScript: Separating Abstraction from Implementation | by Artem Khrienov | Medium, consulté le novembre 2, 2025, [https://medium.com/@artemkhrenov/the-bridge-pattern-in-modern-javascript-separating-abstraction-from-implementation-ce8c896c747e](https://medium.com/@artemkhrenov/the-bridge-pattern-in-modern-javascript-separating-abstraction-from-implementation-ce8c896c747e)  
70. Create a Component Library Fast (using Vite's library mode) \- DEV Community, consulté le novembre 2, 2025, [https://dev.to/receter/how-to-create-a-react-component-library-using-vites-library-mode-4lma](https://dev.to/receter/how-to-create-a-react-component-library-using-vites-library-mode-4lma)