// ts_src/chatbots/kimi.ts

import { Chatbot } from '../types/chatbot';
import { waitForActionableElement } from '../utils/wait-for-actionable-element';
import { getModifiedTimeout } from '../utils/timeout';

// --- Selectors validated from inspiration codebase ---
export const SELECTORS = {
  TUTORIAL_CLOSE_BUTTON: '.edu-card-popover svg.iconify.close',
  NOTICE_DIALOG_BUTTON: '.common-notice-dialog button.kimi-button.plain',
  PROMPT_INPUT: 'div[contenteditable=true]',
  SEND_BUTTON_CONTAINER: '.send-button-container',
  SEND_BUTTON: 'div.send-button',
  GENERATING_INDICATOR: 'path[d^="M331.946667 379.904"]',
  RESPONSE_CONTAINER: '.segment-content',
  RESPONSE_TEXT: '.segment-content > div:first-child',
  COPY_BUTTON: '.segment-assistant-actions-content div[data-v-10d40aa8]',
};

// --- Timing constants ---
const TIMING = {
  POLL_INTERVAL_MS: 150,
  COPY_POLL_MAX_ATTEMPTS: 40,
  UI_STABILIZE_MS: 300,
  SEND_BUTTON_TIMEOUT_MS: 5000,
};

const delay = (ms: number) =>
  new Promise<void>(resolve => {
    // WHY: Provide deterministic waits for transient UI animations when no actionable element exists.
    // eslint-disable-next-line custom/disallow-timeout-for-waits
    setTimeout(resolve, ms);
  });

class KimiChatbot implements Chatbot {
  async waitForReady(): Promise<void> {
    console.log('[Kimi] Starting readiness check...');
    try {
      const closeButton = await waitForActionableElement(
        [SELECTORS.TUTORIAL_CLOSE_BUTTON],
        'Tutorial Close Button',
        3000,
        0,
      );
      console.log('[Kimi] Found and dismissing tutorial popover...');
      closeButton.click();
      await delay(500);
    } catch {
      console.log('[Kimi] Info: Tutorial popover not found.');
    }
    try {
      const noticeButton = Array.from(document.querySelectorAll(SELECTORS.NOTICE_DIALOG_BUTTON)).find(
        el => el.textContent?.trim() === 'Got it',
      ) as HTMLElement | undefined;
      if (noticeButton) {
        console.log('[Kimi] Found and dismissing notice dialog...');
        noticeButton.click();
        await delay(500);
      }
    } catch {
      console.log('[Kimi] Info: Notice dialog not found.');
    }

    await waitForActionableElement([SELECTORS.PROMPT_INPUT], 'Prompt Input');
    console.log('[Kimi] UI is ready.');
  }

  private async _waitForResponseFinalization(): Promise<void> {
    console.log('[Kimi] Now waiting for AI response to finalize...');

    return new Promise((resolve, reject) => {
      const timeout = getModifiedTimeout(60000);
      const observer = new MutationObserver(() => {
        const isGenerating = !!document.querySelector(SELECTORS.GENERATING_INDICATOR);
        const responseContainers = document.querySelectorAll(SELECTORS.RESPONSE_CONTAINER);
        if (responseContainers.length === 0) return;

        const lastResponseContainer = responseContainers[responseContainers.length - 1];
        if (!lastResponseContainer) return;

        const copyButton = lastResponseContainer.querySelector(SELECTORS.COPY_BUTTON);

        if (!isGenerating && copyButton) {
          console.log('[Kimi] Response finalized. Ready for extraction.');
          observer.disconnect();
          clearTimeout(timeoutId);
          resolve();
        }
      });
      observer.observe(document.body, { childList: true, subtree: true });
      // WHY: Abort if automation waits too long for the assistant to finish responding.
      // eslint-disable-next-line custom/disallow-timeout-for-waits
      const timeoutId = setTimeout(() => {
        observer.disconnect();
        reject(new Error(`Timed out after ${timeout}ms waiting for response to finalize.`));
      }, timeout);
    });
  }

