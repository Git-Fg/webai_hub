# AGENTS.md

Guide pour les agents IA travaillant sur ce projet Flutter AI Hybrid Hub.

## 🎯 Contexte du Projet

Ce projet est en phase **MVP** avec une architecture 2-tabs (Hub natif + WebView Google AI Studio). L'objectif est de valider le workflow "Assist & Validate" avec un seul provider avant de passer à la version complète.

## 🤖 Instructions Spécifiques pour les Agents

### Outils Recommandés

Utilisez systématiquement ces outils quand disponible :

- **mobile-mcp**: Pour tester l'application en conditions réelles
- **dart-mcp**: Pour les analyses de code Dart
- **context7**: Pour les recherches de documentation

### Commandes Essentielles

```bash
# ⚠️ CRITIQUE : Build TypeScript après TOUTE modification dans ts_src/
npm run build

# Génération code après changements Riverpod/Freezed
flutter pub run build_runner build --delete-conflicting-outputs

# Tests unitaires
flutter test

# Lancement app (device spécifique)
flutter run -d <device_id>
```

### ⚠️ Workflow TypeScript - OBLIGATOIRE

**RÈGLE ABSOLUE** : Après **TOUTE** modification dans `ts_src/`, vous **DEVEZ** exécuter :

```bash
npm run build
```

**Pourquoi** : Les fichiers TypeScript dans `ts_src/` sont compilés vers `assets/js/bridge.js`. Flutter charge le bundle JavaScript compilé, donc :
- ✅ Modifier `automation_engine.ts` → **OBLIGATOIRE** : `npm run build`
- ✅ Changer les sélecteurs CSS → **OBLIGATOIRE** : `npm run build`
- ✅ Ajouter/supprimer fonctions globales → **OBLIGATOIRE** : `npm run build`
- ✅ Modifier la signature d'une fonction appelée depuis Dart → **OBLIGATOIRE** : `npm run build`
- ✅ Changer les dépendances TypeScript → **OBLIGATOIRE** : `npm install` puis `npm run build`

**Symptômes si vous oubliez** :
- Les modifications TypeScript ne sont pas reflétées dans l'app
- Erreurs JavaScript dans la console WebView
- Fonctions non trouvées lors des appels depuis Dart

### Règles de Travail

1. **Toujours vérifier les blueprints** avant toute modification
2. **Respecter la philosophie MVP** - rester simple et fonctionnel
3. **Utiliser Tree** pour explorer l'arborescence avant de créer des fichiers
4. **Lancer `npm run build`** après **TOUTE** modification TypeScript dans `ts_src/`
5. **Lancer build_runner** après toute modification de code généré Dart (@riverpod, @freezed)

### Erreurs Courantes à Éviter

- ❌ **OUBLIER `npm run build` après modification TypeScript** - **ERREUR CRITIQUE**
  - Les modifications dans `ts_src/` ne sont pas reflétées sans build
  - L'app utilise toujours l'ancien `assets/js/bridge.js`
  - Les fonctions JavaScript appelées depuis Dart ne seront pas trouvées
- ❌ Oublier `build_runner` après ajout `@riverpod` ou `@freezed`
- ❌ Modifier TypeScript sans vérifier que `npm run build` s'exécute sans erreurs
- ❌ Committer des modifications TypeScript sans avoir lancé `npm run build` au préalable
- ❌ Ajouter des commentaires inutiles (code auto-documenté)
- ❌ Laisser des `print` ou `console.log` dans le code committé
- ❌ **JAMAIS utiliser `TabController` Flutter natif pour la logique métier** (voir section Architecture)
- ❌ **Allonger les délais/timing en premier recours** - **ANTI-PATTERN CRITIQUE**
  - Les délais (`Future.delayed`, `setTimeout`) doivent être un dernier recours uniquement
  - **TOUJOURS** chercher d'abord la cause racine du timing incorrect :
    - Race condition dans le cycle de vie des widgets ou du WebView
    - État provider mal synchronisé
    - Événements qui arrivent dans le mauvais ordre
    - Sélélecteurs CSS incorrects ou éléments non disponibles
  - Si un délai résout le symptôme mais pas la cause, **SUPPRIMER le délai immédiatement**
  - Documenter précisément pourquoi un délai est nécessaire quand on en ajoute un

