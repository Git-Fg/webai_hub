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
6. **Utiliser `keepAlive: true`** pour services/états partagés (`webViewControllerProvider`) et `autoDispose` (défaut) pour états d'écran. Voir `BLUEPRINT_MVP.md` section 7.4 pour le guide de décision.

### 🚫 Anti-Patterns Critiques

#### Anti-Pattern 1 : Utiliser `TabController` Flutter pour la logique métier

- ❌ **JAMAIS** : `final tabController = ref.read(tabControllerProvider); tabController?.animateTo(1);`
- ✅ **TOUJOURS** : `ref.read(currentTabIndexProvider.notifier).changeTo(index)`
- **Pourquoi** : `TabController` est lourd à synchroniser et ne peut pas être partagé entre widgets et providers. Voir `BLUEPRINT_MVP.md` section 7.1 pour détails.

#### Principe de Gestion du Timing : Les Délais en Dernier Recours

Les délais (`Future.delayed`, `setTimeout`) sont des outils puissants pour gérer l'asynchronisme, mais leur utilisation abusive masque les problèmes de fond et crée une application fragile. Ils traitent les **symptômes** (une action échoue car un élément n'est pas prêt) et non la **cause** (pourquoi l'élément n'était-il pas prêt ?).

- ❌ **L'Approche Symptomatique (à proscrire)** : Ajouter ou augmenter un `Future.delayed(Duration(seconds: 2))` dès qu'un problème de timing apparaît, sans investigation.

- ✅ **L'Approche Fondamentale (Priorité Absolue)** : **TOUJOURS** commencer par chercher la cause racine :
  - Y a-t-il un événement ou un callback que l'on peut écouter ? (ex: `onLoadStop`, un signal du bridge JS)
  - L'état d'un provider Riverpod est-il mal synchronisé ?
  - S'agit-il d'une race condition dans le cycle de vie des widgets/WebView ?
  - Le sélecteur CSS cible-t-il un élément qui apparaît après une animation ? Peut-on attendre la fin de l'animation avec une `MutationObserver` plus précise ?

#### Quand un délai est-il acceptable ?

Un délai est considéré comme un **dernier recours légitime** uniquement dans les cas suivants :

1. **Interaction avec un système externe opaque** : Lorsque vous attendez la fin d'une animation CSS ou d'un script tiers dans la `WebView` qui ne fournit **aucun événement de complétion** observable.

2. **Coussin de sécurité minimal** : Un délai très court (ex: 100-300ms) peut être utilisé pour s'assurer que le thread UI a eu le temps de finaliser un rendu complexe après un changement d'état, bien que des solutions comme `WidgetsBinding.instance.addPostFrameCallback` soient souvent préférables.

**Règle d'or** : Si un délai est ajouté, il doit être **court**, **borné**, et accompagné d'un commentaire expliquant **pourquoi** une solution événementielle n'était pas possible.

```dart
// TIMING: Attente de 300ms pour permettre à l'animation de fermeture du panneau de se terminer.
// Aucune callback JS n'est disponible pour cet événement.
await Future.delayed(const Duration(milliseconds: 300));
```

#### Règle pour l'ajustement des délais existants

Il est parfois nécessaire d'augmenter un délai existant car le comportement de la page web a changé. **Ne jamais augmenter un délai à l'aveugle.**

**Workflow obligatoire pour modifier un délai :**

1. **Diagnostiquer** : Comprendre *précisément pourquoi* le délai initial n'est plus suffisant. (Ex: "Le spinner de chargement de l'IA dure maintenant en moyenne 500ms de plus").

2. **Documenter** : Ajouter ou mettre à jour le commentaire pour justifier l'augmentation.
   ```dart
   // TIMING (MAJ 03/11/2025): Augmenté de 300ms à 800ms car la nouvelle interface
   // de l'IA ajoute une animation de fondu qui retarde l'apparition du bouton.
   await Future.delayed(const Duration(milliseconds: 800));
   ```

3. **Ajuster au minimum** : N'augmentez le délai que de la durée strictement nécessaire, avec une petite marge de sécurité. Ne doublez pas la valeur "juste au cas où".

4. **Considérer l'alternative** : Chaque fois que vous touchez à un délai, demandez-vous si une nouvelle méthode de détection (un nouvel attribut sur un élément, un événement) n'est pas devenue disponible.

**Conclusion : Chaque délai est une dette technique. Justifiez-le.**

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

### Test Application Réelle

Quand vous utilisez mobile-mcp :

- Ne jamais désinstaller/réinstaller l'app (déconnexion)
- Attendre ~20s après redémarrage pour stabilisation
- Utiliser `flutter run -d <device_id>` pour cibler un device

### Workflow Debug

#### Principe de Débogage

Face à une erreur, privilégier une approche systématique : **1. Observer** (comportement via `mobile-mcp`, screenshots), **2. Diagnostiquer** (logs JS via `onConsoleMessage`, état Riverpod, sélecteurs CSS), **3. Corriger la cause racine** (non le symptôme), **4. Vérifier** (re-tester workflow complet).

#### Guides de Débogage

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

## 🏗️ Règles Architecturales Critiques

⚠️ **Règle Critique** : Ne JAMAIS utiliser `TabController` Flutter pour la logique métier. Utiliser `ref.read(currentTabIndexProvider.notifier).changeTo(index)`. Voir `BLUEPRINT_MVP.md` section 7.1 pour l'explication complète.
