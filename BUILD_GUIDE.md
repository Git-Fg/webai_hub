# WebAI Hub - Build and Development Guide

## Overview
WebAI Hub is a hybrid AI assistant that provides a centralized interface to multiple AI services through WebViews with automation capabilities.

## Prerequisites
- Flutter SDK 3.0 or higher
- Dart 2.18 or higher
- Android Studio / Xcode for mobile development

## Initial Setup

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Generate Code (Isar & Riverpod)
The project uses code generation for Isar database models and Riverpod providers. Run:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

This will generate:
- `lib/models/chat_message.g.dart` - Isar schema for ChatMessage
- Any Riverpod generated providers

### 3. Build and Run

For Android:
```bash
flutter run -d android
```

For iOS:
```bash
flutter run -d ios
```

## Project Structure

```
lib/
├── main.dart                          # App entry point with 5-tab structure
├── models/
│   ├── app_models.dart               # Core app models (ProviderConfig, OverlayState, etc.)
│   ├── chat_message.dart             # Isar database model for chat history
│   └── providers.dart                # Provider configurations (Kimi, Qwen, etc.)
├── providers/
│   └── app_providers.dart            # Riverpod state management providers
├── services/
│   ├── database_service.dart         # Isar database operations
│   ├── prompt_formatter.dart         # CWC-style prompt formatting
│   └── selector_service.dart         # CSS selector management
assets/
├── js/
│   └── bridge.js                     # JavaScript bridge for WebView automation
└── json/
    └── selectors.json                # CSS selectors for AI providers
```

## Architecture

The application follows the BLUEPRINT.md specifications with:

### 5 Fixed Tabs:
1. **Hub** - Native chat interface
2. **AI Studio** - Google AI Studio WebView
3. **Qwen** - Qwen Chat WebView
4. **Z-ai** - Z.ai Chat WebView
5. **Kimi** - Kimi Chat WebView

### Key Components:

#### State Management (Riverpod)
- `selectedProviderProvider` - Currently selected AI provider
- `providerStatusProvider` - Connection status of each provider
- `overlayStateProvider` - Companion overlay UI state
- `hubMessagesProvider` - Chat history with persistence
- `workflowProvider` - Orchestrates automation workflow

#### Automation Workflow
The app implements a 4-phase "Assist & Validate" workflow:
1. **Send Phase** - Inject prompt into selected provider
2. **Observation Phase** - Wait for AI generation to complete
3. **Refinement Phase** - Allow manual interaction
4. **Validation Phase** - Extract and return response to Hub

#### JavaScript Bridge
The `bridge.js` implements the "Contrat d'API" with:
- `checkStatus()` - Detect if provider is ready or needs login
- `start()` - Inject prompt and trigger generation
- `getFinalResponse()` - Extract the last assistant response
- `cancel()` - Stop the automation

## Development Workflow

### Adding a New Provider

1. Add configuration to `lib/models/providers.dart`:
```dart
static const newProvider = ProviderConfig(
  id: 'newprovider',
  name: 'New Provider',
  url: 'https://example.com/chat',
  icon: 'icon_name',
);
```

2. Add selectors to `assets/json/selectors.json`:
```json
{
  "newprovider": {
    "checkStatus": ["textarea"],
    "loginCheck": ["input[type='password']"],
    "promptTextarea": ["textarea"],
    "sendButton": ["button[type='submit']"],
    "isGenerating": ["button[aria-label='Stop']"],
    "assistantResponse": ["div[data-role='assistant']"]
  }
}
```

3. Add tab to main.dart (increase TabController length and add to TabBarView)

### Testing

Run existing tests:
```bash
flutter test
```

### Code Generation (when models change)
```bash
flutter pub run build_runner watch
```

## Troubleshooting

### "Database not initialized" error
Make sure `DatabaseService.initialize()` is called in `main()` before runApp.

### "Bridge not ready" messages in console
This is normal during initial page load. Messages are queued and sent once the bridge initializes.

### Provider shows "❌ Connexion requise"
Navigate to that provider's tab and manually log in to the service.

### Selectors not working
Selectors may need updating if the provider's website changes. Update `assets/json/selectors.json` with new selectors using browser DevTools.

## Security & Privacy

- All conversations are stored locally using Isar database
- No data is sent to external servers (except to the AI providers themselves)
- WebView sessions are isolated per provider
- The native layer cannot access WebView cookies or localStorage

## License

[Add your license here]
