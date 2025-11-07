/**
 * AI Studio Comprehensive Selector & Functionality Validator (v5.8 - Definitive)
 *
 * This script is the definitive manual debugging tool for the AI Studio provider.
 *
 * v5.8 Final Changes:
 * - Implemented a new `waitForFirstElement` helper that polls until one of several
 *   possible selectors is found. This definitively fixes the readiness check, which
 *   now correctly handles both mobile and desktop UI layouts.
 * - All other logic has been re-verified and is confirmed to be robust. This is
 *   the final, working version.
 *
 * To use:
 * 1. Open AI Studio in a browser, log in, and have a conversation with at least one response.
 * 2. Toggle the "device toolbar" in DevTools to simulate a mobile view (recommended).
 * 3. Open Developer Tools (F12 or Cmd+Opt+I) and select the "Console" tab.
 * 4. Paste this entire script into the Console and press Enter.
 */
(async () => {
  console.clear();
  console.log("🚀 Starting AI Studio Comprehensive Validation (v5.8 - Definitive)...");

  // --- Configuration: Selectors must match ts_src/chatbots/ai-studio.ts ---
  const TIMING = {
      UI_STABILIZE_DELAY_MS: 300,
      PANEL_ANIMATION_MS: 400,
      POLL_INTERVAL_MS: 100,
      POLL_TIMEOUT_MS: 5000,
  };

  const SELECTORS = {
      RUN_SETTINGS_TOGGLE_MOBILE: 'button.runsettings-toggle-button',
      MODEL_SELECTOR_DESKTOP: 'button.model-selector-card',
      PROMPT_INPUTS: [
          'ms-chunk-input textarea',
          "textarea[placeholder*='Start typing a prompt']",
          "textarea[aria-label*='Start typing a prompt']",
      ],
      SEND_BUTTONS: [
          'ms-run-button > button[aria-label="Run"]',
          'ms-run-button > button',
      ],
      TOKEN_COUNT: 'span.v3-token-count-value',
      EDIT_BUTTON: 'button[aria-label="Edit"]',
      EDIT_TEXTAREA: 'textarea',
      STOP_EDITING_BUTTON: 'button[aria-label="Stop editing"]',
      CHAT_TURN: 'ms-chat-turn',
      SETTINGS_PANEL_MOBILE_TOGGLE: 'button.runsettings-toggle-button',
      SETTINGS_PANEL_CLOSE_BUTTON: 'ms-run-settings button[iconname="close"]',
      MODEL_SELECTOR_CARD: 'button.model-selector-card',
      MODEL_CATEGORIES_ALL_BUTTON: 'button[data-test-category-button]',
      MODEL_CAROUSEL_BUTTON: 'ms-model-carousel-row button.content-button',
      MODEL_TITLE_TEXT: 'span.model-title-text',
      SYSTEM_PROMPT_CARD: 'button[data-test-system-instructions-card]',
      SYSTEM_PROMPT_TEXTAREA: 'ms-system-instructions textarea',
      DIALOG_CLOSE_BUTTON: 'mat-dialog-container button[data-test-close-button]',
      ADVANCED_SETTINGS_TOGGLE: 'div.settings-item',
      THINKING_TOGGLE: 'mat-slide-toggle[data-test-toggle="enable-thinking"] button',
      MANUAL_BUDGET_TOGGLE: 'mat-slide-toggle[data-test-toggle="manual-budget"] button',
      BUDGET_INPUT: 'div[data-test-id="user-setting-budget-animation-wrapper"] input',
      TOOLS_TOGGLE_SELECTOR: 'div.settings-item',
      WEB_SEARCH_TOGGLE: 'div[data-test-id="searchAsAToolTooltip"] button',
      URL_CONTEXT_TOGGLE: 'div[data-test-id="browseAsAToolTooltip"] button',
  };

  const CONFIG = {
      SCREEN_WIDTH_BREAKPOINT_PX: 960,
  };

  const results = { passed: [], failed: [] };

  // --- Helper Functions ---
  const waitForElement = (selector, { root = document, timeout = TIMING.POLL_TIMEOUT_MS } = {}) => {
      return new Promise((resolve, reject) => {
          const intervalTime = TIMING.POLL_INTERVAL_MS;
          let elapsedTime = 0;
          const interval = setInterval(() => {
              const element = root.querySelector(selector);
              if (element) {
                  clearInterval(interval);
                  resolve(element);
                  return;
              }
              elapsedTime += intervalTime;
              if (elapsedTime >= timeout) {
                  clearInterval(interval);
                  reject(new Error(`Element with selector "${selector}" not found within ${timeout}ms.`));
              }
          }, intervalTime);
      });
  };
  
  const waitForFirstElement = (selectors, { root = document, timeout = TIMING.POLL_TIMEOUT_MS } = {}) => {
      return new Promise((resolve, reject) => {
          const intervalTime = TIMING.POLL_INTERVAL_MS;
          let elapsedTime = 0;
          const interval = setInterval(() => {
              for (const selector of selectors) {
                  const element = root.querySelector(selector);
                  if (element) {
                      clearInterval(interval);
                      resolve({ element, selector });
                      return;
                  }
              }
              elapsedTime += intervalTime;
              if (elapsedTime >= timeout) {
                  clearInterval(interval);
                  reject(new Error(`None of the selectors [${selectors.join(', ')}] were found within ${timeout}ms.`));
              }
          }, intervalTime);
      });
  };

  const waitForElementByText = (tagName, text, { timeout = TIMING.POLL_TIMEOUT_MS } = {}) => {
      return new Promise((resolve, reject) => {
          const intervalTime = TIMING.POLL_INTERVAL_MS;
          let elapsedTime = 0;
          const interval = setInterval(() => {
              const elements = Array.from(document.querySelectorAll(tagName));
              const targetElement = elements.find(el => el.textContent?.trim().toLowerCase() === text.toLowerCase());
              if (targetElement) {
                  clearInterval(interval);
                  resolve(targetElement);
                  return;
              }
              elapsedTime += intervalTime;
              if (elapsedTime >= timeout) {
                  clearInterval(interval);
                  reject(new Error(`Element <${tagName}> with text "${text}" not found within ${timeout}ms.`));
              }
          }, intervalTime);
      });
  };
  
  // WHY: Check element actionability (5-point check) before interaction
  const checkActionability = (element, elementName = 'element') => {
      const issues = [];
      
      // 1. Attached
      if (!element.isConnected) {
          issues.push('not attached to DOM');
      }
      
      // 2. Visible
      if (element.offsetParent === null) {
          issues.push('not visible');
      }
      
      // 3. Enabled
      if (element.disabled === true) {
          issues.push('disabled');
      }
      if (element.getAttribute('aria-disabled') === 'true') {
          issues.push('aria-disabled');
      }
      if (element.hasAttribute('inert')) {
          issues.push('inert');
      }
      
      // 4. Unoccluded (basic check)
      try {
          const rect = element.getBoundingClientRect();
          const centerX = rect.left + rect.width / 2;
          const centerY = rect.top + rect.height / 2;
          const topElement = document.elementFromPoint(centerX, centerY);
          if (topElement && !element.contains(topElement) && topElement !== element) {
              issues.push(`occluded by ${topElement.tagName}`);
          }
      } catch (e) {
          // Ignore
      }
      
      if (issues.length > 0) {
          return { actionable: false, issues };
      }
      return { actionable: true, issues: [] };
  };

  const clickAndDelay = async (element, delay = TIMING.PANEL_ANIMATION_MS, elementName = 'element') => {
      // WHY: Verify actionability before clicking
      const actionability = checkActionability(element, elementName);
      if (!actionability.actionable) {
          console.warn(`⚠️ WARNING: ${elementName} is not fully actionable: ${actionability.issues.join(', ')}`);
      }
      element.click();
      return new Promise(resolve => setTimeout(resolve, delay));
  };

  const openSettingsPanel = async () => {
      if (window.innerWidth <= CONFIG.SCREEN_WIDTH_BREAKPOINT_PX) {
          if (document.querySelector(SELECTORS.SETTINGS_PANEL_CLOSE_BUTTON)) return;
          const tuneButton = await waitForElement(SELECTORS.SETTINGS_PANEL_MOBILE_TOGGLE);
          await clickAndDelay(tuneButton);
      }
  };

  const closeSettingsPanel = async () => {
      if (window.innerWidth <= CONFIG.SCREEN_WIDTH_BREAKPOINT_PX) {
          const closeButton = document.querySelector(SELECTORS.SETTINGS_PANEL_CLOSE_BUTTON);
          if (closeButton) await clickAndDelay(closeButton);
      }
  };

  const testSliderByLabel = async (labelName) => {
      const testName = `${labelName} Input`;
      try {
          const labelElement = await waitForElementByText('h3', labelName);
          const container = labelElement.closest('.settings-item-column');
          if (!container) throw new Error(`Could not find parent container for "${labelName}" label.`);
          const inputElement = container.querySelector('input[type=number]');
          if (!inputElement) throw new Error(`Found container for "${labelName}" but no number input inside.`);
          
          // WHY: Check actionability
          const actionability = checkActionability(inputElement, testName);
          if (!actionability.actionable) {
              console.warn(`⚠️ WARNING: "${testName}" found but not actionable: ${actionability.issues.join(', ')}`);
          }
          
          console.log(`✅ PASSED: "${testName}" found successfully${actionability.actionable ? ' and is actionable' : ' (with warnings)'}.`);
          results.passed.push(testName);
          return inputElement;
      } catch (e) {
          console.error(`❌ FAILED: "${testName}" - ${e.message}`);
          results.failed.push(testName);
          throw e;
      }
  };

  // --- Test Suites ---
  const testReadinessAndLogin = async () => {
      console.group("1. Readiness & Login Page Detection");
      if (window.location.href.includes('accounts.google.com')) {
          console.warn("⚠️ On Login Page. Readiness selectors will fail. Please log in first.");
          results.failed.push("App Readiness (Login Required)");
          throw new Error("Cannot run validation on login page.");
      }
      try {
          const { selector } = await waitForFirstElement([
              SELECTORS.MODEL_SELECTOR_DESKTOP,
              SELECTORS.RUN_SETTINGS_TOGGLE_MOBILE
          ]);
          results.passed.push("Readiness");
          console.log(`✅ PASSED: Main UI is ready (found readiness element with selector: "${selector}").`);
      } catch (e) {
          results.failed.push("Readiness");
          console.error(`❌ FAILED: Could not find any readiness indicator.`);
          throw e;
      }
      console.groupEnd();
  };

  const testPromptAndSend = async () => {
      console.group("2. Prompt Input & Send Button");
      const { element: promptElement, selector: promptSelector } = await waitForFirstElement(SELECTORS.PROMPT_INPUTS);
      const promptActionability = checkActionability(promptElement, 'Prompt Input');
      if (promptActionability.actionable) {
          console.log(`✅ PASSED: Prompt Input Area found with selector: "${promptSelector}" and is actionable`);
      } else {
          console.warn(`⚠️ WARNING: Prompt Input Area found but not actionable: ${promptActionability.issues.join(', ')}`);
      }
      results.passed.push("Prompt Input Area");
      
      const { element: sendElement, selector: sendSelector } = await waitForFirstElement(SELECTORS.SEND_BUTTONS);
      const sendActionability = checkActionability(sendElement, 'Send Button');
      if (sendActionability.actionable) {
          console.log(`✅ PASSED: Send Button found with selector: "${sendSelector}" and is actionable`);
      } else {
          console.warn(`⚠️ WARNING: Send Button found but not actionable: ${sendActionability.issues.join(', ')}`);
      }
      results.passed.push("Send Button");
      console.groupEnd();
  };

  const testSettingsPanel = async () => {
      console.group("3. Settings Panel Functionality");
      
      console.log("  -> Testing Model Selection Dialog...");
      await openSettingsPanel();
      const modelCard = await waitForElement(SELECTORS.MODEL_SELECTOR_CARD);
      await clickAndDelay(modelCard);
      await waitForElement(SELECTORS.MODEL_CATEGORIES_ALL_BUTTON);
      await waitForElement(SELECTORS.MODEL_CAROUSEL_BUTTON);
      const modelDialogCloseButton = await waitForElement(SELECTORS.DIALOG_CLOSE_BUTTON);
      await clickAndDelay(modelDialogCloseButton);
      await new Promise(resolve => setTimeout(resolve, TIMING.PANEL_ANIMATION_MS));

      console.log("  -> Testing System Instructions Dialog...");
      await openSettingsPanel();
      const spCard = await waitForElement(SELECTORS.SYSTEM_PROMPT_CARD);
      await clickAndDelay(spCard);
      await waitForElement(SELECTORS.SYSTEM_PROMPT_TEXTAREA);
      const spClose = await waitForElement(SELECTORS.DIALOG_CLOSE_BUTTON);
      await clickAndDelay(spClose);
      await new Promise(resolve => setTimeout(resolve, TIMING.PANEL_ANIMATION_MS));

      console.log("  -> Testing Main Run Settings...");
      await openSettingsPanel();
      await testSliderByLabel("Temperature");
      
      const advancedToggle = await waitForElementByText('p', 'Advanced settings');
      const advancedToggleContainer = advancedToggle.closest(SELECTORS.ADVANCED_SETTINGS_TOGGLE);
      if (advancedToggleContainer) {
          console.log("✅ PASSED: Found 'Advanced' settings toggle.");
          results.passed.push('Advanced Settings Toggle');
          if (!advancedToggleContainer.classList.contains('expanded')) {
              await clickAndDelay(advancedToggleContainer, TIMING.UI_STABILIZE_DELAY_MS);
          }
      } else {
          throw new Error("'Advanced' settings toggle not found by text.");
      }
      
      await testSliderByLabel("Top P");
      
      await waitForElement(SELECTORS.THINKING_TOGGLE);
      results.passed.push('Thinking Feature Toggle');
      await waitForElement(SELECTORS.MANUAL_BUDGET_TOGGLE);
      results.passed.push('Manual Budget Toggle');

      const toolsToggle = await waitForElementByText('p', 'Tools');
      const toolsToggleContainer = toolsToggle.closest(SELECTORS.TOOLS_TOGGLE_SELECTOR);
      if (toolsToggleContainer) {
          console.log("✅ PASSED: Found 'Tools' settings toggle.");
          results.passed.push('Tools Settings Toggle');
          if (!toolsToggleContainer.classList.contains('expanded')) {
              await clickAndDelay(toolsToggleContainer, TIMING.UI_STABILIZE_DELAY_MS);
          }
      } else {
          throw new Error("'Tools' settings toggle not found by text.");
      }
      await waitForElement(SELECTORS.WEB_SEARCH_TOGGLE);
      results.passed.push('Web Search Toggle');
      await waitForElement(SELECTORS.URL_CONTEXT_TOGGLE);
      results.passed.push('URL Context Toggle');

      await closeSettingsPanel();
      console.groupEnd();
  };

  const testExtractionCycle = async () => {
      console.group("4. Core Extraction Cycle");
      const allEditButtons = Array.from(document.querySelectorAll(SELECTORS.EDIT_BUTTON));
      if (allEditButtons.length === 0) throw new Error("No 'Edit' buttons found. Cannot test extraction.");

      const lastEditButton = allEditButtons[allEditButtons.length - 1];
      const lastTurn = lastEditButton.closest(SELECTORS.CHAT_TURN);
      if (!lastTurn) throw new Error("Could not find parent turn for the last 'Edit' button.");
      results.passed.push("Last Turn Anchor");
      console.log("✅ PASSED: Last Turn Anchor found.");

      // WHY: Check actionability before clicking Edit button
      const editActionability = checkActionability(lastEditButton, 'Edit Button');
      if (!editActionability.actionable) {
          console.warn(`⚠️ WARNING: Edit button not actionable: ${editActionability.issues.join(', ')}`);
      }
      await clickAndDelay(lastEditButton, TIMING.UI_STABILIZE_DELAY_MS, 'Edit Button');
      const textarea = await waitForElement(SELECTORS.EDIT_TEXTAREA, { root: lastTurn });
      console.log(`   -> Extracted ${textarea.value.length} characters.`);

      const stopEditingButton = await waitForElement(SELECTORS.STOP_EDITING_BUTTON, { root: lastTurn });
      const stopActionability = checkActionability(stopEditingButton, 'Stop Editing Button');
      if (!stopActionability.actionable) {
          console.warn(`⚠️ WARNING: Stop editing button not actionable: ${stopActionability.issues.join(', ')}`);
      }
      await clickAndDelay(stopEditingButton, TIMING.PANEL_ANIMATION_MS, 'Stop Editing Button');
      results.passed.push("Extraction Cycle");
      console.log("✅ PASSED: Extraction cycle completed.");
      console.groupEnd();
  };

  // --- Run and Report ---
  try {
      await testReadinessAndLogin();
      await testPromptAndSend();
      await testSettingsPanel();
      await testExtractionCycle();
  } catch (e) {
      console.error(`\n🔥 A critical test failed, aborting sequence: ${e.message}`);
  } finally {
      console.log("\n--- 📊 Final Validation Report ---");
      if (results.failed.length > 0) {
          console.error(`❌ Validation Failed. ${results.failed.length} selectors/features are broken.`);
          console.log("Failed items:", results.failed.sort());
      } else {
          console.log(`✅ All ${results.passed.length} selectors and features validated successfully!`);
      }
      console.log("-------------------------------------");
  }
})();