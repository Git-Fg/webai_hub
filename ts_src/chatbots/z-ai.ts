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
    const initialResponseCount = document.querySelectorAll(SELECTORS.RESPONSE_CONTAINER).length;
    await new Promise((resolve, reject) => {
        const timeout = 30000;
        const interval = 100;
        let elapsedTime = 0;
        const check = () => {
            if (document.querySelectorAll(SELECTORS.RESPONSE_CONTAINER).length > initialResponseCount) {
                resolve(true);
            } else {
                elapsedTime += interval;
                if (elapsedTime >= timeout) reject(new Error(`[Z.ai] New response did not appear within ${timeout}ms.`));
                else {
                  // WHY: Polling mechanism for response detection, not a UI wait
                  // eslint-disable-next-line custom/disallow-timeout-for-waits
                  setTimeout(check, interval);
                }
            }
        };
        check();
    });
  }

  async extractResponse(): Promise<string> {
    const responseFooters = document.querySelectorAll(SELECTORS.RESPONSE_ACTIONS_FOOTER);
    const lastFooter = responseFooters[responseFooters.length - 1];
    if (!lastFooter) throw new Error('[Z.ai] Could not find any response footer.');

    const responseContainer = lastFooter.previousElementSibling as HTMLElement;
    if (!responseContainer || !responseContainer.matches(SELECTORS.RESPONSE_CONTAINER)) {
      throw new Error('[Z.ai] Could not find response container associated with the last footer.');
    }

    return responseContainer.innerText.trim();
  }
}

export const zAiChatbot = new ZAiChatbot();

