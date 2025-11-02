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