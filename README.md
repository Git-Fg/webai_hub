# WebAI Hub - Hybrid AI Assistant

A Flutter mobile application that provides a centralized interface to multiple AI services (Google AI Studio, Qwen, Z.ai, Kimi) with intelligent automation capabilities.

## ✨ Features

- **Native Hub Interface**: Clean, native chat UI for managing conversations
- **Multi-Provider Support**: Integrated access to 4 major AI services
- **Smart Automation**: "Assist & Validate" workflow that automates prompt injection while keeping you in control
- **Session Persistence**: Stay logged in across app restarts
- **Local-First**: All conversations stored locally with Isar database
- **Privacy Focused**: No data sent to external servers (operates 100% locally)

## 🏗️ Architecture

Based on the BLUEPRINT.md specifications, this app implements:

### 5 Fixed Tabs:
1. **Hub** - Native chat interface with provider selection
2. **AI Studio** - Google AI Studio WebView  
3. **Qwen** - Qwen Chat WebView
4. **Z-ai** - Z.ai Chat WebView
5. **Kimi** - Kimi Chat WebView

### Automation Workflow:
The app follows a 4-phase "Assist & Validate" workflow inspired by Code Web Chat (CWC):

1. **Send Phase**: Automatically inject your prompt into the selected AI provider
2. **Observation Phase**: Wait for the AI to complete its response
3. **Refinement Phase**: Manually refine the conversation as needed
4. **Validation Phase**: Extract and return the final response to the Hub

This "marionnettiste" approach ensures transparency - you always see what's happening.

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.0+
- Android Studio / Xcode

### Build Instructions

1. **Clone and install dependencies**:
   ```bash
   git clone <repository-url>
   cd webai_hub
   flutter pub get
   ```

2. **Generate required code**:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

3. **Run the app**:
   ```bash
   flutter run
   ```

For detailed build instructions, see [BUILD_GUIDE.md](BUILD_GUIDE.md).

## 📖 User Guide

### First Launch (Onboarding)

1. Open the app - you'll start on the Hub tab
2. Navigate to each AI provider tab (AI Studio, Qwen, Z-ai, Kimi)
3. Manually log in to your accounts on each provider
4. Return to the Hub - providers will show ✅ when ready

### Sending a Prompt

1. On the Hub tab, select your desired AI provider from the dropdown
2. Type your prompt in the chat input
3. Press Send
4. The app will automatically:
   - Switch to the provider's tab
   - Inject your prompt
   - Wait for the response
   - Show a "Validate" button when ready

### Refining Responses

- After the AI responds, you can manually interact with the provider's interface
- Ask follow-up questions, request reformatting, etc.
- When satisfied, click "✅ Valider et envoyer au Hub"
- The final response returns to the Hub

### Provider Status

- ✅ Prêt - Ready to use
- ❌ Connexion requise - Please log in manually
- ❓ Inconnu - Status unclear (may be loading)

## 🔧 Technical Details

### Technology Stack
- **Framework**: Flutter
- **State Management**: Riverpod
- **Database**: Isar (local)
- **WebView**: flutter_inappwebview
- **Chat UI**: flutter_gen_ai_chat_ui

### JavaScript Bridge
The app uses a custom JavaScript bridge (`assets/js/bridge.js`) to interact with AI provider WebViews:
- DOM manipulation for prompt injection
- MutationObserver for response detection
- Defense-in-depth selector strategy for robustness

### Selector Maintenance
CSS selectors for each provider are stored in `assets/json/selectors.json` with fallback arrays for resilience when providers update their UIs.

## 🔐 Security & Privacy

- **Local-First**: All conversations stored locally on your device
- **No External Servers**: No data sent to third-party servers
- **Session Isolation**: Each provider WebView is isolated
- **Secure Storage**: Chat history encrypted with Isar

## 🤝 Contributing

Contributions welcome! See [BUILD_GUIDE.md](BUILD_GUIDE.md) for development setup.

### Adding New Providers

1. Add configuration in `lib/models/providers.dart`
2. Add selectors in `assets/json/selectors.json`
3. Add tab to main.dart

## 📝 License

[Add your license here]

## 🙏 Acknowledgments

- Inspired by [Code Web Chat (CWC)](https://github.com/cesarpenhaardev/code-web-chat)
- Built following the BLUEPRINT.md architecture specifications

---

![Android example](https://user-images.githubusercontent.com/5956938/205614782-cb3ae2db-870c-4dd6-9ef9-f9c222e8a2ae.gif)
![iOS example](https://user-images.githubusercontent.com/5956938/205614819-a6b781c8-ad52-462e-afb2-5721ab11eb2c.gif)
