// ts_src/chatbots/z-ai.ts

import { Chatbot, AutomationOptions } from '../types/chatbot';
import { waitForActionableElement } from '../utils/wait-for-actionable-element';
import { waitForElementByText } from '../utils/wait-for-element';
import { getModifiedTimeout } from '../utils/timeout';

// --- Selectors validated from inspiration codebase ---
export const SELECTORS = {
  PROMPT_INPUT: 'textarea[placeholder="How can I help you today?"]',
  SEND_BUTTON: 'button#send-message-button',
  DEEP_THINK_TOGGLE: 'button[data-autothink]',
  MODEL_SWITCHER_BUTTON: 'button[aria-label="Select a model"]',
  MODEL_OPTION_BY_VALUE: (value: string) => `button[data-value="${value}"]`,
  TOOLS_BUTTON_GLM45: 'button:has(svg path[d^="M2.6499 4.48322"])',
  WEB_SEARCH_BUTTON_POPOVER: 'button.px-3.py-2',
  RESPONSE_ACTIONS_FOOTER: '.chat-assistant + div',
  COPY_BUTTON: 'button.copy-response-button',
};

// --- Model mapping from inspiration code ---
const MODEL_DATA_VALUES: Record<string, string> = {
  'GLM-4.6': 'GLM-4-6-API-V1',
  'GLM-4.5': '0727-360B-API',
};

const TIMING = {
  POLL_INTERVAL_MS: 150,
  COPY_POLL_MAX_ATTEMPTS: 40,
  UI_STABILIZE_MS: 300,
  GENERATION_TIMEOUT_MS: 30000,
};

const delay = (ms: number) =>
  new Promise<void>(resolve => {
    // WHY: Provide deterministic waits for UI transitions when no actionable selector exists yet.
    // eslint-disable-next-line custom/disallow-timeout-for-waits
    setTimeout(resolve, ms);
  });

class ZAiChatbot implements Chatbot {
  async waitForReady(): Promise<void> {
    await waitForActionableElement([SELECTORS.PROMPT_INPUT], 'Prompt Input');
    console.log('[Z.ai] UI is ready.');
  }

  private async _switchModel(modelName: string): Promise<void> {
    console.log(`[Z.ai] Switching model to: ${modelName}`);
    const modelSwitcher = await waitForActionableElement([SELECTORS.MODEL_SWITCHER_BUTTON], 'Model Switcher');

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
    await delay(500); // Wait for UI update
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
      } else {
        const webSearchButton = await waitForElementByText('button', 'Web Search');
        const isEnabled = !webSearchButton.className.includes('text-gray-400'); // Enabled buttons have different styling
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
    return new Promise<void>((resolve, reject) => {
      const timeout = getModifiedTimeout(TIMING.GENERATION_TIMEOUT_MS);
      let timeoutId: number | null = null;
      const observer = new MutationObserver(async () => {
        const currentFooters = document.querySelectorAll(SELECTORS.RESPONSE_ACTIONS_FOOTER);
        if (currentFooters.length > initialFooterCount) {
          try {
            await waitForActionableElement<HTMLElement>(
              [SELECTORS.COPY_BUTTON],
              'Copy Button in new footer',
              2000,
              0,
            );
            console.log('[Z.ai] Response finalized: New footer with actionable copy button found.');
            if (timeoutId) clearTimeout(timeoutId);
            observer.disconnect();
            resolve();
          } catch {
            // Button not yet actionable, keep waiting.
          }
        }
      });

      observer.observe(document.body, { childList: true, subtree: true });
      // WHY: Stop waiting if no new assistant footer appears within the expected window.
      // eslint-disable-next-line custom/disallow-timeout-for-waits
      timeoutId = window.setTimeout(() => {
        observer.disconnect();
        reject(new Error(`[Z.ai] Response did not finalize within ${timeout}ms.`));
      }, timeout);
    });
  }

  async extractResponse(): Promise<string> {
    if (!window.flutter_inappwebview) {
      throw new Error('[Z.ai] flutter_inappwebview bridge is not available for clipboard operations.');
    }
    console.log('[Z.ai] Starting clipboard-based extraction...');
    const uniqueToken = `ai-hybrid-hub-copy-check-${Date.now()}`;
    await window.flutter_inappwebview.callHandler('setClipboard', uniqueToken);
    console.log('[Z.ai] Primed clipboard with unique token.');
    const responseFooters = document.querySelectorAll(SELECTORS.RESPONSE_ACTIONS_FOOTER);
    const lastFooter = responseFooters[responseFooters.length - 1] as HTMLElement | undefined;
    if (!lastFooter) throw new Error('[Z.ai] Could not find any response footer to extract from.');
    const copyButton = await waitForActionableElement<HTMLElement>(
      [SELECTORS.COPY_BUTTON],
      'Copy Button',
      5000,
    );
    copyButton.click();
    console.log('[Z.ai] "Copy" button clicked. Polling clipboard for changes...');
    await delay(TIMING.UI_STABILIZE_MS);
    for (let attempt = 0; attempt < TIMING.COPY_POLL_MAX_ATTEMPTS; attempt++) {
      await delay(TIMING.POLL_INTERVAL_MS);

      const clipboardText = (await window.flutter_inappwebview.callHandler('readClipboard')) as string;
      if (typeof clipboardText === 'string' && clipboardText.trim() && clipboardText !== uniqueToken) {
        console.log(`[Z.ai] Clipboard updated. Successfully extracted ${clipboardText.length} chars.`);
        return clipboardText.trim();
      }
    }
    throw new Error('[Z.ai] Extraction failed: Clipboard content did not change after copy operation.');
  }
}

export const zAiChatbot = new ZAiChatbot();

