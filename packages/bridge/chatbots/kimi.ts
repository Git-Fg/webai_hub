// ts_src/chatbots/kimi.ts

import { Chatbot, AutomationOptions } from '../types/chatbot';
import { waitForElementWithin, waitForElementByText } from '../utils/wait-for-element';
import { waitForActionableElement } from '../utils/wait-for-actionable-element';
import { getModifiedTimeout } from '../utils/timeout';

// --- Sélecteurs validés pour Kimi ---
export const SELECTORS = {
  LOGIN_BUTTON: 'button.login-button',
  PROMPT_INPUT: 'div[contenteditable=true]',
  SEND_BUTTON_CONTAINER: '.send-button-container',
  SEND_BUTTON: 'div.send-button',
  GENERATING_INDICATOR: 'path[d="M331.946667 379.904c-11.946667 23.466667-11.946667 54.186667-11.946667 115.626667v32.938666c0 61.44 0 92.16 11.946667 115.626667 10.538667 20.650667 27.306667 37.418667 47.957333 47.957333 23.466667 11.946667 54.186667 11.946667 115.626667 11.946667h32.938666c61.44 0 92.16 0 115.626667-11.946667 20.650667-10.538667 37.418667-27.306667 47.957333-47.957333 11.946667-23.466667 11.946667-54.186667 11.946667-115.626667v-32.938666c0-61.44 0-92.16-11.946667-115.626667a109.696 109.696 0 0 0-47.957333-47.957333c-23.466667-11.946667-54.186667-11.946667-115.626667-11.946667h-32.938666c-61.44 0-92.16 0-115.626667 11.946667-20.650667 10.538667-37.418667 27.306667-47.957333 47.957333z"]',
  RESPONSE_CONTAINER: '.segment-content',
  RESPONSE_TEXT: '.segment-content > div:first-child',
  COPY_BUTTON: '.segment-assistant-actions-content div[data-v-10d40aa8]',
  SETTINGS_PANEL_TOGGLE: '.option-item',
  TOOLKIT_ITEM_CONTAINER: '.toolkit-item',
  SWITCH_INPUT: 'input[type="checkbox"]',
  SWITCH_LABEL: 'label.switch',
};

class KimiChatbot implements Chatbot {

  async waitForReady(): Promise<void> {
    console.log('[Kimi] Starting readiness check...');

    // WHY: Check for login button first - if present, user needs to log in before automation can proceed
    const loginButton = document.querySelector(SELECTORS.LOGIN_BUTTON);
    if (loginButton) {
      const error = new Error('[Kimi] Login button detected. User must log in before automation can proceed.');
      console.error('[Kimi] Login button detected. User must log in before automation can proceed.');
      throw error;
    }

    // WHY: Use waitForActionableElement which leverages MutationObserver for efficient,
    // event-driven waiting instead of polling. This checks for visibility, stability, and actionability.
    await waitForActionableElement([SELECTORS.PROMPT_INPUT], 'Prompt Input');
    console.log('[Kimi] UI is ready.');
  }

  async applyAllSettings(options: AutomationOptions): Promise<void> {
    const hasKimiSettings = options.useWebSearch !== undefined || options.disableThinking !== undefined;
    if (!hasKimiSettings) {
      console.log('[Kimi] No specific settings to apply.');
      return;
    }

    console.log('[Kimi] Applying settings:', { useWebSearch: options.useWebSearch, disableThinking: options.disableThinking });

    const settingsButton = await waitForActionableElement<HTMLElement>(
      [SELECTORS.SETTINGS_PANEL_TOGGLE], 
      'Settings Panel Toggle'
    );

    settingsButton.click();
    // WHY: Wait for panel animation to complete before interacting with switches
    // eslint-disable-next-line custom/disallow-timeout-for-waits
    await new Promise(resolve => setTimeout(resolve, 500));

    try {
      if (options.useWebSearch !== undefined) {
        await this._toggleSwitch('Search', options.useWebSearch);
      }
      if (options.disableThinking !== undefined) {
        const enableThinking = !options.disableThinking;
        await this._toggleSwitch('Thinking', enableThinking);
      }
    } finally {
      settingsButton.click(); // Close the panel
      // WHY: Wait for panel animation to complete before continuing
      // eslint-disable-next-line custom/disallow-timeout-for-waits
      await new Promise(resolve => setTimeout(resolve, 500));
    }
  }

