# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an **AI Hybrid Hub MVP** - a multi-provider AI assistant application implementing the complete "Assister & Valider" workflow as described in BLUEPRINT.md. The project has been transformed from a basic WebView tab manager into a sophisticated AI hub with native chat interface and JavaScript automation capabilities.

**Key Features:**
- **5-Tab Architecture**: Native Hub + 4 AI provider WebViews (AI Studio, Qwen, Z-ai, Kimi)
- **"Assister & Valider" Workflow**: Complete 4-phase automation process
- **Native Chat Interface**: Modern bubble-based conversation UI with provider selection
- **JavaScript Bridge**: Bidirectional communication with AI provider WebViews
- **Companion Overlay**: Visual feedback during automation phases
- **Session Persistence**: Maintains login state across all providers
- **Real-time Status**: Live connection status indicators for each provider

## Development Commands

### Basic Commands
```bash
# Install dependencies
flutter pub get

# Run the app in debug mode
flutter run

# Run on specific platform
flutter run -d android
flutter run -d ios

# Build for release
flutter build apk
flutter build ios

# Analyze code
flutter analyze

# Run tests (unit + widget tests)
flutter test

# Run only unit tests
flutter test test/unit/

# Run tests with coverage
flutter test --coverage
```

### Development Tools
```bash
# Enable WebView debugging (Android only, already configured in main.dart)
# WebView debug will be available in Chrome at chrome://inspect

# Check for outdated dependencies
flutter pub outdated

# Upgrade dependencies
flutter pub upgrade

# Generate code (if using code generation)
flutter packages pub run build_runner
```

## Architecture Overview

### Complete Application Architecture

```
lib/
├── main.dart (5-tab fixed architecture with ProviderScope)
├── core/
│   ├── constants/
│   │   ├── app_constants.dart
│   │   ├── selector_dictionary.dart (DOM selectors with fallback)
│   │   └── automation_state.dart
│   ├── database/ (SQLite for conversation persistence)
│   │   ├── database_helper.dart
│   │   └── conversation_model.dart
│   └── utils/
│       ├── javascript_bridge.dart (Native ↔ JS communication)
│       ├── prompt_formatter.dart (CWC-style prompt formatting)
│       ├── remote_config_service.dart (Remote selector fetching)
│       └── asset_loader.dart (Asset-based configuration loading)
├── features/
│   ├── hub/ (Native chat interface)
│   │   ├── providers/
│   │   │   ├── conversation_provider.dart (Riverpod state management)
│   │   │   └── provider_status_provider.dart (Provider connection status)
│   │   └── widgets/
│   │       ├── hub_screen.dart (Main chat UI)
│   │       ├── chat_bubble.dart (Message bubbles)
│   │       ├── prompt_input.dart (User input with context support)
│   │       ├── provider_selector.dart (Provider selection dropdown)
│   │       └── options_dialog.dart (Provider-specific settings)
│   ├── automation/ (Workflow management)
│   │   ├── providers/
│   │   │   └── automation_provider.dart (Automation state management)
│   │   └── widgets/
│   │       └── companion_overlay.dart (Visual feedback overlay)
│   └── webview/ (AI provider integration)
│       ├── providers/
│   │   └── webview_provider.dart (WebView and bridge management)
│       └── widgets/
│           └── ai_webview_tab.dart (Individual provider WebView)
├── shared/
│   ├── models/
│   │   ├── ai_provider.dart (4 AI provider definitions)
│   │   ├── conversation.dart (Chat and conversation data)
│   │   └── automation_state.dart (Automation workflow states)
│   └── widgets/ (Reusable UI components)
└── assets/
    ├── js/ (JavaScript automation scripts)
    └── json/ (Selector configuration files)
```

### Core Architecture Patterns

**State Management (Riverpod):**
- `ProviderScope` wrapper for global state
- Multiple interconnected providers for different concerns
- Reactive UI updates with automatic dependency management

**"Assister & Valider" Workflow:**
- **Phase 1 (Sending)**: Automatic navigation and prompt injection
- **Phase 2 (Observing)**: Real-time monitoring with MutationObserver
- **Phase 3 (Refining)**: Manual user control with validation option
- **Phase 4 (Extraction)**: Response extraction and return to Hub

**JavaScript Bridge Architecture:**
- Provider-specific bridges (AIStudioBridge, QwenBridge, etc.)
- Message queuing system for reliable communication
- Contract-based API with standardized events
- Error handling and recovery mechanisms

**WebView Management:**
- Individual WebView controllers per AI provider
- Session persistence through IndexedStack
- Bridge lifecycle management tied to WebView lifecycle
- Cross-platform compatibility (iOS/Android)

### Technical Implementation Details