  async sendPrompt(prompt: string): Promise<void> {
    console.log('[Kimi] Starting sendPrompt workflow...');

    const inputElement = await waitForActionableElement<HTMLDivElement>(
      [SELECTORS.PROMPT_INPUT],
      'Prompt Input',
    );
    console.log('[Kimi] Dispatching InputEvent to contenteditable div...');
    inputElement.dispatchEvent(
      new InputEvent('input', {
        bubbles: true,
        cancelable: true,
        inputType: 'insertText',
        data: prompt,
      }),
    );
    console.log('[Kimi] Waiting for send button to become enabled...');
    await new Promise<void>((resolve, reject) => {
      const timeout = getModifiedTimeout(TIMING.SEND_BUTTON_TIMEOUT_MS);
      const interval = 100;
      let elapsedTime = 0;
      const check = () => {
        const container = document.querySelector(SELECTORS.SEND_BUTTON_CONTAINER);
        if (container && !container.classList.contains('disabled')) {
          clearInterval(checkInterval);
          console.log('[Kimi] Send button is now enabled.');
          resolve();
        } else {
          elapsedTime += interval;
          if (elapsedTime >= timeout) {
            clearInterval(checkInterval);
            reject(new Error('Send button did not become enabled in time.'));
          }
        }
      };
      const checkInterval = setInterval(check, interval);
    });
    const sendButton = await waitForActionableElement<HTMLDivElement>(
      [SELECTORS.SEND_BUTTON],
      'Send Button',
    );
    console.log('[Kimi] Clicking send button...');
    sendButton.click();
    console.log('[Kimi] Send button clicked successfully.');
    await this._waitForResponseFinalization();
  }

  async extractResponse(): Promise<string> {
    console.log('[Kimi] Starting response extraction...');
    const responseContainers = document.querySelectorAll(SELECTORS.RESPONSE_CONTAINER);
    if (responseContainers.length === 0) throw new Error('No response containers found.');

    const lastResponseContainer = responseContainers[responseContainers.length - 1] as HTMLElement;
    if (!lastResponseContainer) throw new Error('Could not find last response container.');

    const responseTextElement = lastResponseContainer.querySelector(SELECTORS.RESPONSE_TEXT) as HTMLElement | null;
    if (responseTextElement && responseTextElement.innerText.trim()) {
      const domText = responseTextElement.innerText.trim();
      console.log(`[Kimi] Extracted response text directly from DOM (${domText.length} chars).`);
      return domText;
    }

    console.log('[Kimi] Falling back to clipboard-based extraction...');
    if (!window.flutter_inappwebview) {
      throw new Error('flutter_inappwebview bridge is not available for clipboard operations.');
    }
    const uniqueToken = `ai-hybrid-hub-copy-check-${Date.now()}`;
    await window.flutter_inappwebview.callHandler('setClipboard', uniqueToken);
    console.log('[Kimi] Primed clipboard with unique token.');
    const copyButton = await waitForActionableElement<HTMLElement>(
      [SELECTORS.COPY_BUTTON],
      'Copy Button',
      5000,
      2,
    );
    copyButton.click();
    console.log('[Kimi] "Copy" button clicked. Polling clipboard for changes...');
    await delay(TIMING.UI_STABILIZE_MS);
    for (let attempt = 0; attempt < TIMING.COPY_POLL_MAX_ATTEMPTS; attempt++) {
      await delay(TIMING.POLL_INTERVAL_MS);

      const clipboardText = (await window.flutter_inappwebview.callHandler('readClipboard')) as string;
      if (typeof clipboardText === 'string' && clipboardText.trim() && clipboardText !== uniqueToken) {
        console.log(`[Kimi] Clipboard updated. Successfully extracted ${clipboardText.length} chars.`);
        return clipboardText;
      }
    }
    throw new Error('Extraction failed: Clipboard content did not change after copy operation.');
  }
}

export const kimiChatbot = new KimiChatbot();

