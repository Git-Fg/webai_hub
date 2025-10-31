# Next Steps Checklist

This document outlines the specific steps needed to complete the MVP and make it ready for production.

## ⚠️ Critical - Must Do Before First Run

### 1. Install Dependencies
```bash
cd /home/runner/work/webai_hub/webai_hub
flutter pub get
```

**Expected Output**: All packages successfully downloaded
**Troubleshooting**: If any package fails, check pubspec.yaml version constraints

### 2. Generate Isar Schemas
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

**Expected Output**: 
- Creates `lib/models/chat_message.g.dart`
- Message: "Succeeded after X.Xs with Y outputs"

**Troubleshooting**: 
- If fails, check that Isar models are properly annotated
- Ensure build_runner dependencies are correct

### 3. Verify Compilation
```bash
flutter analyze
```

**Expected Output**: "No issues found!"
**Action if errors**: Fix any compilation errors before proceeding

### 4. Run Tests
```bash
flutter test
```

**Expected Output**: All tests pass
**Action if fails**: Fix failing tests

## 📱 Testing Phase

### 5. Test on Emulator/Device
```bash
# For Android
flutter run -d android

# For iOS
flutter run -d ios
```

**Initial Verification**:
- [ ] App launches without crashes
- [ ] 5 tabs are visible (Hub, AI Studio, Qwen, Z-ai, Kimi)
- [ ] Can switch between tabs
- [ ] Hub tab shows chat interface
- [ ] WebView tabs load their respective URLs

### 6. Complete TEST_VALIDATION.md
Follow the comprehensive test plan in TEST_VALIDATION.md

**Critical Tests**:
- [ ] Test 1: Manual login to at least one provider (Kimi recommended)
- [ ] Test 2: Status detection shows "✅ Prêt"
- [ ] Test 3: Send automation works (prompt injection)
- [ ] Test 4: Generation detection works
- [ ] Test 5: Manual refinement works
- [ ] Test 6: Extraction and return to Hub works

## 🔧 Likely Adjustments Needed

### 7. Update Selectors (If Needed)
If automation fails, providers may have changed their UI:

**Steps**:
1. Open provider website in Chrome/Safari
2. Open DevTools (F12)
3. Inspect the element (textarea, send button, etc.)
4. Note the correct selector
5. Update `assets/json/selectors.json`
6. Hot reload the app (press 'r' in terminal)

**Common Selector Issues**:
| Provider | Element | Likely Issue |
|----------|---------|--------------|
| All | sendButton | SVG path changed |
| Kimi | isGenerating | Class name changed |
| Qwen | assistantResponse | Structure changed |

### 8. Check Console Output
Monitor Flutter console and browser console (via WebView debugging):

**Good Messages**:
```
[HubBridge] Initializing bridge for kimi
[HubBridge] Bridge ready for kimi
[WebAIHub] Bridge injected for kimi
[HubBridge] Found element with selector: textarea
```

**Bad Messages** (need fixing):
```
[HubBridge] Timeout: Could not find element
[WebAIHub] Failed to inject bridge: ...
```

## 🎨 UI Polish (Optional but Recommended)

### 9. Improve Visual Feedback
- [ ] Add loading spinner to WebViews during initial load
- [ ] Better error messages in overlay
- [ ] Add provider logos instead of generic icons
- [ ] Improve Hub chat UI styling

### 10. Add Onboarding
- [ ] Show welcome screen on first launch
- [ ] Guide user to log in to providers
- [ ] Explain the workflow
- [ ] Add help/info button

## 🔒 Security Review

### 11. Review Security Checklist
- [ ] Verify no sensitive data in logs
- [ ] Check that WebView sessions are isolated
- [ ] Ensure no data sent to external servers
- [ ] Verify Isar database is not world-readable

### 12. Privacy Policy
- [ ] Create privacy policy (even though local-only)
- [ ] Add settings screen with privacy information
- [ ] Allow user to clear all data

## 📦 Build for Distribution

### 13. Build Release Versions

**Android**:
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

**iOS**:
```bash
flutter build ios --release
# Then archive in Xcode
```

### 14. Test Release Builds
- [ ] Install release APK on Android device
- [ ] Test full workflow in release mode
- [ ] Check app size and performance
- [ ] Verify no debug information leaks

## 📝 Documentation Updates

### 15. Update Documentation
After testing, update these files:
- [ ] README.md - Add screenshots/demo GIF
- [ ] BUILD_GUIDE.md - Note any setup issues found
- [ ] TEST_VALIDATION.md - Fill in actual test results
- [ ] IMPLEMENTATION_SUMMARY.md - Update status

## 🚀 Deployment

### 16. Prepare for App Stores

**Android (Google Play)**:
- [ ] Create app listing
- [ ] Prepare screenshots
- [ ] Write description
- [ ] Set up billing (if needed)
- [ ] Submit for review

**iOS (App Store)**:
- [ ] Create app listing in App Store Connect
- [ ] Prepare screenshots
- [ ] Write description
- [ ] Set up TestFlight for beta testing
- [ ] Submit for review

## 🐛 Known Issues to Address

### Issues from Implementation
1. **flutter_gen_ai_chat_ui package**: May need version adjustment
2. **Isar schema generation**: First time may need --delete-conflicting-outputs
3. **WebView memory**: 4 persistent WebViews use significant RAM
4. **Selector maintenance**: Will need periodic updates

### Monitoring Plan
- [ ] Set up crash reporting (e.g., Sentry, Firebase Crashlytics)
- [ ] Monitor user feedback on selector failures
- [ ] Track which providers are most used
- [ ] Monitor database size growth

## 📊 Success Metrics

### Define Success Criteria
- [ ] App launches successfully on 100% of test devices
- [ ] Automation success rate > 90% (after selector tuning)
- [ ] No crashes during normal use
- [ ] User can complete full workflow without issues
- [ ] Session persistence works 100% of time

## 🎯 Post-MVP Enhancements

### Priority 1 (Next Sprint)
- [ ] Remote selector updates (BLUEPRINT Section 10.3)
- [ ] Model/options selection (BLUEPRINT Section 5.1)
- [ ] Better error recovery

### Priority 2
- [ ] File context support (BLUEPRINT Section 5.2)
- [ ] Clipboard integration
- [ ] Conversation export

### Priority 3
- [ ] More providers (Claude, ChatGPT, etc.)
- [ ] API-based providers
- [ ] Desktop/tablet layouts

## ✅ Final Checklist Before Launch

Before declaring MVP complete:
- [ ] All critical tests pass (TEST_VALIDATION.md)
- [ ] All 4 providers work correctly
- [ ] Documentation is complete and accurate
- [ ] No known critical bugs
- [ ] Performance is acceptable
- [ ] Privacy/security review complete
- [ ] App store listings ready (if applicable)

---

**Current Status**: Implementation complete, ready for build_runner and testing
**Next Action**: Run `flutter pub get && build_runner build`
**Estimated Time to MVP**: 2-4 hours (including testing and selector adjustment)