### Test Application Réelle

Quand vous utilisez mobile-mcp :

- Ne jamais désinstaller/réinstaller l'app (déconnexion)
- Attendre ~20s après redémarrage pour stabilisation
- Utiliser `flutter run -d <device_id>` pour cibler un device

### 🔄 Cycle Autonome : Test → Diagnostic → Correction

**RÈGLE ABSOLUE** : Quand une erreur est rencontrée, vous DEVEZ entrer dans un cycle autonome continu jusqu'à résolution complète. Ne JAMAIS s'arrêter tant qu'il reste une erreur.

#### Étapes du Cycle

1. **TEST** (Vérification objective)
   - Relancer l'app avec `flutter run -d <device_id>`
   - Tester le workflow complet via `mobile-mcp` (envoyer message, observer UI, capturer éléments)
   - **Ne JAMAIS utiliser directement les logs Flutter** (instruction explicite)
   - Prendre screenshots et lister éléments pour analyse visuelle

2. **DIAGNOSTIC** (Identification de la cause racine)
   - Comparer éléments détectés (`mobile-mcp`) avec sélecteurs hardcodés
   - Analyser logs JavaScript via `onConsoleMessage` dans WebView
   - Identifier le problème réel : race condition, sélecteurs obsolètes, synchronisation provider, timing incorrect
   - **PRIORITÉ** : Chercher la cause racine, PAS juste le symptôme

3. **CORRECTION** (Solution durable)
   - **ANTI-PATTERN** : Ne pas ajouter `Future.delayed` dès la première erreur
   - **CORRECT** : Corriger les race conditions, la synchronisation, l'ordre des événements
   - Si TypeScript modifié → `npm run build` (OBLIGATOIRE)
   - Si Riverpod modifié → `flutter pub run build_runner build --delete-conflicting-outputs`
   - Vérifier `flutter analyze` après modification

4. **VÉRIFICATION** (Validation)
   - Re-tester le même workflow
   - Confirmer que l'erreur est résolue
   - Vérifier qu'aucune régression n'est introduite

