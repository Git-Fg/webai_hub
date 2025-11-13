// ts_src/chatbots/z-ai.ts

import { Chatbot, AutomationOptions } from '../types/chatbot';
import { waitForActionableElement } from '../utils/wait-for-actionable-element';
import { waitForElementByText } from '../utils/wait-for-element';

export const SELECTORS = {
  PROMPT_INPUT: 'textarea[placeholder="How can I help you today?"]',
  SEND_BUTTON: 'button#send-message-button',
  DEEP_THINK_TOGGLE: 'button[data-autothink]',
  MODEL_SWITCHER_BUTTON: 'button[aria-label="Select a model"]',
  MODEL_OPTION_BY_VALUE: (value: string) => `button[data-value="${value}"]`,
  TOOLS_BUTTON_GLM45: 'button:has(svg path[d^="M2.6499 4.48322"])',
  WEB_SEARCH_BUTTON_POPOVER: 'button.px-3.py-2',
  RESPONSE_CONTAINER: '.chat-assistant',
  RESPONSE_ACTIONS_FOOTER: '.chat-assistant + div',
  COPY_BUTTON: 'button.copy-response-button',
};

const MODEL_DATA_VALUES: Record<string, string> = {
  'GLM-4.6': 'GLM-4-6-API-V1',
  'GLM-4.5': '0727-360B-API',
};

class ZAiChatbot implements Chatbot {
  async waitForReady(): Promise<void> {
    await waitForActionableElement([SELECTORS.PROMPT_INPUT], 'Prompt Input');
  }

  private async _switchModel(modelName: string): Promise<void> {
    console.log(`[Z.ai] Switching model to: ${modelName}`);
    const modelSwitcher = await waitForActionableElement([SELECTORS.MODEL_SWITCHER_BUTTON], 'Model Switcher');
    
    // Don't switch if already on the correct model
    if (modelSwitcher.textContent?.includes(modelName)) {
      console.log(`[Z.ai] Model is already set to ${modelName}.`);
      return;
    }
    modelSwitcher.click();

    const dataValue = MODEL_DATA_VALUES[modelName];
    if (!dataValue) throw new Error(`[Z.ai] No data-value mapping for model "${modelName}".`);

    const modelOptionSelector = SELECTORS.MODEL_OPTION_BY_VALUE(dataValue);
    const targetOption = await waitForActionableElement([modelOptionSelector], `Model Option ${modelName}`);
    
    targetOption.click();
    // WHY: Wait for UI to update after model switch
    // eslint-disable-next-line custom/disallow-timeout-for-waits
    await new Promise(r => setTimeout(r, 500));
  }

  async applyAllSettings(options: AutomationOptions): Promise<void> {
    if (options.model) {
      await this._switchModel(options.model);
    }

    if (options.disableThinking !== undefined) {
      const deepThinkToggle = await waitForActionableElement([SELECTORS.DEEP_THINK_TOGGLE], 'Deep Think Toggle');
      const isEnabled = deepThinkToggle.getAttribute('data-autothink') === 'true';
      const shouldBeEnabled = !options.disableThinking;
      if (isEnabled !== shouldBeEnabled) {
        deepThinkToggle.click();
        console.log(`[Z.ai] Toggled Deep Think to: ${shouldBeEnabled}`);
      }
    }

    if (options.useWebSearch !== undefined) {
      if (options.model === 'GLM-4.5') {
        const toolsButton = await waitForActionableElement([SELECTORS.TOOLS_BUTTON_GLM45], 'Tools Button');
        toolsButton.click();
        const webSearchButton = await waitForElementByText(SELECTORS.WEB_SEARCH_BUTTON_POPOVER, 'Web Search');
        const checkbox = webSearchButton.querySelector('[role="checkbox"]');
        if (!checkbox) throw new Error('[Z.ai] Web Search checkbox not found in popover.');
        const isEnabled = checkbox.getAttribute('data-state') === 'checked';
        if (isEnabled !== options.useWebSearch) {
          webSearchButton.click();
          console.log(`[Z.ai] Toggled Web Search (GLM-4.5) to: ${options.useWebSearch}`);
        }
        (await waitForActionableElement([SELECTORS.PROMPT_INPUT], 'Prompt Input')).click(); // Close popover
      } else { // Assumes GLM-4.6 or other models with direct button
        // WHY: Use text-based search for GLM-4.6 as validated in the test script
        const webSearchButton = await waitForElementByText('button', 'Web Search');
        const isEnabled = !webSearchButton.className.includes('text-gray-400');
        if (isEnabled !== options.useWebSearch) {
          webSearchButton.click();
          console.log(`[Z.ai] Toggled Web Search to: ${options.useWebSearch}`);
        }
      }
    }
  }

