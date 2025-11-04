
# Selector Validation Guide for AI Studio

## 1. Why This Guide is Critical

The web automation logic in `ts_src/` is highly dependent on specific CSS selectors to interact with the Google AI Studio web interface. These selectors are the most fragile part of the application, as Google can update their website structure at any time without notice, breaking our automation.

This document provides a **critical manual process** to validate our selectors against the **live, authenticated AI Studio website**.

Running this validation is the **first line of defense** against automation failures. It allows you to quickly determine if a problem comes from an outdated selector or from a bug in our own codebase.

## 2. When to Run This Script

You MUST run this validation script:

-   **Before any code modification** in `ts_src/chatbots/ai-studio.ts`.
-   **If automation fails unexpectedly** in the mobile app, especially during the "Edit" or "Extract" phases.
-   **As a routine check** every few days to ensure the AI Studio interface has not been updated.

## 3. How to Validate Selectors (Step-by-Step)

This process takes less than 60 seconds.

1.  **Open AI Studio**:
    Navigate to [Google AI Studio](https://aistudio.google.com/prompts/new_chat) in a desktop browser and ensure you are **logged in**. Make sure a conversation with at least one assistant response is visible.

2.  **Enter Mobile View**:
    -   Right-click anywhere on the page and select **"Inspect"** to open Developer Tools.
    -   Click the **"Toggle device toolbar"** icon (it looks like a phone and tablet 📱).
    -   Select a mobile device preset from the top bar (e.g., "iPhone 12 Pro").

3.  **Open the Console**:
    -   In the Developer Tools panel, navigate to the **"Console"** tab.

4.  **Run the Validation Script**:
    -   Copy the entire JavaScript script from the code block below.
    -   Paste it into the console and press `Enter`.

## 4. Interpreting the Results

The script will output a clear report in the console.

#### ✅ On Success
If all tests pass, you will see green `✅ SUCCESS` messages and a final confirmation:

```
✅ The entire extraction cycle (Entry -> Extraction -> Exit) was validated successfully!
```
This means your selectors are **correct**. If you are debugging an issue, the problem likely lies in the Dart code or the communication bridge, not the selectors themselves.

#### ❌ On Failure
If a test fails, you will see a red `❌ FAILURE` message indicating exactly which selector is broken:

```
❌ [FAILURE] Selector "Edit Button" (button[aria-label="Edit"]) not found.
```
This means the automation is **broken**. You must:
1.  Use the "Elements" tab in the Developer Tools to inspect the page and find the new, correct selector.
2.  Update the selector in the automation source code at `ts_src/chatbots/ai-studio.ts`.
3.  Update the selector in the validation script below to keep it synchronized with the source code.
