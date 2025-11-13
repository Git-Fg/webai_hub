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

- ✅ **Multi-Provider Orchestration** - Manage a library of "Presets" (Provider + Model + Settings). Send a single prompt to multiple presets simultaneously and compare their responses side-by-side in a dedicated curation panel.

- ✅ **Native Chat Experience** - A modern, intuitive chat UI for sending prompts and viewing conversations, complete with message editing and system prompt management.

- ✅ **"YOLO" Mode for Streamlined Workflow** - An optional, default-on mode that fully automates the send-and-extract cycle. Get answers back in the native UI as fast as possible with zero manual intervention. Disable it for full manual control over the refinement process.

- ✅ **Robust Hybrid Automation** - For providers like Kimi without direct text access, the app uses a resilient hybrid clipboard strategy, ensuring reliable response extraction where other methods fail.

- ✅ **Contextual "Assist & Validate" Workflow** - Build a "meta-conversation" in the native UI while visually validating each step in a fresh, clean WebView session.
- ✅ **Intelligent UI Feedback** - Employs a smart UI that uses non-intrusive notifications for background status updates, reserving an interactive overlay only for when user action is needed. This provides a clear, unobstructed view of the web automation.
- ✅ **Customizable Prompt Engineering** - Fine-tune how the AI receives context with customizable settings, including the ability to edit the instruction text that introduces the conversation history.

- ✅ **Resilient Automation Engine** - A powerful TypeScript-based engine pilots web interfaces. It uses modern, event-driven APIs (`MutationObserver`) instead of inefficient polling to prevent crashes and ensure stability on mobile devices.

- ✅ **Optimized for All Devices** - Built with performance in mind. Features a unique **Timeout Modifier** setting, allowing users on slower devices or networks to increase automation timeouts and ensure a reliable experience.

- ✅ **Multi-Provider Ready** - Connects seamlessly to Google AI Studio with a modular architecture designed for easy expansion to other providers like ChatGPT, Claude, and more.

- ⚠️ **Known Limitation** - Google AI Studio may show a CookieMismatch error due to Google's security policies that block embedded WebViews. The app includes workarounds, but authentication may require using a regular browser first.

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

- Core "Assist & Validate" workflow for single providers.
- **Multi-provider orchestration** via a persistent, user-configurable Preset system.
- Side-by-side response comparison in the native Hub UI.
- Integration with **Google AI Studio** and **Kimi**, with robust, provider-specific automation logic.
- Native chat interface with message history, editing, and copying.

#### 🚀 On the Roadmap

- **Preset-Based Orchestration System** - Create, save, and manage "Presets" (a combination of provider, model, and parameters). Group presets for organization and settings inheritance.

- **Multi-Preset Broadcasting** - Send a single prompt to multiple presets simultaneously and view their responses side-by-side for direct comparison.

- **Intelligent Response Synthesis** - Use a primary AI model to analyze, critique, and merge the best parts of multiple responses into one superior answer.

- **Smart Meta-Chat Management** - Advanced conversation management features:
  - Message reordering and reorganization within conversations.
  - Intelligent message condensation - Use an AI to summarize parts of a conversation to reduce token usage while preserving context.
  - Conversation pruning and optimization tools.

- **Advanced Chat Features** - Conversation export (Markdown), multi-message selection, bulk operations.

- **File Attachments** - Support for TXT, PDF files for context augmentation.

### 🛠️ Technology Stack

- **Framework**: Flutter & Dart
- **State Management**: Riverpod (`riverpod_generator`)
- **WebView Integration**: `flutter_inappwebview`
- **Automation Bridge**: TypeScript + Vite

### 🚀 Quick Start

#### Prerequisites

- Flutter SDK (>= 3.3.0)
- Node.js and pnpm

#### Installation & Launch

1. **Clone the repository:**

    ```bash
    git clone <YOUR_REPO_URL>
    cd ai_hybrid_hub
    ```

2. **Install dependencies:**

    ```bash
    flutter pub get
    pnpm install
    ```

3. **Validate and Build:**
    *Run this unified quality gate any time you modify Flutter or TypeScript code.*

    ```bash
    pnpm run test:ci
    ```

4. **Run the application:**

    ```bash
    flutter run
    ```

> **Note on First Use & Google Login (Error 403)**
>
> The app uses your saved web sessions. The first time you use a provider, you will need to log in.
>
> **Important for Google AI Studio:** Google often blocks logins from unrecognized applications, showing a "disallowed_useragent" or "Error 403" message. This is expected. To fix this:
>
> 1. Go to the **Hub** tab and tap the **Settings** icon.
> 2. Under "WebView Settings," find the **User Agent** dropdown.
> 3. Change it from "Device Default" to a standard browser like **"Chrome (Windows)"**.
>
> The app will automatically reload the WebView with the new identity, allowing you to log in successfully. Your session will be saved for all future launches.

### 🏗️ Project Structure

```text
lib/
├── features/
│   ├── hub/         # Native chat UI and state management
│   ├── presets/     # Preset management UI and state
│   └── webview/     # WebView widget and Dart-JS bridge logic
assets/
├── js/
│   └── bridge.js    # Compiled JS bundle (generated by Vite)
packages/
├── bridge/          # Core TypeScript automation engine (compiled into assets/js/bridge.js)
│   ├── automation_engine.ts
│   ├── chatbots/
│   ├── types/
│   └── utils/
└── manual_validation/ # Developer utilities for manual selector validation
```
