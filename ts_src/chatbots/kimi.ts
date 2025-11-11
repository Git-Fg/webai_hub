// ts_src/chatbots/kimi.ts

import { Chatbot } from '../types/chatbot';
import { waitForElement, waitForElementWithin } from '../utils/wait-for-element';
import { waitForActionableElement } from '../utils/wait-for-actionable-element';
import { getModifiedTimeout } from '../utils/timeout';

// --- Sélecteurs validés pour Kimi ---
const SELECTORS = {
  READINESS: '.current-model',
  PROMPT_INPUT: 'div[contenteditable=true]',
  SEND_BUTTON_CONTAINER: '.send-button-container',
  SEND_BUTTON: 'div.send-button',
  GENERATING_INDICATOR: 'path[d="M331.946667 379.904c-11.946667 23.466667-11.946667 54.186667-11.946667 115.626667v32.938666c0 61.44 0 92.16 11.946667 115.626667 10.538667 20.650667 27.306667 37.418667 47.957333 47.957333 23.466667 11.946667 54.186667 11.946667 115.626667 11.946667h32.938666c61.44 0 92.16 0 115.626667-11.946667 20.650667-10.538667 37.418667-27.306667 47.957333-47.957333 11.946667-23.466667 11.946667-54.186667 11.946667-115.626667v-32.938666c0-61.44 0-92.16-11.946667-115.626667a109.696 109.696 0 0 0-47.957333-47.957333c-23.466667-11.946667-54.186667-11.946667-115.626667-11.946667h-32.938666c-61.44 0-92.16 0-115.626667 11.946667-20.650667 10.538667-37.418667 27.306667-47.957333 47.957333z"]',
  RESPONSE_CONTAINER: '.segment-content',
  RESPONSE_TEXT: '.segment-content > div:first-child',
  COPY_BUTTON: '.segment-assistant-actions-content div[data-v-10d40aa8]',
};

class KimiChatbot implements Chatbot {
  async waitForReady(): Promise<void> {
    console.log('[Kimi] Waiting for UI to be ready...');
    await waitForElement([SELECTORS.READINESS], getModifiedTimeout(10000));
    console.log('[Kimi] UI is ready.');
  }

  async sendPrompt(prompt: string): Promise<void> {
    console.log('[Kimi] Starting sendPrompt workflow...');
    
    const inputElement = await waitForActionableElement<HTMLDivElement>(
      [SELECTORS.PROMPT_INPUT],
      'Prompt Input',
    );

    // WHY: Kimi uses a contenteditable div. We must dispatch an InputEvent
    // for its web framework to recognize the change. Setting .innerText is not enough.
    console.log('[Kimi] Dispatching InputEvent to contenteditable div...');
    inputElement.dispatchEvent(
      new InputEvent('input', {
        bubbles: true,
        cancelable: true,
        inputType: 'insertText',
        data: prompt,
      }),
    );

    // Wait for the send button to become enabled
    console.log('[Kimi] Waiting for send button to become enabled...');
    await new Promise<void>((resolve, reject) => {
      const timeout = getModifiedTimeout(5000);
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
  }

  async extractResponse(): Promise<string> {
    console.log('[Kimi] Starting response extraction...');
    
    // 1. Wait for the generating indicator to appear, then disappear.
    console.log('[Kimi] Waiting for generating indicator to appear...');
    await waitForElement([SELECTORS.GENERATING_INDICATOR], getModifiedTimeout(5000));
    console.log('[Kimi] Generating indicator appeared. Waiting for it to disappear...');
    
    // Custom logic for waiting for an element to disappear
    await new Promise<void>((resolve, reject) => {
      const timeout = getModifiedTimeout(60000); // Long timeout for response generation
      const interval = 200;
      let elapsedTime = 0;
      
      const check = () => {
        if (!document.querySelector(SELECTORS.GENERATING_INDICATOR)) {
          clearInterval(checkInterval);
          console.log('[Kimi] Generating indicator disappeared. Response should be complete.');
          resolve();
        } else {
          elapsedTime += interval;
          if (elapsedTime >= timeout) {
            clearInterval(checkInterval);
            reject(new Error('Response generation timed out.'));
          }
        }
      };
      const checkInterval = setInterval(check, interval);
    });

    // 2. Find all response containers and target the last one.
    console.log('[Kimi] Finding response containers...');
    const responseContainers = document.querySelectorAll(SELECTORS.RESPONSE_CONTAINER);
    if (responseContainers.length === 0) {
      throw new Error('No response containers found.');
    }
    const lastResponseContainer = responseContainers[responseContainers.length - 1];
    if (!lastResponseContainer) {
      throw new Error('Could not find last response container.');
    }
    console.log(`[Kimi] Found ${responseContainers.length} response container(s). Targeting the last one.`);

    // 3. Confirm the response is complete by finding the copy button inside it.
    console.log('[Kimi] Waiting for copy button to appear (confirms response is complete)...');
    await waitForElementWithin(
      lastResponseContainer,
      [SELECTORS.COPY_BUTTON],
      getModifiedTimeout(5000),
    );
    console.log('[Kimi] Copy button found. Response is complete.');

    // 4. Extract the text using the robust structural selector.
    const responseTextElement = lastResponseContainer.querySelector<HTMLDivElement>(
      SELECTORS.RESPONSE_TEXT,
    );
    if (!responseTextElement) {
      throw new Error('Could not find response text element within the final container.');
    }
    
    const responseText = responseTextElement.textContent?.trim();
    if (!responseText) {
      throw new Error('Response text element was found, but it is empty.');
    }

    console.log(`[Kimi] Response extracted successfully (${responseText.length} characters).`);
    return responseText;
  }
}

export const kimiChatbot = new KimiChatbot();

