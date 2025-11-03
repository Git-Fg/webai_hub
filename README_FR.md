# AI Hybrid Hub (Français)

## ⚠️ Projet en Cours de Développement ⚠️

![Status](https://img.shields.io/badge/Statut-Développement_Actif-green)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
![Platform](https://img.shields.io/badge/Plateforme-Flutter-02569B?logo=flutter)

**Un assistant IA hybride et intelligent qui fait le pont entre une interface native Flutter et la puissance des fournisseurs d'IA basés sur le web grâce à l'automatisation JavaScript.**

Inspiré par le workflow de [Code Web Chat](https://github.com/robertpiosik/CodeWebChat).

AI Hybrid Hub transforme votre appareil mobile en un centre de contrôle sophistiqué pour les outils d'IA en ligne. Il combine une interface de chat native avec un puissant pont d'automatisation JavaScript, vous permettant d'interagir avec des fournisseurs comme Google AI Studio depuis une interface unique et unifiée.

### ✨ Fonctionnalités Clés

-   ✅ **Expérience de Chat Native** — Une interface de chat moderne et intuitive pour envoyer des prompts et visualiser les conversations, avec des fonctions d'édition et de copie.
-   ✅ **Intégration Multi-Fournisseurs** — Se connecte de manière transparente à plusieurs fournisseurs comme Google AI Studio, avec une architecture modulaire prête pour ChatGPT, Claude, et d'autres.
-   ✅ **Workflow "Assister & Valider"** — Un processus unique (Envoi, Observation, Raffinement, Extraction) qui vous donne le contrôle total en validant visuellement chaque étape dans le WebView intégré.
-   ✅ **Moteur d'Automatisation JavaScript** — Un puissant moteur basé sur TypeScript pilote les interfaces web, gérant les connexions, la soumission des prompts et l'extraction des réponses.
-   ❤️ **Gratuit et Open-Source** — Publié sous la licence MIT.

### 📊 Statut du Projet & Feuille de Route

Ce projet est en développement actif.

#### ✅ Actuellement Fonctionnel :
-   Workflow principal "Assister & Valider".
-   Intégration avec **Google AI Studio**.
-   Interface de chat native avec historique, édition et copie des messages.
-   Architecture TypeScript robuste et modulaire pour le moteur d'automatisation.
-   Mode "sandbox" pour les tests d'intégration.

#### 🚀 Sur la Feuille de Route :
-   Ajout de nouveaux fournisseurs d'IA (ChatGPT, Claude, etc.).
-   Fonctionnalités de chat avancées : exportation de conversation (Markdown), sélection multiple.
-   Pièces jointes (TXT, PDF) pour augmenter le contexte.
-   Interface pour gérer les paramètres spécifiques à chaque fournisseur (sélection du modèle, température, etc.).

### 🛠️ Stack Technologique

-   **Framework**: Flutter & Dart
-   **Gestion d'état**: Riverpod (`riverpod_generator`)
-   **Intégration WebView**: `flutter_inappwebview`
-   **Pont d'Automatisation**: TypeScript + Vite

### 🚀 Démarrage Rapide

**Prérequis**
-   Flutter SDK (>= 3.3.0)
-   Node.js et npm

**Installation & Lancement**
1.  **Cloner le dépôt :**
    ```bash
    git clone <VOTRE_URL_DE_DÉPÔT>
    cd ai_hybrid_hub
    ```

2.  **Installer les dépendances :**
    ```bash
    flutter pub get
    npm install
    ```

3.  **Compiler le pont JavaScript :**
    *Cette commande est obligatoire après toute modification dans le dossier `ts_src/`.*
    ```bash
    npm run build
    ```

4.  **Générer le code Dart :**
    *À exécuter après avoir modifié des providers Riverpod ou des modèles Freezed.*
    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs
    ```

5.  **Lancer l'application :**
    ```bash
    flutter run
    ```
    *(Utilisez les configurations de lancement dans VS Code ou Android Studio pour basculer entre les modes production et sandbox).*

### 🏗️ Structure du Projet

```
lib/
├── features/
│   ├── hub/         # UI du chat natif et gestion d'état
│   └── webview/     # Widget WebView et logique du pont Dart-JS
└── config/          # Configuration d'environnement (sandbox vs production)
assets/
├── js/
│   └── bridge.js    # Bundle JS compilé (généré par Vite)
└── sandboxes/
    └── aistudio_sandbox.html # Fichier HTML local pour les tests
ts_src/
├── chatbots/        # Logique pour chaque fournisseur d'IA spécifique
├── types/           # Interfaces TypeScript partagées (ex: Chatbot)
├── utils/           # Fonctions utilitaires (waitForElement, etc.)
└── automation_engine.ts # Orchestrateur principal de l'automatisation
```