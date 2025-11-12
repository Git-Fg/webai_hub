// ts_src/chatbots/kimi.ts

import { Chatbot } from '../types/chatbot';
import { waitForElementWithin } from '../utils/wait-for-element';
import { waitForActionableElement } from '../utils/wait-for-actionable-element';
import { getModifiedTimeout } from '../utils/timeout';
import { notifyDart } from '../utils/notify-dart';
import { EVENT_TYPE_NEW_RESPONSE } from '../utils/bridge-constants';

// --- Sélecteurs validés pour Kimi ---
const SELECTORS = {
  LOGIN_BUTTON: 'button.login-button',
  PROMPT_INPUT: 'div[contenteditable=true]',
  SEND_BUTTON_CONTAINER: '.send-button-container',
  SEND_BUTTON: 'div.send-button',
  GENERATING_INDICATOR: 'path[d="M331.946667 379.904c-11.946667 23.466667-11.946667 54.186667-11.946667 115.626667v32.938666c0 61.44 0 92.16 11.946667 115.626667 10.538667 20.650667 27.306667 37.418667 47.957333 47.957333 23.466667 11.946667 54.186667 11.946667 115.626667 11.946667h32.938666c61.44 0 92.16 0 115.626667-11.946667 20.650667-10.538667 37.418667-27.306667 47.957333-47.957333 11.946667-23.466667 11.946667-54.186667 11.946667-115.626667v-32.938666c0-61.44 0-92.16-11.946667-115.626667a109.696 109.696 0 0 0-47.957333-47.957333c-23.466667-11.946667-54.186667-11.946667-115.626667-11.946667h-32.938666c-61.44 0-92.16 0-115.626667 11.946667-20.650667 10.538667-37.418667 27.306667-47.957333 47.957333z"]',
  RESPONSE_CONTAINER: '.segment-content',
  RESPONSE_TEXT: '.segment-content > div:first-child',
  COPY_BUTTON: '.segment-assistant-actions-content div[data-v-10d40aa8]',
};

class KimiChatbot implements Chatbot {
  // --- Observer State ---
  private responseObserver: MutationObserver | null = null;
  private debounceTimer: number | null = null;

  async waitForReady(): Promise<void> {
    console.log('[Kimi] Starting robust multi-condition readiness check...');

    const readinessTimeout = getModifiedTimeout(20000); // 20-second timeout

    return new Promise((resolve, reject) => {
      const interval = 250; // Check every 250ms
      let elapsedTime = 0;
      let loginButtonDetected = false;
      let loginButtonWaitComplete = false;

      const checkConditions = () => {
        // Condition 1: Login button must NOT be visible.
        const loginButton = document.querySelector(SELECTORS.LOGIN_BUTTON);
        const isLoggedIn = !loginButton;

        // WHY: If login button was detected, wait 1.5 seconds for page to stabilize
        // This handles the case where the page is still initializing and the login state
        // is being determined, which can cause script injection timing issues.
        if (loginButton && !loginButtonDetected) {
          loginButtonDetected = true;
          console.log('[Kimi] Login button detected. Waiting 1.5s for page to stabilize...');
          setTimeout(() => {
            loginButtonWaitComplete = true;
            console.log('[Kimi] Login button wait complete. Resuming readiness check...');
          }, 1500);
          return; // Skip this check cycle, wait for the delay
        }

        // If we're waiting for login button delay, don't proceed yet
        if (loginButtonDetected && !loginButtonWaitComplete) {
          return;
        }

        // Condition 2: Prompt input must BE visible and actionable.
        const promptInput = document.querySelector(SELECTORS.PROMPT_INPUT) as HTMLElement;
        const isPromptReady = promptInput && promptInput.offsetParent !== null;

        // Condition 3: Send button container must BE visible.
        const sendContainer = document.querySelector(SELECTORS.SEND_BUTTON_CONTAINER) as HTMLElement;
        const isSendContainerReady = sendContainer && sendContainer.offsetParent !== null;

        if (isLoggedIn && isPromptReady && isSendContainerReady) {
          clearInterval(checkInterval);
          clearTimeout(timeoutId);
          console.log('[Kimi] All readiness conditions met. UI is ready.');
          resolve();
        } else {
          elapsedTime += interval;
          if (elapsedTime >= readinessTimeout) {
            clearInterval(checkInterval);
            clearTimeout(timeoutId);
            // Provide a detailed error message for easier debugging
            const errorDetails = [
              `- Logged In: ${isLoggedIn}`,
              `- Prompt Input Ready: ${isPromptReady}`,
              `- Send Container Ready: ${isSendContainerReady}`
            ].join('\n');
            reject(new Error(`[Kimi] UI readiness check timed out after ${readinessTimeout}ms.\nStatus:\n${errorDetails}`));
          }
        }
      };

      const checkInterval = setInterval(checkConditions, interval);
      const timeoutId = setTimeout(() => {
        clearInterval(checkInterval);
        // This will be caught by the polling logic, but it's a safety net.
        reject(new Error(`[Kimi] Readiness check timed out externally after ${readinessTimeout}ms.`));
      }, readinessTimeout);

      // Perform the first check immediately
      checkConditions();
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
  }

  // --- Response Observer Implementation ---

  private stopResponseObserver(): void {
    if (this.responseObserver) {
      this.responseObserver.disconnect();
      this.responseObserver = null;
    }
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer);
      this.debounceTimer = null;
    }
    console.log('[Kimi Observer] Stopped observing.');
  }

  private checkForFinalizedResponse(): void {
    const responseContainers = document.querySelectorAll(SELECTORS.RESPONSE_CONTAINER);
    if (responseContainers.length === 0) return;

    const lastResponseContainer = responseContainers[responseContainers.length - 1];
    if (!lastResponseContainer) return;

    // Condition: The generating spinner is GONE, and the copy button is PRESENT.
    const isGenerating = !!document.querySelector(SELECTORS.GENERATING_INDICATOR);
    const copyButton = lastResponseContainer.querySelector(SELECTORS.COPY_BUTTON);

    if (!isGenerating && copyButton) {
      console.log('[Kimi Observer] Detected finalized response. Notifying Dart.');
      notifyDart({ type: EVENT_TYPE_NEW_RESPONSE });
      this.stopResponseObserver();
    }
  }

  async startResponseObserver(): Promise<void> {
    this.stopResponseObserver(); // Ensure no old observers are running

    const targetNode = document.body;

    this.responseObserver = new MutationObserver(() => {
      if (this.debounceTimer) clearTimeout(this.debounceTimer);
      this.debounceTimer = window.setTimeout(() => this.checkForFinalizedResponse(), 300);
    });

    this.responseObserver.observe(targetNode, {
      childList: true,
      subtree: true,
    });

    console.log('[Kimi Observer] Started observing DOM for new responses.');
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
    await new Promise(resolve => setTimeout(resolve, 50));
    copyButton.dispatchEvent(mouseUpEvent);
    await new Promise(resolve => setTimeout(resolve, 50));
    copyButton.dispatchEvent(clickEvent);
    
    console.log('[Kimi] "Copy" button clicked with full mouse event sequence. Waiting before polling...');

    // WHY: Add a delay after clicking to allow the clipboard operation to complete.
    // Some systems need time for the clipboard to update after a copy action.
    await new Promise(resolve => setTimeout(resolve, 300));

    // 4. Poll the clipboard until its content is different from our token.
    const pollInterval = 150; // Check every 150ms for better responsiveness
    const maxAttempts = 40; // Poll for up to 6 seconds (40 * 150ms) to handle slower devices
    
    for (let attempt = 0; attempt < maxAttempts; attempt++) {
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

