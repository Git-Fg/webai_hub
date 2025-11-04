// ts_src/chatbots/ai-studio.ts

import { Chatbot } from '../types/chatbot';
import { notifyDart } from '../utils/notify-dart';
import { waitForElement, waitForElementWithin } from '../utils/wait-for-element';
import { 
  EVENT_TYPE_AUTOMATION_FAILED,
  EVENT_TYPE_LOGIN_REQUIRED,
  EVENT_TYPE_NEW_RESPONSE
} from '../utils/bridge-constants';

// --- Constants for Timing and Timeouts ---
const READINESS_CHECK_INTERVAL_MS = 100;
const SCREEN_WIDTH_BREAKPOINT_PX = 960;
const LOG_PREVIEW_LENGTH = 50;
const TOKEN_COUNT_UPDATE_TIMEOUT_MS = 5000;
const TOKEN_COUNT_CHECK_INTERVAL_MS = 100;
const FINALIZED_TURN_TIMEOUT_MS = 15000;
const FINALIZED_TURN_CHECK_INTERVAL_MS = 1000;
const EDIT_BUTTON_WAIT_TIMEOUT_MS = 2000;
const TEXTAREA_APPEAR_TIMEOUT_MS = 5000;
const UI_STABILIZE_DELAY_MS = 300;

// NOTE: READY_SELECTORS removed; readiness handled by explicit conditional checks below.

const PROMPT_INPUT_SELECTORS = [
  'ms-chunk-input textarea',
  "textarea[placeholder*='Start typing a prompt']",
  "textarea[aria-label*='Start typing a prompt']",
];

const SEND_BUTTON_SELECTORS = [
  'ms-run-button > button[aria-label="Run"]',
  'ms-run-button > button',
];

const MODEL_TURN_SELECTOR = 'ms-chat-turn[data-turn-role="Model"]';

// WHY: Wait for token count update to ensure prompt is processed before sending
const TOKEN_COUNT_SELECTOR = 'span.v3-token-count-value';

// Detects if current page is a Google login page
function isLoginPage(): boolean {
  const url = window.location.href.toLowerCase();
  if (url.includes('accounts.google.com') || url.includes('/signin')) {
    return true;
  }
  const emailInput = document.querySelector('input[type="email"]');
  const signInText = document.body?.innerText?.includes('Sign in');
  if (emailInput && signInText) {
    console.log('[AI Studio] Login page detected via DOM elements');
    return true;
  }
  return false;
}