5. **ITÉRATION** (Répétition jusqu'à résolution)
   - Si nouvelle erreur → Retour à l'étape 1 immédiatement
   - Si erreur persiste → Approfondir diagnostic (étape 2)
   - Continuer jusqu'à ce que **TOUT** fonctionne

#### Exemples Concrets

**`WEBVIEWNOTREADY`** → Diagnostic : `IndexedStack` avec `const` empêche `onWebViewCreated` → Correction : Retirer `const`, ajuster timing

**`AUTOMATION_FAILED`** → Diagnostic : Fonctions JS non exposées sur `window` → Correction : `AT_DOCUMENT_END`, déclaration directe sur `window`, MutationObserver au lieu de `setInterval`

**`RESPONSEEXTRACTIONFAILED`** → Diagnostic : Sélecteurs ne matchent pas structure sandbox → Correction : Ajouter `.message-response` en priorité

#### Critères de Succès

Le cycle est **réussi** quand :
- ✅ Aucune erreur visible dans l'UI
- ✅ Workflow complet fonctionne : Envoi → Automation → Phase 3 → Extraction → Retour Hub
- ✅ `flutter test` : "All tests passed!"
- ✅ `flutter analyze` : Aucune erreur critique

### Workflow Debug

1. **Problème WebView**: 
   - Vérifier que `npm run build` a été exécuté après modifications TypeScript
   - Vérifier le bridge JS dans `assets/js/bridge.js` (ce fichier est généré, ne pas modifier directement)
   - Vérifier les logs JavaScript dans la console WebView
2. **Problème State**: Vérifier les providers Riverpod et les generated files
3. **Problème Build**: 
   - Pour TypeScript : Vérifier que `npm run build` s'exécute sans erreurs
   - Pour Dart : Vérifier que les dépendances sont synchronisées (`flutter pub get`)
   - Vérifier que `build_runner` a été lancé après modifications @riverpod/@freezed

## 📁 Structure Critique

```text
lib/features/
├── hub/          # UI native chat
├── webview/      # WebView + bridge JS
└── automation/   # Workflow + overlay

ts_src/
└── automation_engine.ts  # Moteur JS (hardcoded selectors MVP)
```

## 🔍 Points d'Attention

- Les sélecteurs CSS sont **hardcodés** dans le TypeScript (approche MVP)
- La persistence est **in-memory** uniquement (pas de Drift dans MVP)
- L'architecture est **2-tabs** et non 5-tabs comme la version complète
- Les tests utilisent des **fakes** plutôt que des mocks complexes

## 🏗️ Architecture : Gestion des Onglets avec Riverpod

### ⚠️ Règle Critique : Ne JAMAIS utiliser `TabController` Flutter pour la logique métier

**Problème identifié et résolu :**

- Initialement, nous avons tenté d'utiliser `TabController` Flutter natif avec un `Provider` override, mais cela créait des problèmes de synchronisation car les overrides de `ProviderScope` ne s'appliquent qu'aux widgets descendants, pas aux `NotifierProvider` globaux.
- Résultat : `tabControllerProvider` retournait toujours `null` dans `ConversationProvider`, causant des échecs de changement d'onglet.

### ✅ Solution : Architecture Riverpod Pure

**Principe :** Utiliser **uniquement** `currentTabIndexProvider` Riverpod pour gérer les changements d'onglets. Le `TabController` Flutter natif n'est utilisé **que pour l'affichage UI**.

#### Architecture Actuelle

1. **Provider Global Riverpod** (`lib/main.dart`):

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

   - `TabController` est utilisé **uniquement pour l'affichage** du `TabBar`
   - Synchronisation bidirectionnelle :
     - `TabController` → `currentTabIndexProvider` (via `_onTabChanged` listener)
     - `currentTabIndexProvider` → `TabController` (via `ref.listen` dans `build`)

3. **Business Logic** (`lib/features/hub/providers/conversation_provider.dart`):

   - **JAMAIS** accéder au `TabController` directement
   - **TOUJOURS** utiliser `ref.read(currentTabIndexProvider.notifier).changeTo(index)`
   - Exemple :

```dart
// ✅ CORRECT
ref.read(currentTabIndexProvider.notifier).changeTo(1);

// ❌ INCORRECT - Ne JAMAIS faire ça
final tabController = ref.read(tabControllerProvider);
tabController?.animateTo(1);
```

### 📝 Bonnes Pratiques Riverpod pour les Onglets

1. **Single Source of Truth** : `currentTabIndexProvider` est la seule source de vérité pour l'index de l'onglet actif

1. **Séparation des Responsabilités** :
   - **Riverpod Provider** (`currentTabIndexProvider`) : Logique métier, accessible partout
   - **Flutter TabController** : UI uniquement, local au widget `MainScreen`

1. **Pattern de Synchronisation** :

```dart
// Dans _MainScreenState

// 1. TabController → Provider (quand l'utilisateur clique sur TabBar)
_tabController.addListener(() {
  ref.read(currentTabIndexProvider.notifier).changeTo(_tabController.index);
});

// 2. Provider → TabController (quand code métier change l'onglet)
ref.listen(currentTabIndexProvider, (previous, next) {
  _tabController.animateTo(next);
});
```

1. **Accès depuis les Providers** :
   - Toujours utiliser `ref.read(currentTabIndexProvider.notifier).changeTo(index)`
   - Accessible depuis n'importe quel `NotifierProvider` sans dépendance au widget tree

### 🐛 Problèmes Résolus

- ✅ Synchronisation TabBar/IndexedStack : Le TabBar se met maintenant à jour visuellement quand le code métier change l'onglet
- ✅ Accessibilité globale : `currentTabIndexProvider` est accessible depuis tous les providers Riverpod
- ✅ Pas de race conditions : Le provider gère l'état de manière déterministe

### ⚙️ Implémentation Technique

- **Fichier clé** : `lib/main.dart` définit `CurrentTabIndex` provider
- **Utilisation** : `lib/features/hub/providers/conversation_provider.dart` l'utilise pour changer d'onglet
- **Synchronisation** : `ref.listen` dans `_MainScreenState.build` assure la cohérence UI

## 🔄 Riverpod : autoDispose vs keepAlive - Règle Générale

### ⚠️ Problème Résolu lors du Test d'Intégration

**Contexte** : Lors du développement du test d'intégration `bridge_communication_test.dart`, un problème critique a été identifié : les providers `BridgeReady` et `WebViewController` étaient auto-dispose par défaut, créant des **instances séparées** entre le widget et le container externe du test, empêchant la synchronisation de l'état.

**Solution** : Utilisation de `@Riverpod(keepAlive: true)` pour ces providers partagés entre plusieurs contextes (widget tree + test container).

### ✅ Règle Générale : Quand utiliser quoi ?

#### Utilisez `autoDispose` (défaut `@riverpod`) pour :

✅ **État spécifique à un seul écran/widget** :
- `TextEditingController` pour un formulaire
- État d'un carrousel (index actuel)
- État local d'un dialog ou d'une bottom sheet
- Cache temporaire pour un écran spécifique

✅ **FutureProvider/StreamProvider pour données d'écran** :
- Chargement de données qui doivent se rafraîchir quand l'utilisateur quitte et revient sur l'écran
- Exemple : `@riverpod Future<List<Item>> itemsForScreen(Ref ref) async { ... }`

**Avantage** : Libération automatique de la mémoire quand l'écran n'est plus utilisé.

#### Utilisez `keepAlive: true` (`@Riverpod(keepAlive: true)`) pour :

✅ **Services et dépôts (repositories)** :
- Clients API, services d'authentification
- Dépôts de données (repositories)
- **Exemple dans le projet** : `javaScriptBridgeProvider` (déjà keepAlive par défaut car provider simple)

✅ **État partagé entre plusieurs écrans** :
- État d'authentification utilisateur
- Thème de l'application
- **Exemple dans le projet** : `bridgeReadyProvider` - partagé entre WebView widget, test container, et providers métier

✅ **Handles vers ressources uniques** :
- Contrôleur de WebView (instance unique à partager)
- **Exemple dans le projet** : `webViewControllerProvider` - référence unique au `InAppWebViewController`

✅ **État de navigation global** :
- Index d'onglet actif (`currentTabIndexProvider`)
- État d'automatisation global (`automationStateProvider`)

### 📝 Exemples dans le Projet

```dart
// ✅ keepAlive: true - État partagé, ressource unique
@Riverpod(keepAlive: true)
class BridgeReady extends _$BridgeReady {
  @override
  bool build() => false;
  // Partagé entre widget WebView, test container, et providers métier
}

@Riverpod(keepAlive: true)
class WebViewController extends _$WebViewController {
  @override
  InAppWebViewController? build() => null;
  // Handle unique vers le contrôleur WebView
}

// ✅ autoDispose (défaut) - État local d'écran
@riverpod
class Conversation extends _$Conversation {
  @override
  List<Message> build() => [];
  // État spécifique à l'écran de conversation
}
```

### 🐛 Symptômes si vous utilisez le mauvais mode

**Si vous utilisez `autoDispose` pour un provider partagé** :
- ❌ Instances différentes créées dans différents contextes
- ❌ Mises à jour non visibles entre widget tree et container externe (tests)
- ❌ Provider dispose prématurément alors qu'il est encore utilisé ailleurs

**Si vous utilisez `keepAlive` pour un état local d'écran** :
- ❌ Fuite mémoire : état conservé même après navigation
- ❌ Données obsolètes réutilisées après navigation
- ❌ Performance dégradée (providers non disposés inutilement)

### 🎯 Checklist de Décision

Avant de créer un provider, demandez-vous :

1. **Ce provider est-il utilisé par plusieurs écrans/widgets ?**
   - Oui → `keepAlive: true`
   - Non → `autoDispose` (défaut)

2. **Ce provider représente-t-il une ressource unique (controller, service) ?**
   - Oui → `keepAlive: true`
   - Non → `autoDispose` (défaut)

3. **Ce provider est-il accessible depuis un container externe (tests, providers métier) ?**
   - Oui → `keepAlive: true`
   - Non → `autoDispose` (défaut)

4. **Ce provider est-il spécifique à un seul écran et doit se rafraîchir à chaque visite ?**
   - Oui → `autoDispose` (défaut)
   - Non → `keepAlive: true`
