/**
 * Kimi Comprehensive Selector & Functionality Validator (v1.2 - Final)
 *
 * This script provides a complete, manual end-to-end test of the Kimi web UI
 * to validate that all critical CSS selectors and interaction logic are working
 * as expected before integrating them into the main TypeScript application.
 *
 * v1.2 Changes:
 * - Implemented a highly specific selector for the "Copy" button using data-v attributes.
 * - Confirmed the structural selector for the response text is correct.
 *
 * To use:
 * 1. Open Kimi (https://kimi.moonshot.cn/) in a browser, log in, and start a new chat.
 * 2. Open Developer Tools (F12 or Cmd+Opt+I) and select the "Console" tab.
 * 3. Paste this entire script into the Console and press Enter.
 * 4. Observe the logs to see which steps pass or fail.
 */
(async () => {
    console.clear();
    console.log("🚀 Starting Kimi Selector & Workflow Validation v1.2 (Final)...");
  
    // --- Configuration: Selectors derived from analysis ---
    const SELECTORS = {
      READINESS: '.current-model',
      PROMPT_INPUT: 'div[contenteditable=true]',
      SEND_BUTTON_CONTAINER: '.send-button-container',
      SEND_BUTTON: 'div.send-button',
      GENERATING_INDICATOR: 'path[d="M331.946667 379.904c-11.946667 23.466667-11.946667 54.186667-11.946667 115.626667v32.938666c0 61.44 0 92.16 11.946667 115.626667 10.538667 20.650667 27.306667 37.418667 47.957333 47.957333 23.466667 11.946667 54.186667 11.946667 115.626667 11.946667h32.938666c61.44 0 92.16 0 115.626667-11.946667 20.650667-10.538667 37.418667-27.306667 47.957333-47.957333 11.946667-23.466667 11.946667-54.186667 11.946667-115.626667v-32.938666c0-61.44 0-92.16-11.946667-115.626667a109.696 109.696 0 0 0-47.957333-47.957333c-23.466667-11.946667-54.186667-11.946667-115.626667-11.946667h-32.938666c-61.44 0-92.16 0-115.626667 11.946667-20.650667 10.538667-37.418667 27.306667-47.957333 47.957333z"]',
      RESPONSE_CONTAINER: '.segment-content',
      // WHY: The text content is inside the first direct child div of the main container.
      // This structural selector is more robust than relying on a specific class.
      RESPONSE_TEXT: '.segment-content > div:first-child',
      // WHY: Use the unique data-v attribute to target the copy button reliably.
      COPY_BUTTON: '.segment-assistant-actions-content div[data-v-10d40aa8]',
    };
  
    const TIMING = {
      POLL_INTERVAL_MS: 100,
      DEFAULT_TIMEOUT_MS: 7000,
    };
  
    const results = { passed: [], failed: [] };
  
    // --- Helper Functions ---
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
    
    const waitForElementToDisappear = (selector, { root = document, timeout = TIMING.DEFAULT_TIMEOUT_MS } = {}) => {
        return new Promise((resolve, reject) => {
            let elapsedTime = 0;
            const interval = setInterval(() => {
                const element = root.querySelector(selector);
                if (!element) {
                    clearInterval(interval);
                    resolve(true);
                } else {
                    elapsedTime += TIMING.POLL_INTERVAL_MS;
                    if (elapsedTime >= timeout) {
                        clearInterval(interval);
                        reject(new Error(`Element "${selector}" did not disappear within ${timeout}ms.`));
                    }
                }
            }, TIMING.POLL_INTERVAL_MS);
        });
    };
  
    // --- Test Suites ---
    const testReadiness = async () => {
      console.group("1. Readiness Check");
      try {
        await waitForElement(SELECTORS.READINESS);
        results.passed.push("Readiness");
        console.log(`✅ PASSED: Main UI is ready (found "${SELECTORS.READINESS}").`);
      } catch (e) {
        results.failed.push("Readiness");
        console.error(`❌ FAILED: ${e.message}`);
        throw e;
      }
      console.groupEnd();
    };
  
    const testPromptAndSend = async () => {
      console.group("2. Prompt Input & Send Workflow");
      const testPrompt = `Hello Kimi, this is a test from the validation script at ${new Date().toLocaleTimeString()}.`;
      try {
        const inputElement = await waitForElement(SELECTORS.PROMPT_INPUT);
        
        inputElement.dispatchEvent(new InputEvent('input', { bubbles: true, cancelable: true, inputType: 'insertText', data: testPrompt }));
        
        console.log(`✅ PASSED: Prompt entered into "${SELECTORS.PROMPT_INPUT}".`);
        results.passed.push("Prompt Input");
        
        await new Promise((resolve, reject) => {
            let elapsedTime = 0;
            const interval = setInterval(() => {
                const container = document.querySelector(SELECTORS.SEND_BUTTON_CONTAINER);
                if (container && !container.classList.contains('disabled')) {
                    clearInterval(interval);
                    resolve();
                } else {
                    elapsedTime += TIMING.POLL_INTERVAL_MS;
                    if (elapsedTime >= TIMING.DEFAULT_TIMEOUT_MS) {
                        clearInterval(interval);
                        reject(new Error("Send button did not become enabled in time."));
                    }
                }
            }, TIMING.POLL_INTERVAL_MS);
        });
  
        const sendButton = await waitForElement(SELECTORS.SEND_BUTTON);
        sendButton.click();
        console.log(`✅ PASSED: Send button clicked successfully.`);
        results.passed.push("Send Button");
        
      } catch (e) {
        results.failed.push("Prompt/Send Workflow");
        console.error(`❌ FAILED: ${e.message}`);
        throw e;
      }
      console.groupEnd();
    };
  
    const testExtractionCycle = async () => {
        console.group("3. Response & Extraction Cycle");
        try {
            // 1. Wait for generation to start and finish.
            await waitForElement(SELECTORS.GENERATING_INDICATOR, { timeout: 5000 });
            console.log("  -> Generation started (indicator appeared).");
            await waitForElementToDisappear(SELECTORS.GENERATING_INDICATOR, { timeout: 60000 });
            console.log("  -> Generation finished (indicator disappeared).");
            results.passed.push("Generation Indicator");
  
            // 2. Find the last response container.
            const responseContainers = document.querySelectorAll(SELECTORS.RESPONSE_CONTAINER);
            if (responseContainers.length === 0) throw new Error("No response containers found.");
            const lastResponseContainer = responseContainers[responseContainers.length - 1];
            results.passed.push("Response Container");
            
            // 3. Validate the copy button exists within it using the new, specific selector.
            await waitForElement(SELECTORS.COPY_BUTTON, { root: lastResponseContainer });
            console.log(`✅ PASSED: Copy button found in the last response.`);
            results.passed.push("Copy Button");
            
            // 4. Extract and log a preview of the response text using the corrected text selector.
            const responseTextElement = lastResponseContainer.querySelector(SELECTORS.RESPONSE_TEXT);
            if (!responseTextElement) throw new Error("Could not find response text element.");
            
            const responseText = responseTextElement.textContent.trim();
            if (!responseText) throw new Error("Response text element was found, but it is empty.");
            
            console.log(`✅ PASSED: Extraction successful. Preview: "${responseText.substring(0, 100)}..."`);
            results.passed.push("Extraction Logic");
            
        } catch (e) {
            results.failed.push("Extraction Cycle");
            console.error(`❌ FAILED: ${e.message}`);
            throw e;
        }
        console.groupEnd();
    };
  
    // --- Run and Report ---
    try {
      await testReadiness();
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
        console.log(`✅ All ${results.passed.length} checks passed successfully! Selectors for Kimi are valid.`);
      }
      console.log("-------------------------------------");
    }
  })();