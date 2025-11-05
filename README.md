# AI Hybrid Hub

## ⚠️ Work in Progress ⚠️

![Status](https://img.shields.io/badge/Status-Active_Development-green)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
![Platform](https://img.shields.io/badge/Platform-Flutter-02569B?logo=flutter)

### About This Project

**AI Hybrid Hub** is a personal project created to address my own needs for centralizing access to various web-based AI providers and their free tiers. As I continue to use and refine it, I'm building it to evolve based on real-world usage patterns and emerging requirements.

The primary goal is to create a unified interface that brings together multiple AI web UIs (like Google AI Studio, ChatGPT, Claude, Qwen, Zai, Kimi, etc.) in one place, making it easier to leverage free access tiers and compare different providers' capabilities.

**An intelligent, hybrid AI assistant that bridges a native Flutter interface with the power of web-based AI providers through JavaScript automation.**

Inspired by the powerful workflow of [Code Web Chat](https://github.com/robertpiosik/CodeWebChat).

AI Hybrid Hub transforms your mobile device into a sophisticated control center for web-based AI tools. It combines a native chat UI with a powerful JavaScript automation bridge, allowing you to interact with AI providers like Google AI Studio directly from a single, unified interface.

### ✨ Key Features

- ✅ **Native Chat Experience** - A modern, intuitive chat UI for sending prompts and viewing conversations with features like message editing and copying.
- ✅ **Multi-Provider Integration** - Connects seamlessly to multiple providers like Google AI Studio, with a modular architecture ready for ChatGPT, Claude, and more.
- ✅ **Contextual "Assist & Validate" Workflow** - A unique process where you build a "meta-conversation" in the native UI. The entire chat history is used as context for the AI, enabling complex, multi-turn dialogues, while you visually validate each step in a fresh, clean WebView session.
- ✅ **Dynamic & Interactive UI** - Features a draggable and minimizable automation panel, giving you an unobstructed view of the web provider. Error messages are displayed as non-destructive, ephemeral bubbles, allowing you to retry actions without losing context.
- ✅ **JavaScript Automation Engine** - A powerful TypeScript-based engine pilots web interfaces, handling logins, prompt submissions, and response extractions.
- ❤️ **Free and Open-Source** - Released under the GNU license.

### 📊 Project Status & Roadmap

This project is under active development.

#### ✅ Currently Functional

- Core "Assist & Validate" workflow.
- Integration with **Google AI Studio**.
- Native chat interface with message history, editing, and copying.
- Robust, modular TypeScript architecture for the automation engine.

#### 🚀 On the Roadmap

- **Multi-Provider Support** - Adding more AI providers (ChatGPT, Claude, Qwen, Zai, Kimi, etc.).
- **Automated Provider Comparison** - Send the same prompt to multiple providers simultaneously and compare their responses side-by-side.
- **Intelligent Response Synthesis** - Use a "main agent" (like Google AI Studio) to classify, compare, and synthesize responses from multiple providers, leveraging the best aspects of each answer.
- **Smart Meta-Chat Management** - Advanced conversation management features:
  - Message reordering and reorganization within conversations.
  - Enhanced message editing capabilities with context preservation.
  - Intelligent message condensation - Use a web UI to automatically condense multiple messages (messages x to x+n) into a single, concise summary, helping to maintain context while reducing token usage.
  - Conversation pruning and optimization tools.
- **Advanced Chat Features** - Conversation export (Markdown), multi-message selection, bulk operations.
- **File Attachments** - Support for TXT, PDF files for context augmentation.
- **Provider Settings UI** - Manage provider-specific settings (model selection, temperature, etc.).

### 🛠️ Technology Stack

- **Framework**: Flutter & Dart
- **State Management**: Riverpod (`riverpod_generator`)
- **WebView Integration**: `flutter_inappwebview`
- **Automation Bridge**: TypeScript + Vite

### 🚀 Quick Start

#### Prerequisites

- Flutter SDK (>= 3.3.0)
- Node.js and npm

#### Installation & Launch

1. **Clone the repository:**

    ```bash
    git clone <YOUR_REPO_URL>
    cd ai_hybrid_hub
    ```

2. **Install dependencies:**

    ```bash
    flutter pub get
    npm install
    ```

3. **Build the JavaScript bridge:**
    *This command is mandatory after any change in the `ts_src/` directory.*

    ```bash
    npm run build
    ```

4. **Generate Dart code:**
    *Run this after modifying Riverpod providers or Freezed models.*

    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs
    ```

5. **Run the application:**

    ```bash
    flutter run
    ```

### 🏗️ Project Structure

```text
lib/
├── features/
│   ├── hub/         # Native chat UI and state management
│   └── webview/     # WebView widget and Dart-JS bridge logic
assets/
├── js/
│   └── bridge.js    # Compiled JS bundle (generated by Vite)
ts_src/
├── chatbots/        # Logic for each specific AI provider
├── types/           # Shared TypeScript interfaces (e.g., Chatbot)
├── utils/           # Utility functions (waitForElement, etc.)
└── automation_engine.ts # Core automation orchestrator
```
