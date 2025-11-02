# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**AI Hybrid Hub** is a Flutter application designed to create a multi-provider AI assistant interface. The project implements an "Assister & Valider" workflow that combines native mobile UI with web-based AI provider interactions through JavaScript automation.

**Current Status**: Fresh Flutter project with default counter app implementation
**Vision**: Multi-tab AI Hub with native chat interface and WebView automation capabilities

## Application Architecture

### Core Concept
The application bridges native Flutter UI with web-based AI providers through automated interactions, enabling users to:
- Use a native chat interface for AI conversations
- Automatically interact with multiple AI provider web interfaces
- Maintain conversation history across providers
- Validate and refine AI responses through a structured workflow

### Target Structure
```
lib/
├── main.dart                    # Application entry point
├── features/
│   ├── hub/                     # Native chat interface
│   │   ├── providers/           # State management
│   │   └── widgets/             # Chat UI components
│   ├── webview/                 # AI provider integration
│   │   ├── providers/           # WebView management
│   │   ├── widgets/             # WebView screens
│   │   └── bridge/              # JavaScript communication
│   └── automation/              # Workflow management
│       ├── providers/           # Automation state
│       └── widgets/             # Visual feedback
├── shared/
│   ├── models/                  # Data models
│   ├── constants/               # App constants
│   └── utils/                   # Utility functions
└── assets/
    ├── js/                      # JavaScript automation scripts
    └── json/                    # Configuration files
```

### Technology Stack
- **Framework**: Flutter with modern Dart patterns
- **State Management**: Riverpod ecosystem
- **WebView Integration**: InAppWebView for JavaScript automation
- **Architecture**: Clean Architecture with feature-based organization
- **Code Generation**: Automated provider and model generation

## Key Features

### Multi-Provider Support
- Integration with multiple AI providers (Google AI Studio, Qwen, Z-ai, Kimi)
- Provider-specific automation engines
- Unified native interface for all interactions

### "Assister & Valider" Workflow
A structured 4-phase automation process:
1. **Sending** - Automated prompt delivery to provider
2. **Observing** - Real-time response monitoring
3. **Refining** - User control and validation options
4. **Extraction** - Response capture and native display

### Native Chat Interface
- Modern bubble-based conversation UI
- Provider selection and management
- Conversation history and context
- Real-time status indicators

### JavaScript Automation
- DOM manipulation for web interactions
- MutationObserver for response monitoring
- Bridge communication between native and web contexts
- Error handling and recovery mechanisms

## Provider Integration

### Google AI Studio (Primary Target)
- **URL**: `https://aistudio.google.com/prompts/new_chat`
- **Automation**: CSS selector-based DOM interaction
- **Session**: Manual user login with automatic persistence

### Future Providers
- Qwen AI integration
- Z-ai platform support
- Kimi AI automation

## Data Management

### State Architecture
- In-memory conversation state management
- Provider-specific session handling
- Cross-provider conversation aggregation
- Real-time UI updates through reactive state

### Session Persistence
- WebView cookie and storage management
- Login state preservation across app sessions
- Provider-specific authentication handling

## User Interface Design

### Navigation Pattern
- Fixed 5-tab architecture (Hub + 4 AI providers)
- Tab-based navigation with automatic switching
- Visual status indicators for provider availability
- Seamless transition between native and web interfaces

### Chat Interface
- Modern bubble design for messages
- Provider selection and switching
- Context-aware input suggestions
- Response validation and refinement tools

## Security & Privacy

### Data Isolation
- Native app data separated from WebView contexts
- No cross-provider data leakage
- Local-only processing and storage

### Privacy Design
- User-controlled data retention
- No external data transmission beyond provider APIs
- Transparent data handling practices

## Project Status

### Current Implementation
- Basic Flutter project structure
- Default counter app implementation
- Comprehensive architectural blueprint available

### Implementation Roadmap
The project follows a phased approach:
1. **MVP** - Google AI Studio integration validation
2. **Expansion** - Additional provider support
3. **Enhancement** - Advanced features and optimizations
4. **Refinement** - UI/UX improvements and performance

This project represents an exploration of native-web integration patterns for AI interactions, focusing on user experience and automation reliability while maintaining clean, maintainable code architecture.