**Selector Strategy:**
- Embedded fallback selectors for offline functionality
- Remote configuration fetching with local caching
- Multi-selector fallback for robustness
- Validation and error handling for invalid selectors

**Automation Engine:**
- CSS selector-based DOM interaction
- MutationObserver for response monitoring
- Timeout and retry mechanisms
- Graceful degradation on automation failure

**Error Recovery:**
- CAPTCHA and login requirement detection
- User handoff with clear instructions
- Automatic retry with exponential backoff
- Comprehensive error reporting

## Development Workflow

### Starting a New Session
1. Navigate to provider tabs (2-5) and log in manually
2. Return to Hub tab (1) and verify "✅ Prêt" status
3. Select provider and send prompt from native interface
4. System automatically navigates to provider and starts automation
5. Monitor progress through companion overlay
6. Validate response or continue manual refinement

### Provider Configuration
- Each provider has individual selector configuration
- Remote updates available through JSON configuration
- Local caching ensures offline functionality
- Validation ensures selector reliability

### Testing Strategy
- Unit tests for all core models and utilities
- Integration tests for complete workflow simulation
- Widget tests for UI components
- Manual testing required for actual AI provider interactions

## Important Implementation Details

**JavaScript Bridge Communication:**
```dart
// Native to JavaScript (automation start)
await bridge.startAutomation(prompt, options);

// JavaScript to Native (status updates)
window.kimiBridge.postMessage({
  event: 'onGenerationComplete',
  payload: { timestamp: Date.now() }
});
```

**State Management Example:**
```dart
// Watch automation state
final automationState = ref.watch(automationProvider);

// Start automation
ref.read(automationProvider.notifier).startAutomation(
  provider: AIProvider.kimi,
  prompt: userMessage,
);

// Handle completion
ref.read(automationProvider.notifier).completeAutomation();
```

**Selector Configuration:**
```json
{
  "kimi": {
    "promptTextarea": ["textarea[placeholder*='Kimi']", "textarea"],
    "sendButton": ["button[data-testid='send-button']", ".send-btn"],
    "assistantResponse": ["[data-message-role='assistant']", ".assistant-message"]
  }
}
```

## Code Quality Standards

**Linting:** Uses `flutter_lints: ^2.0.0` with comprehensive rule set
**Testing:** 22/25 tests passing with unit and integration coverage
**Code Style:** Clean Architecture with clear separation of concerns
**Error Handling:** Robust error recovery throughout the application

## Performance Considerations

**Memory Management:**
- IndexedStack efficiently manages multiple WebView instances
- JavaScript bridge cleanup prevents memory leaks
- Proper disposal patterns for all resources

**WebView Optimization:**
- Paused WebViews conserve CPU resources
- Session persistence avoids unnecessary reloads
- Efficient DOM observation with targeted MutationObserver

**Network Optimization:**
- Local caching reduces unnecessary remote calls
- Automatic retry mechanisms for failed requests
- Graceful degradation when remote configuration unavailable

## Security & Privacy

**Data Isolation:**
- Hub data isolated from WebView cookies/storage
- No cross-provider data leakage
- All processing performed locally on device

**JavaScript Security:**
- Input sanitization for all bridge communications
- Restricted JavaScript execution scope
- Validation of all incoming/outgoing messages

**Privacy-First Design:**
- No conversations sent to external servers
- All data stored locally on user's device
- User retains full control over their data

## Recent Major Changes

### Phase 1-7 Complete Transformation (2025-10-31)
- ✅ **Architecture migrated** from dynamic tabs to fixed 5-tab structure
- ✅ **Native Hub interface** implemented with modern chat UI
- ✅ **JavaScript automation** complete with provider-specific bridges
- ✅ **Riverpod state management** fully integrated
- ✅ **"Assister & Valider" workflow** functional with companion overlay
- ✅ **Comprehensive testing** suite with 22/25 passing tests
- ✅ **Blueprint implementation** following CWC philosophy principles

### Key Architectural Changes
- **From**: Dynamic tab browser → **To**: AI Hybrid Hub with automation
- **From**: Simple WebView management → **To**: JavaScript bridge integration
- **From**: Basic UI → **To**: Professional chat interface with workflow automation
- **From**: Manual interactions → **To**: Semi-automated assistance with user control

### New Technical Components
- `AutomationState` and workflow management system
- `JavaScriptBridge` for DOM automation
- `CompanionOverlay` for visual feedback
- Riverpod providers for comprehensive state management
- Selector dictionary with remote configuration support
- Prompt formatter for CWC-style structured prompts

### Testing Infrastructure
- Unit tests for all core models and utilities
- Widget tests for UI components
- Integration tests for workflow simulation
- 88% test pass rate on core functionality

The application now represents a complete **MVP AI Hub** ready for demonstration and user testing, with a solid foundation for future enhancements as outlined in BLUEPRINT.md.