// ts_src/chatbots/z-ai.ts

import { Chatbot, AutomationOptions } from '../types/chatbot';
import { waitForActionableElement } from '../utils/wait-for-actionable-element';
import { waitForElementByText, waitForElementWithin } from '../utils/wait-for-element';
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
  // WHY: Multiple selector strategies for response footer - the structure may vary
  RESPONSE_ACTIONS_FOOTER: '.chat-assistant + div',
  RESPONSE_ACTIONS_FOOTER_ALT: '.chat-assistant ~ div',
  RESPONSE_ACTIONS_FOOTER_ALT2: '[class*="chat"] + div',
  // WHY: Multiple selector strategies for copy button - class names may vary
  COPY_BUTTON: 'button.copy-response-button',
  COPY_BUTTON_ALT: 'button[aria-label*="Copy" i]',
  COPY_BUTTON_ALT2: 'button[title*="Copy" i]',
  COPY_BUTTON_ALT3: 'button:has(svg[class*="copy" i])',
  COPY_BUTTON_ALT4: 'button:has(svg path[d*="M8" i])', // Common copy icon path
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
    
    // WHY: Try multiple footer selector strategies
    let responseFooters: NodeListOf<Element> | null = null;
    let footerSelectorUsed = '';
    const footerSelectors = [
      SELECTORS.RESPONSE_ACTIONS_FOOTER,
      SELECTORS.RESPONSE_ACTIONS_FOOTER_ALT,
      SELECTORS.RESPONSE_ACTIONS_FOOTER_ALT2,
    ];
    
    for (const selector of footerSelectors) {
      try {
        const footers = document.querySelectorAll(selector);
        if (footers.length > 0) {
          responseFooters = footers;
          footerSelectorUsed = selector;
          console.log(`[Z.ai] Found ${footers.length} response footer(s) using selector: ${selector}`);
          break;
        }
      } catch (error) {
        console.warn(`[Z.ai] Selector ${selector} failed:`, error);
      }
    }
    
    if (!responseFooters || responseFooters.length === 0) {
      // WHY: Fallback - try to find any div after chat messages
      console.warn('[Z.ai] No footers found with standard selectors, trying fallback...');
      const allDivs = document.querySelectorAll('div');
      const chatElements = document.querySelectorAll('[class*="chat" i], [class*="message" i], [class*="assistant" i]');
      console.log(`[Z.ai] Found ${chatElements.length} potential chat elements, ${allDivs.length} total divs`);
      
      // Look for the last chat message and find the next div
      if (chatElements.length > 0) {
        const lastChatElement = chatElements[chatElements.length - 1];
        if (lastChatElement) {
          let nextSibling = lastChatElement.nextElementSibling;
          while (nextSibling && nextSibling.tagName !== 'DIV') {
            nextSibling = nextSibling.nextElementSibling;
          }
          if (nextSibling) {
            responseFooters = document.createDocumentFragment().querySelectorAll('*') as unknown as NodeListOf<Element>;
            // Create a temporary array with the found element
            const tempArray = [nextSibling];
            responseFooters = tempArray as unknown as NodeListOf<Element>;
            footerSelectorUsed = 'fallback-next-sibling';
            console.log('[Z.ai] Using fallback: found next sibling div after last chat element');
          }
        }
      }
    }
    
    const lastFooter = responseFooters && responseFooters.length > 0 
      ? responseFooters[responseFooters.length - 1] as HTMLElement | undefined
      : undefined;
      
    if (!lastFooter) {
      console.error('[Z.ai] Could not find any response footer to extract from. DOM state:', {
        url: window.location.href,
        title: document.title,
        chatElements: document.querySelectorAll('[class*="chat" i]').length,
        assistantElements: document.querySelectorAll('[class*="assistant" i]').length,
        allDivs: document.querySelectorAll('div').length,
        footerSelectorUsed: footerSelectorUsed || 'none',
      });
      throw new Error('[Z.ai] Could not find any response footer to extract from.');
    }
    
    console.log(`[Z.ai] Using footer found with selector: ${footerSelectorUsed || 'unknown'}`);
    
    console.log('[Z.ai] Looking for copy button within last footer...');
    // WHY: Try multiple copy button selector strategies
    const copyButtonSelectors = [
      SELECTORS.COPY_BUTTON,
      SELECTORS.COPY_BUTTON_ALT,
      SELECTORS.COPY_BUTTON_ALT2,
      SELECTORS.COPY_BUTTON_ALT3,
      SELECTORS.COPY_BUTTON_ALT4,
    ];
    
    let copyButton: HTMLElement | null = null;
    let copyButtonSelectorUsed = '';
    
    // First try scoped search within footer
    for (const selector of copyButtonSelectors) {
      try {
        const button = await waitForElementWithin<HTMLElement>(
          lastFooter,
          [selector],
          getModifiedTimeout(2000),
        );
        if (button) {
          copyButton = button;
          copyButtonSelectorUsed = selector;
          console.log(`[Z.ai] Copy button found in footer using selector: ${selector}`);
          break;
        }
      } catch {
        // Try next selector
      }
    }
    
    // Fallback to global search if scoped search fails
    if (!copyButton) {
      console.warn('[Z.ai] Copy button not found in footer, searching globally as fallback...');
      for (const selector of copyButtonSelectors) {
        try {
          copyButton = await waitForActionableElement<HTMLElement>(
            [selector],
            'Copy Button',
            2000,
          );
          if (copyButton) {
            copyButtonSelectorUsed = selector;
            console.log(`[Z.ai] Copy button found globally using selector: ${selector}`);
            break;
          }
        } catch {
          // Try next selector
        }
      }
    }
    
    if (!copyButton) {
      console.error('[Z.ai] Could not find copy button with any selector. Available buttons:', {
        allButtons: Array.from(document.querySelectorAll('button')).map(b => ({
          text: b.textContent?.substring(0, 50),
          ariaLabel: b.getAttribute('aria-label'),
          className: b.className,
          id: b.id,
        })),
        footerButtons: Array.from(lastFooter.querySelectorAll('button')).map(b => ({
          text: b.textContent?.substring(0, 50),
          ariaLabel: b.getAttribute('aria-label'),
          className: b.className,
        })),
      });
      throw new Error('[Z.ai] Could not find copy button with any selector strategy.');
    }
    
    copyButton.click();
    console.log(`[Z.ai] "Copy" button clicked (selector: ${copyButtonSelectorUsed}). Polling clipboard for changes...`);
    await delay(TIMING.UI_STABILIZE_MS);
    
    for (let attempt = 0; attempt < TIMING.COPY_POLL_MAX_ATTEMPTS; attempt++) {
      await delay(TIMING.POLL_INTERVAL_MS);

      try {
        const clipboardText = (await window.flutter_inappwebview.callHandler('readClipboard')) as string | null | undefined;
        console.log(`[Z.ai] Clipboard check attempt ${attempt + 1}/${TIMING.COPY_POLL_MAX_ATTEMPTS}: type=${typeof clipboardText}, isNull=${clipboardText === null}, isUndefined=${clipboardText === undefined}, length=${clipboardText?.length ?? 0}, matchesToken=${clipboardText === uniqueToken}`);
        
        // WHY: Handle null/undefined returns from clipboard handler gracefully
        if (clipboardText === null || clipboardText === undefined) {
          console.warn(`[Z.ai] Clipboard read returned ${clipboardText === null ? 'null' : 'undefined'} on attempt ${attempt + 1}, continuing...`);
          continue;
        }
        
        if (typeof clipboardText === 'string' && clipboardText.trim() && clipboardText !== uniqueToken) {
          console.log(`[Z.ai] Clipboard updated. Successfully extracted ${clipboardText.length} chars.`);
          return clipboardText.trim();
        }
      } catch (error) {
        console.error(`[Z.ai] Error reading clipboard on attempt ${attempt + 1}:`, error);
        // Continue to next attempt rather than failing immediately
      }
    }
    
    // Final check with error handling
    let finalClipboard: string | null | undefined;
    try {
      finalClipboard = (await window.flutter_inappwebview.callHandler('readClipboard')) as string | null | undefined;
    } catch (error) {
      console.error('[Z.ai] Error reading final clipboard state:', error);
      finalClipboard = null;
    }
    
    // WHY: Fallback to direct DOM extraction if clipboard method fails
    // This provides a more robust extraction strategy similar to Kimi
    if (!finalClipboard || finalClipboard === uniqueToken || finalClipboard.trim().length === 0) {
      console.warn('[Z.ai] Clipboard extraction failed, attempting direct DOM extraction as fallback...');
      
      // Try to extract text directly from the chat-assistant element
      const chatAssistants = document.querySelectorAll('.chat-assistant');
      if (chatAssistants.length > 0) {
        const lastAssistant = chatAssistants[chatAssistants.length - 1] as HTMLElement;
        if (lastAssistant) {
          // WHY: Extract text from the assistant element, excluding thought process and action buttons
          const thoughtProcess = lastAssistant.querySelector('[class*="thought" i], [class*="process" i]');
          const actionButtons = lastAssistant.querySelectorAll('button, [class*="action" i]');
          
          // Clone to avoid modifying the original
          const clone = lastAssistant.cloneNode(true) as HTMLElement;
          
          // Remove thought process and action buttons from clone
          if (thoughtProcess) {
            thoughtProcess.remove();
          }
          actionButtons.forEach(btn => btn.remove());
          
          const extractedText = clone.innerText?.trim() || clone.textContent?.trim() || '';
          
          if (extractedText && extractedText.length > 0) {
            console.log(`[Z.ai] Direct DOM extraction successful: ${extractedText.length} chars extracted.`);
            return extractedText;
          }
        }
      }
      
      // Try extracting from response container if chat-assistant doesn't work
      const responseContainers = document.querySelectorAll('[class*="response" i], [class*="message" i]');
      if (responseContainers.length > 0) {
        const lastContainer = responseContainers[responseContainers.length - 1] as HTMLElement;
        if (lastContainer && !lastContainer.closest('.chat-user, [class*="user" i]')) {
          // Only extract if it's not a user message
          const extractedText = lastContainer.innerText?.trim() || lastContainer.textContent?.trim() || '';
          if (extractedText && extractedText.length > 0) {
            console.log(`[Z.ai] Direct DOM extraction from response container successful: ${extractedText.length} chars extracted.`);
            return extractedText;
          }
        }
      }
    } else {
      // Clipboard method succeeded
      console.log(`[Z.ai] Clipboard extraction successful: ${finalClipboard.length} chars extracted.`);
      return finalClipboard.trim();
    }
    
    console.error(`[Z.ai] All extraction methods failed. Clipboard: type=${typeof finalClipboard}, isNull=${finalClipboard === null}, isUndefined=${finalClipboard === undefined}, value=${finalClipboard?.substring(0, 100) ?? 'null/undefined'}`);
    throw new Error('[Z.ai] Extraction failed: Both clipboard and direct DOM extraction methods failed.');
  }
}

export const zAiChatbot = new ZAiChatbot();

