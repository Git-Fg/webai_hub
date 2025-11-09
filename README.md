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

- ✅ **Native Chat Experience** - A modern, intuitive chat UI for sending prompts and viewing conversations, complete with message editing and system prompt management.
- ✅ **"YOLO" Mode for Streamlined Workflow** - An optional, default-on mode that fully automates the send-and-extract cycle. Get answers back in the native UI as fast as possible with zero manual intervention. Disable it for full manual control over the refinement process.
- ✅ **Contextual "Assist & Validate" Workflow** - Build a "meta-conversation" in the native UI while visually validating each step in a fresh, clean WebView session.
- ✅ **Intelligent UI Feedback** - Employs a smart UI that uses non-intrusive notifications for background status updates, reserving an interactive overlay only for when user action is needed. This provides a clear, unobstructed view of the web automation.
- ✅ **Customizable Prompt Engineering** - Fine-tune how the AI receives context with customizable settings, including the ability to edit the instruction text that introduces the conversation history.

- ✅ **Resilient Automation Engine** - A powerful TypeScript-based engine pilots web interfaces. It uses modern, event-driven APIs (`MutationObserver`) instead of inefficient polling to prevent crashes and ensure stability on mobile devices.

- ✅ **Optimized for All Devices** - Built with performance in mind. Features a unique **Timeout Modifier** setting, allowing users on slower devices or networks to increase automation timeouts and ensure a reliable experience.

- ✅ **Multi-Provider Ready** - Connects seamlessly to Google AI Studio with a modular architecture designed for easy expansion to other providers like ChatGPT, Claude, and more.

- ❤️ **Free and Open-Source** - Released under the GNU license.

### ⚙️ Performance & Adaptability

AI Hybrid Hub is engineered to be reliable across a wide range of devices and network conditions. We believe that a powerful tool should not require the latest hardware.

- **High-Speed TypeScript Orchestration:** To maximize responsiveness, the app delegates the entire automation workflow to a powerful TypeScript engine that runs directly inside the WebView. By minimizing communication between the native UI and the web content, perceived latency is drastically reduced.

- **Lightweight State Management:** Built on Riverpod, ensuring efficient and predictable state updates without unnecessary overhead.

- **Efficient DOM Interaction:** The TypeScript automation engine avoids inefficient polling (`setInterval`) in favor of modern, event-driven APIs like `MutationObserver`. This drastically reduces CPU and battery usage on mobile devices, preventing common WebView crashes.

- **User-Configurable Timeouts:** Recognizing that not all devices are equal, the app includes a **"Timeout Modifier"** in the settings. Users can easily increase the patience of the automation engine, making the app viable and reliable even on older phones or slow Wi-Fi connections.

- **Automatic History Pruning:** To manage storage space, the app automatically keeps only the most recent conversations (defaulting to 10, but configurable), preventing indefinite database growth and keeping the app feeling fast.

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

  - `run_${SESSION_ID}.log`: Session-specific log files that serve as the **single source of truth for process output**. Each validation session generates a unique log file (format: `run_YYYY-MM-DD_HH-MM-SS.log`). The agent reads these logs to determine the success or failure of its actions.

  - `aistudio_state_*.json`: A structured log of the validation session, including the test plan, results, and any fix attempts. This file is written to and updated by the agent throughout the process.

  - `run_session.sh`: A unified script that provides a hermetic environment for each test run, ensuring clean setup and teardown. The script automatically handles termination of previous sessions and manages the application lifecycle.

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