// Implementation of Chatbot interface for Google AI Studio
export const aiStudioChatbot: Chatbot = {
  // WHY: Checks different elements based on screen size for more robust readiness detection
  waitForReady: async () => {
    await new Promise<void>((resolve) => {
      const check_for_element = () => {
        if (!document.querySelector('ms-incognito-mode-toggle > button')) {
          setTimeout(check_for_element, READINESS_CHECK_INTERVAL_MS);
          return;
        }
        if (window.innerWidth <= SCREEN_WIDTH_BREAKPOINT_PX) {
          if (document.querySelector('button.runsettings-toggle-button')) {
            resolve();
          } else {
            setTimeout(check_for_element, READINESS_CHECK_INTERVAL_MS);
          }
        } else {
          if (document.querySelector('button.model-selector-card')) {
            resolve();
          } else {
            setTimeout(check_for_element, READINESS_CHECK_INTERVAL_MS);
          }
        }
      };
      check_for_element();
    });
    console.log('[AI Studio] UI is ready.');
  },
  sendPrompt: async (prompt: string) => {
    console.log('[AI Studio] Starting automation with prompt:', prompt.substring(0, LOG_PREVIEW_LENGTH));
    
    if (isLoginPage()) {
      console.log('[AI Studio] Login page detected. Notifying Dart.');
      notifyDart({ 
        type: EVENT_TYPE_LOGIN_REQUIRED,
        location: 'sendPrompt',
        payload: 'User needs to sign in to Google Account'
      });
      // WHY: Return a promise that never resolves to stop the workflow
      return new Promise(() => {});
    }
    
    const inputArea = await waitForElement(PROMPT_INPUT_SELECTORS);
    if (inputArea instanceof HTMLTextAreaElement || inputArea instanceof HTMLInputElement) {
      inputArea.value = prompt;
      inputArea.dispatchEvent(new Event('input', { bubbles: true }));
      inputArea.dispatchEvent(new Event('change', { bubbles: true }));
    } else {
      throw new Error("Input area is not a valid textarea or input element.");
    }
    
    // TIMING: Wait for token count update with timeout to avoid blocking indefinitely
    await new Promise<void>((resolve, reject) => {
      const timeout = TOKEN_COUNT_UPDATE_TIMEOUT_MS;
      const startTime = Date.now();
      
      const checkTokenCount = () => {
        const elapsed = Date.now() - startTime;
        if (elapsed > timeout) {
          console.warn('[AI Studio] Token count timeout - proceeding anyway');
          resolve();
          return;
        }
        
        const tokenCountElement = document.querySelector(TOKEN_COUNT_SELECTOR);
        const text = tokenCountElement?.textContent?.trim();
        if (text && !text.startsWith('0')) {
          resolve();
        } else {
          setTimeout(checkTokenCount, TOKEN_COUNT_CHECK_INTERVAL_MS);
        }
      };
      checkTokenCount();
    });
    
    const sendButton = await waitForElement(SEND_BUTTON_SELECTORS) as HTMLElement;
    sendButton.click();
  },
  extractResponse: async (): Promise<string> => {
    console.log('[AI Studio] Starting extraction process...');
    
    // WHY: Start from "Edit" button and traverse up to parent container to avoid issues
    // with querySelectorAll on ms-chat-turn[data-turn-role="Model"]
    const waitForFinalizedTurn = (timeout = FINALIZED_TURN_TIMEOUT_MS): Promise<HTMLElement> => {
      return new Promise((resolve, reject) => {
        const intervalTime = FINALIZED_TURN_CHECK_INTERVAL_MS;
        let elapsedTime = 0;
        let checks = 0;

        const interval = setInterval(() => {
          checks++;
          
          // WHY: Find all "Edit" buttons - this is a simple and reliable selector
          const allEditButtons = document.querySelectorAll('button[aria-label="Edit"]');

          if (allEditButtons.length > 0) {
            const lastEditButton = allEditButtons[allEditButtons.length - 1] as HTMLElement;
            const parentTurn = lastEditButton.closest('ms-chat-turn');
            
            if (parentTurn) {
              const lastElement = parentTurn as HTMLElement;
              const isVisible = lastElement.offsetParent !== null;
              const isNotEditing = !lastElement.querySelector('textarea');

              if (isVisible && isNotEditing) {
                console.log(`[AI Studio] Success: Found a finalized model turn by traversing up from an 'Edit' button.`);
                clearInterval(interval);
                resolve(lastElement);
                return;
              } else {
                console.log(`[AI Studio] Found a candidate turn, but it's not ready (Visible: ${isVisible}, Not Editing: ${isNotEditing}).`);
              }
            } else {
              console.warn(`[AI Studio] Found an 'Edit' button but could not find parent ms-chat-turn element.`);
            }
          }

          elapsedTime += intervalTime;
          if (elapsedTime >= timeout) {
            clearInterval(interval);
            // WHY: Auto-run DOM inspection on failure to help with debugging
            console.error('[AI Studio] Timeout reached. Automatically running DOM inspection...');
            try {
              (window as any).inspectDOMForSelectors();
            } catch(e) {
              console.error('[AI Studio] Failed to run inspectDOMForSelectors.', e);
            }
            reject(new Error(`Extraction timed out: No 'Edit' button found on any model response within ${timeout}ms.`));
          }
        }, intervalTime);
      });
    };

    const lastTurn = await waitForFinalizedTurn();
    
    console.log('[AI Studio] Target turn element for extraction (outerHTML):', lastTurn.outerHTML);
    
    const editButton = await waitForElementWithin(lastTurn, ['button[aria-label="Edit"]'], EDIT_BUTTON_WAIT_TIMEOUT_MS) as HTMLElement;
    if (!editButton) {
      throw new Error("Could not find the 'Edit' button within the last assistant turn.");
    }
    editButton.click();
    console.log('[AI Studio] Clicked "Edit" button.');

    const textarea = await waitForElementWithin(lastTurn, ['textarea'], TEXTAREA_APPEAR_TIMEOUT_MS) as HTMLTextAreaElement;
    
    // TIMING: Allow framework to stabilize UI after textarea appears.
    // This delay allows the framework to complete micro-tasks (event listeners, value population).
    await new Promise(resolve => setTimeout(resolve, UI_STABILIZE_DELAY_MS));
    
    const extractedContent = (textarea.value || '').trim();
    console.log(`[AI Studio] Extracted ${extractedContent.length} chars successfully:`, extractedContent);

    if (!extractedContent) {
        throw new Error('Textarea was found but it was empty.');
    }

    // WHY: Cleanup operations are for UX but should not fail extraction
    try {
      const stopEditingButton = await waitForElementWithin(lastTurn, ['button[aria-label="Stop editing"]'], EDIT_BUTTON_WAIT_TIMEOUT_MS) as HTMLElement;
      if (stopEditingButton) {
        // TIMING: Allow time before exiting edit mode.
        // This delay allows Google telemetry calls to complete without being interrupted
        // by our click on "Stop editing", avoiding TextDecoder errors.
        await new Promise(resolve => setTimeout(resolve, UI_STABILIZE_DELAY_MS));
        
        stopEditingButton.click();
        console.log('[AI Studio] Exited edit mode.');
      }
    } catch (e) {
      // WHY: We intentionally ignore this error. The important thing is to have the text.
      console.warn('[AI Studio] Could not exit edit mode, but extraction was successful. This is non-critical.');
    }
    
    return extractedContent;
  },
};

