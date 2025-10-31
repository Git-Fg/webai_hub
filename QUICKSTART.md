# Quick Start Guide for Developers

This is a condensed guide to get the WebAI Hub MVP running quickly.

## Prerequisites
- Flutter SDK 3.0+ installed and in PATH
- Android Studio or Xcode
- Git

## 5-Minute Setup

### Step 1: Clone and Navigate
```bash
git clone <repository-url>
cd webai_hub
```

### Step 2: One-Command Setup
```bash
./build.sh
```

This script will:
- Install all dependencies
- Generate Isar schemas
- Run code analysis

### Step 3: Run the App
```bash
flutter run
```

Or use your IDE's run button.

## First Use

1. **App opens on Hub tab** - This is the native chat interface
2. **Navigate to Kimi tab** (rightmost tab)
3. **Log in manually** to your Kimi account
4. **Return to Hub tab**
5. **Select "Kimi" from dropdown**
6. **Type "Hello" and press Send**
7. **Watch the magic happen!** ✨

## What You'll See

### Automation Flow
```
Hub (Type prompt) 
  → Auto-switch to Kimi
  → Overlay shows "Automatisation en cours..."
  → Prompt injected into Kimi
  → Kimi generates response
  → Overlay changes to "Prêt pour raffinage"
  → [Button] "✅ Valider et envoyer au Hub"
  → Click to extract response
  → Auto-return to Hub
  → Response appears in chat
```

## Project Structure (What You Need to Know)

```
lib/
├── main.dart              ← Main app (5-tab structure)
├── models/                ← Data models
│   ├── app_models.dart    ← UI state, provider configs
│   ├── chat_message.dart  ← Isar model (needs .g.dart)
│   └── providers.dart     ← 4 AI provider configs
├── providers/             ← Riverpod state management
│   └── app_providers.dart ← All app state + workflow
└── services/              ← Business logic
    ├── database_service.dart    ← Isar operations
    ├── prompt_formatter.dart    ← CWC-style formatting
    └── selector_service.dart    ← CSS selector loading

assets/
├── js/bridge.js           ← JavaScript automation engine
└── json/selectors.json    ← CSS selectors (may need updates)
```

## Common Issues & Quick Fixes

### "Database not initialized"
```bash
# Make sure DatabaseService.initialize() is in main()
# It should be there already
```

### "Bridge not ready" in console
```
This is normal during page load. Messages are queued.
```

### Automation Fails
```bash
# 1. Check provider's website in browser
# 2. Update selectors in assets/json/selectors.json
# 3. Hot reload (press 'r' in terminal)
```

### Build Runner Issues
```bash
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

### Package Conflicts
```bash
flutter pub upgrade
# or update version in pubspec.yaml
```

## Key Files to Understand

### 1. `main.dart` (Entry Point)
- 5 tabs defined
- Hub chat UI
- WebView wrappers
- Companion overlay

### 2. `app_providers.dart` (Brain)
- `WorkflowOrchestrator` - handles all automation
- State providers for UI
- Message handling

### 3. `bridge.js` (Bridge)
- `HubBridge` class
- DOM automation
- Event posting to native

### 4. `selectors.json` (Configuration)
- CSS selectors for each provider
- Defense-in-depth arrays
- **Most likely to need updates**

## Development Tips

### Hot Reload
Press `r` in the terminal while app is running to reload changes instantly.

### DevTools
Press `shift + ?` for help menu. Useful commands:
- `r` - Hot reload
- `R` - Full restart
- `q` - Quit
- `p` - Show performance overlay

### Debug WebView
For Android:
```bash
adb shell am set-debug-app --persistent your.package.name
```

Then open `chrome://inspect` in Chrome to see WebView console logs.

### Riverpod DevTools
Install the Riverpod DevTools extension in your IDE to inspect state.

## Testing Checklist

Quick validation that everything works:

- [ ] App launches
- [ ] Can switch between 5 tabs
- [ ] Can type in Hub chat
- [ ] Can log in to Kimi (Tab 5)
- [ ] Status shows "✅ Prêt" after login
- [ ] Sending prompt triggers automation
- [ ] Can see prompt injected in Kimi
- [ ] Overlay shows status
- [ ] Can validate and return to Hub
- [ ] Response appears in Hub chat

## Architecture Philosophy

This app follows 3 principles from BLUEPRINT.md:

1. **"Assister, ne pas cacher"** - Help the user, don't hide the process
   - All automation is visible
   - User can intervene anytime

2. **Robustesse** - Fail gracefully
   - Multiple selector fallbacks
   - Clear error messages
   - User can always take control

3. **Local-First** - Privacy by design
   - Everything stored locally
   - No external servers
   - No tracking

## Need Help?

### Documentation
- **Build Issues**: See BUILD_GUIDE.md
- **Testing**: See TEST_VALIDATION.md
- **Architecture**: See IMPLEMENTATION_SUMMARY.md
- **Next Steps**: See NEXT_STEPS.md

### Debugging
1. Check Flutter console for Dart errors
2. Check WebView console (chrome://inspect) for JS errors
3. Check that selectors.json matches current provider UIs

### Updating Selectors
1. Open provider in browser
2. Open DevTools (F12)
3. Inspect element (right-click → Inspect)
4. Copy selector from DevTools
5. Update selectors.json
6. Hot reload app

## That's It! 🎉

You should now have a working WebAI Hub. The automation might need selector tweaking, but the foundation is solid.

**Happy coding!** 🚀

---

**Pro Tip**: Start by getting Kimi working perfectly before testing other providers. Once you understand the workflow with one provider, the others follow the same pattern.