  private async _toggleSwitch(label: 'Search' | 'Thinking', shouldBeEnabled: boolean): Promise<void> {
    try {
      console.log(`[Kimi] Configuring "${label}" switch to be ${shouldBeEnabled ? 'enabled' : 'disabled'}.`);
      const labelElement = await waitForElementByText('div', label, 3000);
      const parentContainer = labelElement.closest(SELECTORS.TOOLKIT_ITEM_CONTAINER);
      if (!parentContainer) {
        throw new Error(`Could not find parent container for label "${label}".`);
      }

      const switchInput = parentContainer.querySelector(SELECTORS.SWITCH_INPUT) as HTMLInputElement;
      if (!switchInput) {
        throw new Error(`Could not find checkbox input for "${label}".`);
      }

      if (switchInput.checked !== shouldBeEnabled) {
        const clickableSwitch = parentContainer.querySelector(SELECTORS.SWITCH_LABEL) as HTMLElement;
        if (!clickableSwitch) {
          throw new Error(`Could not find clickable label for "${label}".`);
        }
        clickableSwitch.click();
        console.log(`[Kimi] Toggled "${label}" switch to ${shouldBeEnabled}.`);
        // WHY: Wait for UI to update after toggle
        // eslint-disable-next-line custom/disallow-timeout-for-waits
        await new Promise(resolve => setTimeout(resolve, 300));
      } else {
        console.log(`[Kimi] "${label}" switch is already in the desired state.`);
      }
    } catch (error) {
      console.error(`[Kimi] Failed to toggle "${label}" switch.`, error);
      throw error;
    }
  }

  private async _waitForResponseFinalization(): Promise<void> {
    console.log('[Kimi] Now waiting for AI response to finalize...');
    
    return new Promise((resolve, reject) => {
      const timeout = getModifiedTimeout(60000); // 60 second timeout for Kimi
      const pollInterval = 300; // Check every 300ms
      
      const checkForFinalizedResponse = () => {
        const responseContainers = document.querySelectorAll(SELECTORS.RESPONSE_CONTAINER);
        if (responseContainers.length === 0) return;

        const lastResponseContainer = responseContainers[responseContainers.length - 1];
        if (!lastResponseContainer) return;

        // Condition: The generating spinner is GONE, and the copy button is PRESENT.
        const isGenerating = !!document.querySelector(SELECTORS.GENERATING_INDICATOR);
        const copyButton = lastResponseContainer.querySelector(SELECTORS.COPY_BUTTON);

        if (!isGenerating && copyButton) {
          console.log('[Kimi] Response finalized. Ready for extraction.');
          clearInterval(checkInterval);
          clearTimeout(timeoutId);
          resolve();
        }
      };

      const checkInterval = setInterval(checkForFinalizedResponse, pollInterval);
      
      // WHY: Timeout handler for cleanup, not a UI wait
      // eslint-disable-next-line custom/disallow-timeout-for-waits
      const timeoutId = setTimeout(() => {
        clearInterval(checkInterval);
        reject(new Error(`Timed out after ${timeout}ms waiting for response to finalize.`));
      }, timeout);

      // Perform an initial check
      checkForFinalizedResponse();
    });
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

    // *** NEW LOGIC: Await finalization directly ***
    await this._waitForResponseFinalization();
  }


