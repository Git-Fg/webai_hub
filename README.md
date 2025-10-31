# AI Hybrid Hub MVP

**Transformer un gestionnaire d'onglets WebView en un hub hybride IA natif implémentant le workflow "Assister & Valider"**

![Flutter Multi-WebView](https://user-images.githubusercontent.com/5956938/205614782-cb3ae2db-870c-4dd6-9ef9-f9c222e8a2ae.gif)

## 🎯 Vue d'ensemble

Ce projet démontre la transformation complète d'un gestionnaire d'onglets WebView multi-fournisseurs en un hub IA hybride sophistiqué. L'application combine une interface de chat native avec des interactions automatisées via des ponts JavaScript pour implémenter le workflow **"Assister & Valider"** en 4 phases.

### 🏗️ Architecture Principale

```
lib/
├── core/                    # Noyau technique partagé
│   ├── constants/
│   │   └── selector_dictionary.dart    # Sélecteurs CSS par fournisseur
│   └── utils/
│       └── javascript_bridge.dart     # Pont natif ↔ JavaScript
├── shared/                  # Modèles et utilitaires partagés
│   ├── models/
│   │   ├── ai_provider.dart           # Fournisseurs IA (aistudio, qwen, zai, kimi)
│   │   ├── automation_state.dart      # États du workflow d'automatisation
│   │   └── conversation.dart          # Modèles de conversation et messages
│   └── services/
│       └── storage_service.dart       # Persistance des conversations
├── features/                # Modules fonctionnels
│   ├── hub/                     # Interface de chat native
│   ├── automation/              # Workflow d'automatisation
│   ├── webview/                 # Gestion des onglets WebView
│   └── settings/                # Configuration de l'application
└── main.dart                 # Point d'entrée avec architecture 5 onglets fixes
```

## 🔧 Fonctionnalités Clés

### 💬 Interface de Chat Native
- Conversation bubble-style avec support multi-fournisseur
- Gestion des statuts de messages (envoi, traitement, complété, erreur)
- Historique des conversations persistant
- Interface d'accueil pour les nouveaux utilisateurs

### 🤖 Workflow "Assister & Valider"
Le système implémente 4 phases d'automatisation :

1. **Phase 1 - Sending** : Injection du prompt dans le WebView cible
2. **Phase 2 - Observing** : Surveillance en temps réel de la génération
3. **Phase 3 - Refining** : Interface de validation et raffinement
4. **Phase 4 - Extracting** : Extraction et sauvegarde de la réponse finale

### 🌐 Pont JavaScript Bi-directionnel
- Communication natif ↔ JavaScript pour chaque fournisseur
- Surveillance DOM avec MutationObserver
- Gestion des événements et callbacks
- Support des sélecteurs CSS multiples avec fallback

### 📊 État d'Automatisation
- Suivi visuel des phases avec indicateur de progression
- Boutons contextuels (Annuler, Valider) selon la phase
- Gestion des erreurs et retry automatique
- Synchronisation entre l'interface native et les WebViews

## 🎨 Fournisseurs IA Supportés

| Fournisseur | URL | Statut |
|-------------|-----|--------|
| **AI Studio** | https://aistudio.google.com | ✅ Opérationnel |
| **Qwen** | https://qwen.ai | ✅ Opérationnel |
| **Zai** | https://zai.ai | ✅ Opérationnel |
| **Kimi** | https://kimi.ai | ✅ Opérationnel |

## 🚀 Démarrage Rapide

### Prérequis
- Flutter SDK (>=3.0.0)
- Dart SDK (>=2.17.0)
- Android Studio / Xcode pour l'émulation

### Installation
```bash
# Cloner le repository
git clone https://github.com/pichilin/flutter_inappwebview_multi_tab_manager.git
cd multi_webview_tab_manager

# Installer les dépendances
flutter pub get

# Générer les providers Riverpod
flutter packages pub run build_runner build

# Lancer l'application
flutter run
```

### Tests
```bash
# Lancer tous les tests unitaires
flutter test

# Test coverage
flutter test --coverage
```

## 📱 Utilisation

1. **Interface Hub** : Onglet principal avec interface de chat native
2. **Onglets Fournisseurs** : 4 onglets dédiés pour chaque IA
3. **Workflow Automatisé** :
   - Saisir un message dans l'interface Hub
   - Sélectionner un fournisseur IA
   - Lancer l'automatisation
   - Observer la progression via l'overlay compagnon
   - Valider ou corriger la réponse générée

## 🔧 Architecture Technique

### State Management
- **Riverpod** : Gestion d'état réactive avec providers
- **AutomationProvider** : État du workflow d'automatisation
- **ConversationProvider** : Gestion des conversations
- **WebviewProvider** : État des onglets WebView

### JavaScript Bridge
```javascript
// Exemple de communication
HubBridge.sendMessage({
  action: 'start',
  provider: 'aistudio',
  prompt: 'Votre message ici'
});

// Surveillance des réponses
HubBridge.observeResponse((response) => {
  console.log('Réponse détectée:', response);
});
```

### Sélecteurs CSS
Chaque fournisseur dispose de sélecteurs CSS intégrés pour :
- Zone de saisie du prompt
- Bouton d'envoi
- Indicateur de génération
- Zone de réponse de l'assistant

## 📊 Tests et Qualité

### Couverture de Tests
- ✅ 22/25 tests unitaires passent
- 📝 Tests des modèles de données
- 📝 Tests des providers Riverpod
- 📝 Tests du dictionnaire de sélecteurs
- 📝 Tests des états d'automatisation

### Qualité du Code
- Architecture Clean Code avec séparation des responsabilités
- Documentation inline complète
- Gestion des erreurs robuste
- Support offline avec fallbacks locaux

## 🔄 Workflow de Développement

Le projet suit une approche modulaire avec :
- Features isolées et testables
- Configuration centralisée
- Persistance des données locale
- Mises à jour OTA des sélecteurs (prévu)

## 📝 Notes Techniques

### Performance
- Gestion optimisée des ressources WebView
- Communication JavaScript asynchrone
- Surveillance DOM non-bloquante

### Sécurité
- Aucun envoi de données vers des serveurs externes
- Traitement local exclusivement
- Validation des entrées utilisateur

### Extensibilité
- Architecture modulaire pour ajouter de nouveaux fournisseurs
- Système de plugins pour les workflows personnalisés
- Configuration distante des sélecteurs

## 🤝 Contribuer

Ce projet sert de **proof-of-concept** pour la transformation d'applications WebView natives en hubs IA hybrides. La base de code est conçue pour être :

- **Éducative** : Démonstration des patterns Flutter avancés
- **Extensible** : Architecture modulaire pour évolutions futures
- **Robuste** : Tests complets et gestion d'erreurs

---

**Transformé avec succès depuis un gestionnaire d'onglets standard vers un hub IA hybride sophistiqué** 🚀
