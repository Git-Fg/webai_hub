# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 🎯 Project Philosophy

**IMPORTANT**: This is a **personal project** focused on **simplicity**, **modernity**, and **elegance** rather than enterprise complexity. The goal is to create beautiful, maintainable code that demonstrates advanced Flutter patterns while staying pragmatic and user-focused.

### Core Principles
- **🎯 Simplicity First** : Choose the simplest solution that works well
- **🚀 Modern Code** : Use current best practices and patterns
- **🧱 Clean Architecture** : Maintainable, readable, and testable code
- **🎨 Aesthetic Quality** : Beautiful UI and elegant code structure
- **📱 User Experience** : Focus on usability and delight

## Project Overview

This is an **AI Hybrid Hub** - a personal multi-provider AI assistant application implementing the complete "Assister & Valider" workflow. The project transforms a basic WebView tab manager into a sophisticated AI hub with native chat interface and JavaScript automation capabilities.

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

# Run only unit tests (109 tests)
flutter test test/unit/

# Run tests with coverage
flutter test --coverage

# Run specific test categories
flutter test test/unit/provider_tests/
flutter test test/unit/conversation_test.dart
flutter test test/unit/automation_state_test.dart
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

## 🎨 Development Guidelines

### Simplicity Principles
- **Avoid Over-Engineering** : Don't build complex systems for simple problems
- **Prefer Readability** : Code should be self-documenting when possible
- **Minimal Dependencies** : Use only necessary packages and keep them updated
- **Early Refactoring** : Keep code clean as you develop, not as a separate phase

### Code Style Rules
- **Modern Flutter Patterns** : Use const constructors, final variables, and null safety
- **Descriptive Naming** : Clear, concise names for functions, variables, and files
- **Small Functions** : Keep functions focused and under 30 lines when possible
- **Clear File Organization** : Follow feature-based structure consistently

### Testing Strategy
- **Pragmatic Testing** : Test business logic, not implementation details
- **Unit Tests Focus** : Priority on core functionality and edge cases
- **Avoid Complex Mocks** : Prefer simple test doubles over complex mocking
- **Maintain Test Coverage** : Keep tests passing and meaningful

## Code Quality Standards

**Linting:** Uses `flutter_lints: ^2.0.0` with comprehensive rule set
**Testing:** 109/109 tests passing with comprehensive unit coverage
**Code Style:** Clean Architecture with clear separation of concerns
**Error Handling:** Robust but simple error recovery throughout the application

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
- ✅ **Comprehensive testing** suite with 107/107 passing tests
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
- **109 unit tests** for all core models and utilities
- Widget tests for UI components
- Integration tests for workflow simulation
- **100% test pass rate** on core functionality
- **60-70% reduction** in manual testing requirements

## 📋 CHANGELOG Usage Guidelines

### 🔄 ALWAYS Update CHANGELOG.md

**CRITICAL:** Always update CHANGELOG.md when making changes to the codebase.

**When to update CHANGELOG.md:**
- **✨ Every new feature implementation** - Add under "Added" section
- **🐛 Bug fixes** - Add under "Fixed" section
- **🔄 API changes** - Add under "Changed" section
- **💥 Breaking changes** - Add under "Breaking Changes" section
- **⚡ Performance improvements** - Add under "Performance" section
- **📚 Documentation updates** - Add under "Documentation" section

### 📝 CHANGELOG Format

**Latest entries MUST be at the TOP of the file:**

```markdown
## [1.0.0+2] - 2025-10-31

### ✨ Added
- New feature description with user impact

### 🐛 Fixed
- Bug fix description with issue number if available

### ⚡ Performance
- Performance improvement description

### 📚 Documentation
- Documentation update description
```

### 🎯 CHANGELOG Best Practices

1. **Include semantic version numbers** (x.y.z)
2. **Use dates in YYYY-MM-DD format**
3. **Group changes by type** using proper section headers
4. **Be specific and descriptive** about what changed
5. **Include user impact** when relevant
6. **Reference related issues or PRs** when available

### 📅 Current Project Status

**Latest Version:** 1.0.0+2 (2025-10-31)
**Total Tests:** 109 passing ✅
**Architecture:** Complete MVP implementation
**Status:** 100% functional - personal project ready for use

The application represents a complete **AI Hub** demonstrating advanced Flutter patterns while maintaining simplicity and elegance. Perfect for personal use and as a foundation for future enhancements.

## 🌟 Personal Project Focus

This project is **NOT** an enterprise application. The focus is on:

### ✅ **What Matters**
- **Learning and Growth** : Exploring advanced Flutter patterns
- **Beautiful Code** : Creating maintainable, elegant solutions
- **User Delight** : Building something genuinely useful and pleasant
- **Technical Excellence** : Demonstrating craftsmanship and best practices

### ❌ **What to Avoid**
- **Over-Engineering** : No unnecessary complexity or enterprise patterns
- **Bureaucracy** : No heavy processes or excessive documentation
- **Feature Creep** : Stay focused on core functionality
- **Analysis Paralysis** : Progress over perfection

### 🎯 **Decision Making**
When in doubt, choose:
1. **Simplicity** over complexity
2. **Clarity** over cleverness
3. **Usability** over features
4. **Maintainability** over optimization

---

**This is a personal project celebrating the joy of building elegant, useful software with modern Flutter patterns.** 🚀