  async sendPrompt(prompt: string): Promise<void> {
    const inputElement = await waitForActionableElement<HTMLTextAreaElement>([SELECTORS.PROMPT_INPUT], 'Prompt Input');
    inputElement.value = prompt;
    inputElement.dispatchEvent(new Event('input', { bubbles: true }));

    const sendButton = await waitForActionableElement([SELECTORS.SEND_BUTTON], 'Send Button');
    sendButton.click();

    await this._waitForResponseFinalization();
  }

  private async _waitForResponseFinalization(): Promise<void> {
    const initialFooterCount = document.querySelectorAll(SELECTORS.RESPONSE_ACTIONS_FOOTER).length;

    await new Promise<void>((resolve, reject) => {
        const timeout = 30000;
        const interval = 200;
        let elapsedTime = 0;

        const check = async () => {
            const currentFooters = document.querySelectorAll(SELECTORS.RESPONSE_ACTIONS_FOOTER);
            if (currentFooters.length > initialFooterCount) {
                // WHY: A new footer exists. Now we must confirm the copy button within it is ready.
                const lastFooter = currentFooters[currentFooters.length - 1] as HTMLElement;
                try {
                    // Use a short timeout here, as the button should appear almost instantly.
                    const actionableButton = await waitForActionableElement<HTMLElement>(
                        [SELECTORS.COPY_BUTTON],
                        'Copy Button in new footer',
                        2000,
                        0,
                    );
                    const footerCopyButton = lastFooter.querySelector(SELECTORS.COPY_BUTTON);
                    if (footerCopyButton || actionableButton) {
                      console.log('[Z.ai] Response finalized: New footer with actionable copy button found.');
                      resolve();
                      return;
                    }
                } catch {
                    // Not ready yet, continue polling.
                }
            }

            elapsedTime += interval;
            if (elapsedTime >= timeout) {
                reject(new Error(`[Z.ai] Response did not finalize (copy button not found) within ${timeout}ms.`));
            } else {
                // WHY: Polling mechanism for response detection, not a UI wait
                // eslint-disable-next-line custom/disallow-timeout-for-waits
                setTimeout(check, interval);
            }
        };
        check();
    });
  }

  async extractResponse(): Promise<string> {
    // WHY: This guard ensures the native bridge for clipboard access exists.
    if (!window.flutter_inappwebview) {
      throw new Error('[Z.ai] flutter_inappwebview bridge is not available for clipboard operations.');
    }

    console.log('[Z.ai] Starting clipboard-based extraction workflow...');

    // 1. Prime the clipboard with a unique token to verify the copy operation.
    const uniqueToken = `ai-hybrid-hub-copy-check-${Date.now()}`;
    try {
      await window.flutter_inappwebview.callHandler('setClipboard', uniqueToken);
      console.log('[Z.ai] Primed clipboard with unique token.');
    } catch (error) {
      throw new Error(`[Z.ai] Could not set initial clipboard state: ${error}`);
    }

    // 2. Find the last response footer and click its copy button.
    const responseFooters = document.querySelectorAll(SELECTORS.RESPONSE_ACTIONS_FOOTER);
    const lastFooter = responseFooters[responseFooters.length - 1] as HTMLElement | undefined;
    if (!lastFooter) {
      throw new Error('[Z.ai] Could not find any response footer to extract from.');
    }

    let copyButton = lastFooter.querySelector(SELECTORS.COPY_BUTTON) as HTMLElement | null;
    if (!copyButton) {
      copyButton = await waitForActionableElement<HTMLElement>(
          [SELECTORS.COPY_BUTTON],
          'Copy Button',
          5000,
          2,
      );
    }

    copyButton.click();
    console.log('[Z.ai] "Copy" button clicked. Waiting for clipboard to update...');

    // WHY: Wait a brief moment to allow the OS-level clipboard operation to complete.
    // eslint-disable-next-line custom/disallow-timeout-for-waits
    await new Promise(resolve => setTimeout(resolve, 300));

    // 3. Poll the clipboard until its content is different from our token.
    const pollInterval = 150;
    const maxAttempts = 40; // Poll for up to 6 seconds

    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      // WHY: Polling interval for clipboard check, not a UI wait
      // eslint-disable-next-line custom/disallow-timeout-for-waits
      await new Promise(resolve => setTimeout(resolve, pollInterval));

      try {
        const clipboardText = await window.flutter_inappwebview.callHandler('readClipboard') as string;

        if (typeof clipboardText === 'string' && clipboardText.trim() && clipboardText !== uniqueToken) {
          console.log(`[Z.ai] Clipboard updated. Successfully extracted ${clipboardText.length} chars.`);
          return clipboardText.trim();
        }
      } catch (error) {
        console.warn(`[Z.ai] Clipboard read attempt ${attempt + 1} failed, retrying...`, error);
      }
    }

    // 4. If the loop finishes, the clipboard content never changed.
    throw new Error('[Z.ai] Extraction failed: Clipboard content did not change after copy operation.');
  }
}

export const zAiChatbot = new ZAiChatbot();

