# AI Hybrid Hub

## ⚠️ Work in Progress ⚠️

![Status](https://img.shields.io/badge/Status-Active_Development-green)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
![Platform](https://img.shields.io/badge/Platform-Flutter-02569B?logo=flutter)

### About This Project

**AI Hybrid Hub** is a personal project created to address my own needs for centralizing access to various web-based AI providers and their free tiers. As I continue to use and refine it, I'm building it to evolve based on real-world usage patterns and emerging requirements.

The primary goal is to create a unified interface that brings together multiple AI web UIs (like Google AI Studio, ChatGPT, Claude, Qwen, Zai, Kimi, etc.) in one place, making it easier to leverage free access tiers and compare different providers' capabilities.

**Final Goal : An intelligent, hybrid AI assistant that bridges a native Flutter interface with the power of web-based AI providers through JavaScript automation.**

Inspired by the powerful workflow of [Code Web Chat](https://github.com/robertpiosik/CodeWebChat).

AI Hybrid Hub transforms your mobile device into a sophisticated control center for web-based AI tools. It combines a native chat UI with a powerful JavaScript automation bridge, allowing you to interact with AI providers like Google AI Studio directly from a single, unified interface.

### ✨ Key Features

- ✅ **Native Chat Experience** - A modern, intuitive chat UI for sending prompts and viewing conversations with features like message editing and copying.
- ✅ **Multi-Provider Integration** - Connects seamlessly to multiple providers like Google AI Studio, with a modular architecture ready for ChatGPT, Claude, and more.
- ✅ **Contextual "Assist & Validate" Workflow** - Build a "meta-conversation" in the native UI. The app compiles the entire chat history into a structured XML prompt for the AI, enabling complex, multi-turn dialogues while you visually validate each step in a fresh, clean WebView session.
- ✅ **Customizable Prompt Engineering** - Fine-tune how the AI receives context with customizable settings, including the ability to customize the instruction text that introduces conversation history in XML prompts.
- ✅ **Resilient & Interactive UI** - A draggable overlay provides an unobstructed view of the web provider. The UI is decoupled from business logic via signal-based providers, and error messages are displayed as non-destructive, ephemeral bubbles, allowing you to retry actions without losing context.
- ✅ **JavaScript Automation Engine** - A powerful TypeScript-based engine pilots web interfaces, handling logins, prompt submissions, and response extractions.
- ❤️ **Free and Open-Source** - Released under the GNU license.

### 🤖 AI Development Workflow

This project is not only *about* AI; it is actively developed and validated *with* AI agents. Our methodology is formalized through a hierarchy of documents that create a robust, predictable, and autonomous development loop.

This system is designed to be self-contained, providing any compatible AI agent with all the necessary rules and context to be an effective contributor.

#### 1. The Agent Manifesto (`AGENTS.md`)

- **Purpose:** The foundational "constitution" for any AI agent working on this project. It is the highest-level source of truth for behavior and quality standards.

- **Content:** It defines:

  - **Core Philosophy:** Prioritizing simplicity, robustness, and maintainability.

  - **High-Level Workflows:** Distinguishes between "Code Development" and "Autonomous Feature Validation."

  - **Technical Best Practices:** Enforces strict rules for state management (Riverpod 3.0+), hybrid development (timing, delays), and code quality.

  - **Critical Anti-Patterns:** Explicitly forbids common but problematic coding patterns.

#### 2. Task-Specific Protocols (`.cursor/rules/`)

- **Purpose:** These are specialized, executable protocols for complex, automated tasks. While `AGENTS.md` defines the *what* (e.g., "validate a feature"), these rules define the precise, step-by-step *how*.

- **Example (`autonomous-validator.mdc`):** This rule codifies the entire end-to-end validation process. When invoked (e.g., via `@autonomous-validator`), the agent initiates a "Write > Execute > Write" cycle:

  1. **Analyze:** It reads the TypeScript provider code to generate a test plan.

  2. **Execute:** It runs the app, executes tests using `mobile-mcp` commands, and logs all output.

  3. **Correct:** If a test fails, it analyzes the log, attempts a code fix, rebuilds, and re-runs the test.

  4. **Report:** It generates a final report based on the results.

#### 3. The Operational Source of Truth (`reports/`)

- **Purpose:** This directory is the I/O interface for all automated processes. It serves as the agent's working memory and the definitive record of its actions.

- **Key Artifacts:**

  - `run.log`: The **single source of truth for process output**. The agent reads this log to determine the success or failure of its actions.

  - `aistudio_state_*.json`: A structured log of the validation session, including the test plan, results, and any fix attempts. This file is written to and updated by the agent throughout the process.

  - `run_and_log.sh` & `terminate_run.sh`: Scripts that provide a hermetic environment for each test run, ensuring clean setup and teardown.

This structured approach transforms the AI from a simple code generator into an autonomous partner capable of executing complex, stateful tasks with a clear feedback loop.

### 📊 Project Status & Roadmap

This project is under active development.

#### ✅ Currently Functional

- Core "Assist & Validate" workflow.
- Integration with **Google AI Studio**.
- Native chat interface with message history, editing, and copying.
- Robust, modular TypeScript architecture for the automation engine.

#### 🚀 On the Roadmap

- **Multi-Provider Support** - Adding more AI providers (ChatGPT, Claude, Qwen, Zai, Kimi, etc.).
- **Multi-Provider Support** - Adding more AI providers (ChatGPT, Claude, Qwen, Zai, Kimi, etc.). This will be enabled by a robust remote JSON configuration for CSS selectors, allowing updates without requiring an app release.
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

3. **Validate and Build:**
    *This command is mandatory after making changes to Dart or TypeScript code.*

    ```bash
    npm run validate
    ```

4. **Run the application:**

    ```bash
    flutter run
    ```

> Note on First Use: The application relies on persisted web sessions. On your first run, manually navigate to the "AI Studio" tab and log in to your Google account. Your session will be saved for future launches.

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