  async extractResponse(): Promise<string> {
    console.log('[Kimi] Starting response extraction workflow...');

    const responseContainers = document.querySelectorAll(SELECTORS.RESPONSE_CONTAINER);
    if (responseContainers.length === 0) {
      throw new Error('No response containers found.');
    }
    const lastResponseContainer = responseContainers[responseContainers.length - 1];
    if (!lastResponseContainer) {
      throw new Error('Could not find last response container.');
    }

    const sanitizeResponseText = (raw: string): string =>
      raw
        .replace(/\s+Copy\s*$/i, '') // Drop trailing action labels
        .replace(/\u00a0/g, ' ') // Normalize NBSP
        .replace(/[ \t]+\n/g, '\n') // Trim trailing spaces per line
        .replace(/\n{3,}/g, '\n\n') // Collapse excessive blank lines
        .trim();

    const responseTextElement = lastResponseContainer.querySelector(SELECTORS.RESPONSE_TEXT) as HTMLElement | null;
    if (responseTextElement) {
      const domText = sanitizeResponseText(responseTextElement.innerText);
      if (domText.length > 0) {
        console.log(`[Kimi] Extracted response text directly from DOM (${domText.length} chars).`);
        return domText;
      }
    }

    const fallbackDomText = sanitizeResponseText((lastResponseContainer as HTMLElement).innerText ?? '');
    if (fallbackDomText.length > 0) {
      console.log(`[Kimi] Extracted response from container fallback (${fallbackDomText.length} chars).`);
      return fallbackDomText;
    }

    if (!window.flutter_inappwebview) {
      throw new Error('flutter_inappwebview bridge is not available for clipboard operations.');
    }

    console.log('[Kimi] Falling back to clipboard-based extraction workflow...');

    // 1. Define a unique token to prime the clipboard.
    const uniqueToken = `ai-hybrid-hub-copy-check-${Date.now()}`;

    // 2. Write the unique token to the clipboard via the Dart handler.
    try {
      await window.flutter_inappwebview.callHandler('setClipboard', uniqueToken);
      console.log('[Kimi] Primed clipboard with unique token.');
    } catch (error) {
      console.error('[Kimi] Failed to prime clipboard via Dart handler.', error);
      throw new Error('Could not set initial clipboard state for validation.');
    }

    // 3. Find and click the "Copy" button in the web UI.
    
    const copyButton = await waitForElementWithin<HTMLElement>(
      lastResponseContainer,
      [SELECTORS.COPY_BUTTON],
      getModifiedTimeout(5000),
    );
    
    // WHY: Ensure the copy button is visible and clickable before clicking
    if (!copyButton.offsetParent) {
      throw new Error('Copy button is not visible.');
    }
    
    // WHY: Scroll the button into view to ensure it's fully visible and clickable
    copyButton.scrollIntoView({ behavior: 'smooth', block: 'center' });
    // WHY: Wait for smooth scroll animation to complete before interacting
    // eslint-disable-next-line custom/disallow-timeout-for-waits
    await new Promise(resolve => setTimeout(resolve, 200));
    
    // WHY: Use mouse events instead of just click() for better compatibility
    // Some web frameworks require full mouse event sequence to trigger clipboard operations
    const mouseDownEvent = new MouseEvent('mousedown', {
      bubbles: true,
      cancelable: true,
      view: window,
    });
    const mouseUpEvent = new MouseEvent('mouseup', {
      bubbles: true,
      cancelable: true,
      view: window,
    });
    const clickEvent = new MouseEvent('click', {
      bubbles: true,
      cancelable: true,
      view: window,
    });
    
    copyButton.dispatchEvent(mouseDownEvent);
    // WHY: Brief delay between mouse events to ensure proper event sequence processing
    // eslint-disable-next-line custom/disallow-timeout-for-waits
    await new Promise(resolve => setTimeout(resolve, 50));
    copyButton.dispatchEvent(mouseUpEvent);
    // WHY: Brief delay between mouse events to ensure proper event sequence processing
    // eslint-disable-next-line custom/disallow-timeout-for-waits
    await new Promise(resolve => setTimeout(resolve, 50));
    copyButton.dispatchEvent(clickEvent);
    
    console.log('[Kimi] "Copy" button clicked with full mouse event sequence. Waiting before polling...');

    // WHY: Add a delay after clicking to allow the clipboard operation to complete.
    // Some systems need time for the clipboard to update after a copy action.
    // eslint-disable-next-line custom/disallow-timeout-for-waits
    await new Promise(resolve => setTimeout(resolve, 300));

    // 4. Poll the clipboard until its content is different from our token.
    const pollInterval = 150; // Check every 150ms for better responsiveness
    const maxAttempts = 40; // Poll for up to 6 seconds (40 * 150ms) to handle slower devices
    
    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      // WHY: Polling interval for clipboard check, not a UI wait
      // eslint-disable-next-line custom/disallow-timeout-for-waits
      await new Promise(resolve => setTimeout(resolve, pollInterval));

      try {
        const clipboardText = await window.flutter_inappwebview.callHandler('readClipboard') as string;

        // WHY: Check if clipboard contains valid text that's different from our unique token.
        // We accept any non-empty string that's not our token, as the response text could be anything.
        if (typeof clipboardText === 'string' && clipboardText.trim() && clipboardText !== uniqueToken) {
          console.log(`[Kimi] Clipboard updated. Successfully extracted ${clipboardText.length} chars (attempt ${attempt + 1}).`);
          return clipboardText;
        }
      } catch (error) {
        // Log errors but continue polling until the timeout.
        console.warn(`[Kimi] Clipboard read attempt ${attempt + 1} failed, retrying...`, error);
      }
    }

    // If the loop finishes, it means the clipboard content never changed.
    // Provide diagnostic information to help debug the issue.
    let diagnosticInfo = '';
    try {
      const finalClipboard = await window.flutter_inappwebview.callHandler('readClipboard') as string;
      diagnosticInfo = ` Final clipboard state: ${typeof finalClipboard === 'string' ? `"${finalClipboard.substring(0, 50)}..."` : 'non-string'}`;
    } catch (e) {
      diagnosticInfo = ` Could not read final clipboard state: ${e}`;
    }
    
    throw new Error(`Extraction failed: Clipboard content did not change from the unique token after the copy operation.${diagnosticInfo} Tried ${maxAttempts} times over ${(maxAttempts * pollInterval) / 1000}s.`);
  }
}

export const kimiChatbot = new KimiChatbot();

