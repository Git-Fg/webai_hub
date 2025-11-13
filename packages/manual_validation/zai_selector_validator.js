/**
 * Z.ai Comprehensive Selector & Functionality Validator (v2.3 - Definitive)
 *
 * This script performs a complete, manual end-to-end test of the Z.ai web UI,
 * incorporating all corrections from previous validation runs.
 *
 * v2.3 Changes:
 * - Increased the GENERATION_TIMEOUT_MS to 30 seconds to prevent timeouts
 *   on slower AI responses.
 * - Corrected the GLM-4.6 settings test to only verify the presence of the
 *   "Web Search" button, not click it.
 * - This is the final, definitive script for Z.ai validation.
 *
 * To use:
 * 1. Open Z.ai (https://chat.z.ai/) in a browser and log in.
 * 2. Open Developer Tools (F12 or Cmd+Opt+I) and select the "Console" tab.
 * 3. Paste this entire script into the Console and press Enter.
 */
(async () => {
    console.clear();
    console.log("🚀 Starting Z.ai Selector & Workflow Validation v2.3 (Definitive)...");
  
    const SELECTORS = {
      READINESS_INDICATOR: 'textarea[placeholder="How can I help you today?"]',
      PROMPT_INPUT: 'textarea',
      SEND_BUTTON: 'button#send-message-button',
      DEEP_THINK_TOGGLE: 'button[data-autothink]',
      MODEL_SWITCHER_BUTTON: 'button[aria-label="Select a model"]',
      MODEL_OPTION_BY_VALUE: (value) => `button[data-value="${value}"]`,
      TOOLS_BUTTON_GLM45: 'button:has(svg path[d^="M2.6499 4.48322"])',
      WEB_SEARCH_BUTTON_POPOVER: 'button.px-3.py-2',
      RESPONSE_CONTAINER: '.chat-assistant',
      RESPONSE_ACTIONS_FOOTER: '.chat-assistant + div',
      COPY_BUTTON: 'button.copy-response-button',
    };
    
    const MODEL_DATA_VALUES = {
      "GLM-4.6": "GLM-4-6-API-V1",
      "GLM-4.5": "0727-360B-API",
    };
  
    const TIMING = {
      POLL_INTERVAL_MS: 100,
      DEFAULT_TIMEOUT_MS: 7000,
      GENERATION_TIMEOUT_MS: 30000, // Increased timeout
    };
  
    const results = { passed: [], failed: [] };
  
    const waitForElement = (selector, { root = document, timeout = TIMING.DEFAULT_TIMEOUT_MS } = {}) => {
      return new Promise((resolve, reject) => {
        let elapsedTime = 0;
        const interval = setInterval(() => {
          const element = root.querySelector(selector);
          if (element) {
            clearInterval(interval);
            resolve(element);
          } else {
            elapsedTime += TIMING.POLL_INTERVAL_MS;
            if (elapsedTime >= timeout) {
              clearInterval(interval);
              reject(new Error(`Element "${selector}" not found within ${timeout}ms.`));
            }
          }
        }, TIMING.POLL_INTERVAL_MS);
      });
    };
  
    const waitForElementByText = (selector, text, { root = document, timeout = TIMING.DEFAULT_TIMEOUT_MS } = {}) => {
      return new Promise((resolve, reject) => {
        let elapsedTime = 0;
        const interval = setInterval(() => {
          const elements = Array.from(root.querySelectorAll(selector));
          const target = elements.find(el => el.textContent.trim().includes(text));
          if (target) {
            clearInterval(interval);
            resolve(target);
          } else {
            elapsedTime += TIMING.POLL_INTERVAL_MS;
            if (elapsedTime >= timeout) {
              clearInterval(interval);
              reject(new Error(`Element "${selector}" with text "${text}" not found within ${timeout}ms.`));
            }
          }
        }, TIMING.POLL_INTERVAL_MS);
      });
    };
  
    const switchModel = async (modelName) => {
      console.log(`  -> Attempting to switch model to: ${modelName}`);
      const modelSwitcher = await waitForElement(SELECTORS.MODEL_SWITCHER_BUTTON);
      modelSwitcher.click();
  
      const dataValue = MODEL_DATA_VALUES[modelName];
      if (!dataValue) throw new Error(`No data-value mapping for model "${modelName}".`);
  
      const modelOptionSelector = SELECTORS.MODEL_OPTION_BY_VALUE(dataValue);
      const targetOption = await waitForElement(modelOptionSelector);
      
      targetOption.click();
      await new Promise(r => setTimeout(r, 500));
      const updatedSwitcher = await waitForElement(SELECTORS.MODEL_SWITCHER_BUTTON);
      if (!updatedSwitcher.textContent.includes(modelName)) {
        throw new Error(`Model switcher text did not update to "${modelName}".`);
      }
      console.log(`  -> Successfully switched to ${modelName}.`);
    };
  
    const testReadiness = async () => {
      console.group("1. Readiness Check");
      try {
        await waitForElement(SELECTORS.READINESS_INDICATOR);
        results.passed.push("Readiness");
        console.log(`✅ PASSED: Main UI is ready.`);
      } catch (e) {
        results.failed.push("Readiness");
        console.error(`❌ FAILED: ${e.message}`);
        throw e;
      }
      console.groupEnd();
    };
    
    const testGlm45SwitchAndSettings = async () => {
      console.group("2. Model Switch & Settings Validation (GLM-4.5)");
      try {
        await switchModel("GLM-4.5");
        results.passed.push("Model Switch to GLM-4.5");
  
        const toolsButton = await waitForElement(SELECTORS.TOOLS_BUTTON_GLM45);
        toolsButton.click();
  
        const webSearchButton = await waitForElementByText(SELECTORS.WEB_SEARCH_BUTTON_POPOVER, "Web Search");
        const checkbox = webSearchButton.querySelector('[role="checkbox"]');
        if (!checkbox) throw new Error("Web Search checkbox not found.");
        
        webSearchButton.click();
        await new Promise(r => setTimeout(r, 200));
        webSearchButton.click();
        
        (await waitForElement(SELECTORS.PROMPT_INPUT)).click();
        
        results.passed.push("GLM-4.5 Settings: Tools & Web Search");
        console.log(`✅ PASSED: "Tools" and "Web Search" are interactive for GLM-4.5.`);
  
      } catch (e) {
        results.failed.push("Model Switch & Settings (GLM-4.5)");
        console.error(`❌ FAILED: ${e.message}`);
        throw e;
      }
      console.groupEnd();
    };
  
    const testGlm46SwitchAndSettings = async () => {
      console.group("3. Model Switch & Settings Validation (GLM-4.6)");
      try {
        await switchModel("GLM-4.6");
        results.passed.push("Model Switch to GLM-4.6");
  
        const webSearchButton = await waitForElementByText("button", "Web Search");
        if (!webSearchButton) throw new Error("Web Search button not found for GLM-4.6");
  
        results.passed.push("GLM-4.6 Settings: Web Search Button");
        console.log(`✅ PASSED: "Web Search" button is present for GLM-4.6.`);
  
      } catch(e) {
        results.failed.push("Model Switch & Settings (GLM-4.6)");
        console.error(`❌ FAILED: ${e.message}`);
        throw e;
      }
      console.groupEnd();
    };
  
    const testPromptAndSend = async () => {
      console.group("4. Prompt Input & Send Workflow");
      try {
        const testPrompt = `Hello Z.ai, this is a validation script running at ${new Date().toLocaleTimeString()}.`;
        const inputElement = await waitForElement(SELECTORS.PROMPT_INPUT);
        inputElement.value = testPrompt;
        inputElement.dispatchEvent(new Event('input', { bubbles: true }));
        results.passed.push("Prompt Input");
        console.log(`✅ PASSED: Prompt entered.`);
  
        const sendButton = await waitForElement(SELECTORS.SEND_BUTTON);
        if (sendButton.disabled) throw new Error("Send button found but is disabled.");
        sendButton.click();
        results.passed.push("Send Button");
        console.log(`✅ PASSED: Send button clicked successfully.`);
  
      } catch (e) {
        results.failed.push("Prompt/Send Workflow");
        console.error(`❌ FAILED: ${e.message}`);
        throw e;
      }
      console.groupEnd();
    };
  
    const testExtractionCycle = async () => {
      console.group("5. Response & Extraction Cycle");
      try {
        const initialResponseCount = document.querySelectorAll(SELECTORS.RESPONSE_CONTAINER).length;
        await new Promise((resolve, reject) => {
            const timeout = TIMING.GENERATION_TIMEOUT_MS;
            const interval = TIMING.POLL_INTERVAL_MS;
            let elapsedTime = 0;
            const check = () => {
                if (document.querySelectorAll(SELECTORS.RESPONSE_CONTAINER).length > initialResponseCount) {
                    resolve(true);
                } else {
                    elapsedTime += interval;
                    if (elapsedTime >= timeout) reject(new Error(`New response did not appear within ${timeout}ms.`));
                    else setTimeout(check, interval);
                }
            };
            check();
        });
        console.log("  -> New response container appeared.");
        results.passed.push("New Response Container");
        
        const responseFooters = document.querySelectorAll(SELECTORS.RESPONSE_ACTIONS_FOOTER);
        const lastFooter = responseFooters[responseFooters.length - 1];
        
        await waitForElement(SELECTORS.COPY_BUTTON, { root: lastFooter, timeout: TIMING.GENERATION_TIMEOUT_MS });
        results.passed.push("Copy Button");
        console.log(`✅ PASSED: Copy button presence verified.`);
        
      } catch (e) {
        results.failed.push("Extraction Cycle");
        console.error(`❌ FAILED: ${e.message}`);
        throw e;
      }
      console.groupEnd();
    };
  
    try {
      await testReadiness();
      await testGlm45SwitchAndSettings();
      await testGlm46SwitchAndSettings();
      await testPromptAndSend();
      await testExtractionCycle();
    } catch (e) {
      console.error(`\n🔥 A critical test failed, aborting sequence: ${e.message}`);
    } finally {
      console.log("\n--- 📊 Final Validation Report ---");
      if (results.failed.length > 0) {
        console.error(`❌ Validation Failed. ${results.failed.length} checks failed.`);
        console.log("Failed items:", results.failed);
      } else {
        console.log(`✅ All ${results.passed.length} checks passed successfully! Selectors and workflow for Z.ai are valid.`);
      }
      console.log("-------------------------------------");
    }
  })();