# WebAI Hub - MVP Test Validation Plan

This document outlines the testing procedure to validate the MVP implementation following BLUEPRINT.md Section 7 requirements.

## Test Environment Setup

### Prerequisites
- Application built and installed on a test device
- Internet connection available
- Test accounts for at least one AI provider (recommended: Kimi)

## Phase 7: End-to-End Testing

### Test 1: Onboarding (Manual Phase)

**Objective**: Verify that users can manually log in to AI providers

**Steps**:
1. Launch the application
2. Observe starting on the **Hub (Tab 1)** with an empty state
3. Navigate to **Kimi (Tab 5)**
4. Manually log in to Kimi using your credentials
5. Wait for the Kimi chat interface to load fully

**Expected Results**:
- [ ] App opens on Hub tab
- [ ] Can navigate to Kimi tab
- [ ] Can successfully log in
- [ ] Kimi chat interface is visible and functional
- [ ] Session persists after closing/reopening app

**Pass/Fail**: ___________

---

### Test 2: Status Detection (Verification Phase)

**Objective**: Verify that the app correctly detects provider readiness

**Steps**:
1. After logging in to Kimi, return to **Hub (Tab 1)**
2. Check the provider selector dropdown
3. Verify Kimi's status indicator

**Expected Results**:
- [ ] Provider dropdown shows "Kimi: ✅ Prêt"
- [ ] Other providers show "❌ Connexion requise" or "❓ Inconnu"
- [ ] Can select Kimi from the dropdown

**Pass/Fail**: ___________

---

### Test 3: Automation Send Phase (Phase 1)

**Objective**: Verify prompt injection automation

**Steps**:
1. On **Hub (Tab 1)**, select "Kimi" from the provider dropdown
2. Type "Salut" in the chat input
3. Press the Send button
4. Observe the automation

**Expected Results**:
- [ ] App automatically switches to **Kimi (Tab 5)**
- [ ] Companion overlay appears with message "Automatisation en cours..."
- [ ] "Annuler" button is visible in the overlay
- [ ] "Salut" appears in Kimi's textarea
- [ ] Send button is automatically clicked
- [ ] Kimi begins generating a response

**Pass/Fail**: ___________

---

### Test 4: Observation Phase (Phase 2)

**Objective**: Verify that the app detects when generation completes

**Steps**:
1. Continue from Test 3
2. Watch the Kimi WebView as it generates
3. Observe the "Stop" button during generation
4. Wait for generation to complete

**Expected Results**:
- [ ] During generation, Kimi's "Stop" button is visible
- [ ] Overlay remains showing "Automatisation en cours..."
- [ ] When generation completes, overlay changes state
- [ ] New message: "Prêt pour raffinage"
- [ ] "✅ Valider et envoyer au Hub" button appears
- [ ] "❌ Annuler" button still visible

**Pass/Fail**: ___________

---

### Test 5: Refinement Phase (Phase 3)

**Objective**: Verify manual control during refinement

**Steps**:
1. Continue from Test 4
2. DO NOT click "Valider" yet
3. Manually type "Reformule ta réponse" in Kimi's textarea
4. Manually click Kimi's send button
5. Wait for the second response
6. Observe the overlay state

**Expected Results**:
- [ ] Can manually interact with Kimi's interface
- [ ] Second prompt is sent successfully
- [ ] Kimi generates a second response
- [ ] Overlay remains in "Prêt pour raffinage" state
- [ ] "Valider" button remains available

**Pass/Fail**: ___________

---

### Test 6: Validation Phase (Phase 4)

**Objective**: Verify extraction and return to Hub

**Steps**:
1. Continue from Test 5
2. Click "✅ Valider et envoyer au Hub" button
3. Observe the extraction and navigation

**Expected Results**:
- [ ] App automatically switches back to **Hub (Tab 1)**
- [ ] Overlay disappears
- [ ] Hub shows both messages:
  - Original prompt "Salut"
  - **Second (reformulated) response** from Kimi (NOT the first response)
- [ ] Response preserves formatting (if applicable)
- [ ] Chat history is persisted (visible after app restart)

**Pass/Fail**: ___________

---

### Test 7: Error Handling - Injection Failed

**Objective**: Verify graceful handling of automation failures

**Steps**:
1. Attempt to send a prompt to a provider that requires login
2. Or manually break the selector (testing only)

**Expected Results**:
- [ ] Overlay shows error message: "⚠️ Automatisation échouée..."
- [ ] Error message indicates the problem (e.g., "Connexion requise")
- [ ] Overlay hides after showing error
- [ ] User can manually resolve and retry
- [ ] Hub message shows "Échec de l'envoi"

**Pass/Fail**: ___________

---

### Test 8: Cancellation

**Objective**: Verify user can cancel automation

**Steps**:
1. Start sending a prompt (Test 3)
2. Click "❌ Annuler" button during automation or refinement
3. Observe the result

**Expected Results**:
- [ ] Automation stops
- [ ] Overlay disappears
- [ ] Remains on provider tab (does not return to Hub)
- [ ] Hub message updated to "Annulé par l'utilisateur"
- [ ] Can interact manually with provider

**Pass/Fail**: ___________

---

### Test 9: Multi-Provider Support

**Objective**: Verify that all 4 providers work

**Steps**:
1. Log in to each provider manually (AI Studio, Qwen, Z-ai, Kimi)
2. From Hub, send a test prompt to each provider
3. Verify automation works for each

**Expected Results**:
- [ ] AI Studio: Automation works correctly
- [ ] Qwen: Automation works correctly
- [ ] Z-ai: Automation works correctly
- [ ] Kimi: Automation works correctly
- [ ] Each provider's selectors are correct
- [ ] Extraction returns proper content for each

**Pass/Fail for each**:
- AI Studio: ___________
- Qwen: ___________
- Z-ai: ___________
- Kimi: ___________

---

### Test 10: Session Persistence

**Objective**: Verify WebView sessions persist

**Steps**:
1. Log in to Kimi
2. Close the app completely
3. Reopen the app
4. Navigate to Kimi tab

**Expected Results**:
- [ ] Still logged in to Kimi (no re-login required)
- [ ] Chat history in Hub is preserved
- [ ] Provider status still shows "✅ Prêt"

**Pass/Fail**: ___________

---

## Summary

### Test Results
- Total Tests: 10
- Passed: ___ / 10
- Failed: ___ / 10

### Critical Issues Found
(List any critical issues that prevent MVP functionality)

1. 
2. 
3. 

### Non-Critical Issues Found
(List any issues that don't block MVP but should be fixed)

1. 
2. 
3. 

### Recommendations

**MVP Ready**: Yes / No

**Next Steps**:
1. 
2. 
3. 

---

## Notes

### Browser Console Messages
(Document any important console messages from the JavaScript bridge)

```
[Example console output here]
```

### Selector Validation
(Document if any selectors needed updating)

| Provider | Selector Type | Old Selector | New Selector | Status |
|----------|--------------|--------------|--------------|--------|
| Example  | sendButton   | button[...] | button[...] | ✅ Fixed |

---

**Tester Name**: ___________________
**Date**: ___________________
**App Version**: ___________________
**Test Device**: ___________________
