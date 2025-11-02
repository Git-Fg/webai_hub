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
# Build après modifications TypeScript
npm run build

# Génération code après changements Riverpod/Freezed
flutter pub run build_runner build --delete-conflicting-outputs

# Tests unitaires
flutter test

# Lancement app (device spécifique)
flutter run -d <device_id>
```

### Règles de Travail

1. **Toujours vérifier les blueprints** avant toute modification
2. **Respecter la philosophie MVP** - rester simple et fonctionnel
3. **Utiliser Tree** pour explorer l'arborescence avant de créer des fichiers
4. **Lancer build_runner** après toute modification de code généré

### Erreurs Courantes à Éviter

- ❌ Oublier de lancer `npm run build` après modification TypeScript
- ❌ Oublier `build_runner` après ajout `@riverpod` ou `@freezed`
- ❌ Ajouter des commentaires inutiles (code auto-documenté)
- ❌ Laisser des `print` ou `console.log` dans le code committé
- ❌ **JAMAIS utiliser `TabController` Flutter natif pour la logique métier** (voir section Architecture)

### Test Application Réelle

Quand vous utilisez mobile-mcp :

- Ne jamais désinstaller/réinstaller l'app (déconnexion)
- Attendre ~20s après redémarrage pour stabilisation
- Utiliser `flutter run -d <device_id>` pour cibler un device

### Workflow Debug

1. **Problème WebView**: Vérifier le bridge JS dans `assets/js/bridge.js`
2. **Problème State**: Vérifier les providers Riverpod et les generated files
3. **Problème Build**: Vérifier que les dépendances sont synchronisées

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
