# AI Hybrid Hub (MVP)

**🎯 Objectif : Implémenter et valider un hub d'IA hybride via un workflow d'automatisation JavaScript.**

Ce projet Flutter est le Produit Minimum Viable (MVP) d'un assistant IA multi-fournisseurs. Il vise à valider le concept "Assister & Valider" en combinant une interface de chat native avec les interactions automatisées d'une `WebView`.

---

### 📊 **État Actuel du Projet : En cours de construction du MVP**

-   **✅ Architecture définie** : La structure du projet est en place.
-   **🎯 Focus Actuel** : Implémentation du workflow complet pour **un seul fournisseur** : Google AI Studio.
-   **🚀 Prochaine Étape** : Finaliser la logique du pont de communication et l'orchestration du workflow.

### ✨ Fonctionnalités Clés du MVP

-   **Interface Hub Native** : Un écran de chat simple pour envoyer des prompts et voir les réponses.
-   **Intégration `WebView`** : Un onglet dédié pour **Google AI Studio** avec persistance de session de base.
-   **Workflow "Assister & Valider"** : Implémentation du flux en 4 phases (Envoi, Observation, Raffinage, Validation).
-   **Pont JavaScript** : Communication Dart ↔ TypeScript pour piloter l'automatisation du DOM.

### 🛠️ Stack Technique

-   **Framework** : Flutter 3.19+ / Dart 3.3+
-   **Gestion d'État** : Riverpod (avec `riverpod_generator`)
-   **Vue Web** : `flutter_inappwebview`
-   **Pont d'Automatisation** : TypeScript + Vite

### 🚀 Démarrage Rapide

#### **Prérequis**

-   Flutter SDK (>= 3.19.0)
-   Node.js et npm

#### **Installation & Lancement**

1.  **Cloner le repository :**
    ```bash
    git clone <URL_DU_REPO>
    cd ai_hybrid_hub
    ```

2.  **Installer les dépendances Flutter :**
    ```bash
    flutter pub get
    ```

3.  **Installer les dépendances TypeScript :**
    ```bash
    npm install
    ```

4.  **Compiler le pont JavaScript :**
    ```bash
    npm run build
    ```
    *(Cette commande doit être exécutée après chaque modification du fichier `automation_engine.ts`)*

5.  **Générer le code Dart (Riverpod/Freezed) :**
    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs
    ```

6.  **Lancer l'application :**
    ```bash
    flutter run
    ```

### 🏗️ Structure du Projet

```
lib/
├── features/
│   ├── hub/         # UI et logique du chat natif
│   └── webview/     # Gestion de la WebView et du pont
├── assets/
│   └── js/
│       └── bridge.js  # Bundle JS généré par Vite
ts_src/
└── automation_engine.ts # Code source du moteur d'automatisation
```
