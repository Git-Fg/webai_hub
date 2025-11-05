// ts_src/automation_engine.ts
import { Chatbot } from './types/chatbot';
import { aiStudioChatbot } from './chatbots';
import { notifyDart } from './utils/notify-dart';
import { EVENT_TYPE_AUTOMATION_FAILED, EVENT_TYPE_NEW_RESPONSE, READY_HANDLER } from './utils/bridge-constants';

const BRIDGE_READY_RETRY_ATTEMPTS = 100;
const BRIDGE_READY_RETRY_DELAY_MS = 300;
const UI_STATE_DEBOUNCE_DELAY_MS = 250;
const MIN_EDIT_BUTTONS_FOR_NOTIFICATION = 2;
const INITIAL_PROCESSED_FOOTERS_COUNT = 0;
const BUTTON_TEXT_PREVIEW_LENGTH = 100;

interface WindowWithFlutterInAppWebView extends Window {
  flutter_inappwebview?: {
    callHandler(handlerName: string, ...args: unknown[]): void;
  };
  startAutomation?: (prompt: string) => Promise<void>;
  extractFinalResponse?: () => Promise<string>;
}

function signalReady() {
  const windowWithFlutter = window as WindowWithFlutterInAppWebView;
  if (windowWithFlutter.flutter_inappwebview) {
    try {
      windowWithFlutter.flutter_inappwebview.callHandler(READY_HANDLER);
      console.log('[Engine] Bridge ready signal sent to Flutter.');
    } catch (e) {
      console.warn('[Engine] Failed to send bridge ready signal:', e);
    }
  }
}

function trySignalReady(retries = BRIDGE_READY_RETRY_ATTEMPTS, delay = BRIDGE_READY_RETRY_DELAY_MS) {
  if (retries <= 0) {
    console.warn('[Engine] Max retries reached for bridge ready signal.');
    return;
  }
  
  const windowWithFlutter = window as WindowWithFlutterInAppWebView;
  if (windowWithFlutter.flutter_inappwebview) {
    signalReady();
  } else {
    setTimeout(() => trySignalReady(retries - 1, delay), delay);
  }
}

// WHY: Make injection idempotent - check if script already initialized to avoid redefining functions
if ((window as any).__AI_HYBRID_HUB_INITIALIZED__) {
  console.log('[Engine] Bridge script already initialized. Checking if functions exist...');
  
  const functionsExist = 
    typeof (window as any).startAutomation !== 'undefined' &&
    typeof (window as any).extractFinalResponse !== 'undefined' &&
    typeof (window as any).inspectDOMForSelectors !== 'undefined';
  
  if (functionsExist) {
    console.log('[Engine] Functions exist, signaling ready.');
    trySignalReady();
  } else {
    console.warn('[Engine] Flag set but functions missing! Force re-initialization.');
    delete (window as any).__AI_HYBRID_HUB_INITIALIZED__;
  }
}

if (!(window as any).__AI_HYBRID_HUB_INITIALIZED__) {
  (window as any).__AI_HYBRID_HUB_INITIALIZED__ = true;

  // Initialize global counter for tracking processed response footers
  (window as any).__processedFootersCount = INITIAL_PROCESSED_FOOTERS_COUNT;

  const SUPPORTED_SITES = {
    'https://aistudio.google.com': aiStudioChatbot,
    // Future: Add other sites here
    // 'https://chatgpt.com/': chatGptChatbot,
    // 'https://claude.ai/': claudeChatbot,
  };

  // Finds the chatbot module corresponding to the current URL
  function getChatbot(): Chatbot | null {
    const currentUrl = window.location.href;
    
    for (const [baseUrl, chatbot] of Object.entries(SUPPORTED_SITES)) {
      if (currentUrl.startsWith(baseUrl)) {
        console.log(`[Engine] Matched site: ${baseUrl}. Using corresponding chatbot module.`);
        return chatbot;
      }
    }
    console.error(`[Engine] No chatbot module found for current URL: ${currentUrl}`);
    return null;
  }

  // Global function called by Dart to start automation
  (window as any).startAutomation = async function(prompt: string): Promise<void> {
    const chatbot = getChatbot();
    if (!chatbot) {
      notifyDart({ type: EVENT_TYPE_AUTOMATION_FAILED, errorCode: 'UNSUPPORTED_SITE', payload: 'This site is not supported.' });
      return;
    }

    try {
      console.log('[Engine] Waiting for chatbot page to be ready...');
      await chatbot.waitForReady();
      console.log('[Engine] Page is ready. Sending prompt...');
      await chatbot.sendPrompt(prompt);
      console.log('[Engine] Prompt sent. Observation will be handled by Dart.');
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      notifyDart({
        type: EVENT_TYPE_AUTOMATION_FAILED,
        errorCode: 'AUTOMATION_EXECUTION_FAILED',
        location: 'startAutomation',
        payload: errorMessage,
      });
      // WHY: Re-throw error so the Future in Dart also fails
      throw error;
    }
  };

  // Global function called by Dart to extract the response
  (window as any).extractFinalResponse = async function(): Promise<string> {
    const chatbot = getChatbot();
    if (!chatbot) {
      const errorMsg = 'This site is not supported for extraction.';
      notifyDart({ type: EVENT_TYPE_AUTOMATION_FAILED, errorCode: 'UNSUPPORTED_SITE', payload: errorMsg });
      throw new Error(errorMsg);
    }

    try {
      return await chatbot.extractResponse();
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      notifyDart({
        type: EVENT_TYPE_AUTOMATION_FAILED,
        errorCode: 'RESPONSE_EXTRACTION_FAILED',
        location: 'extractFinalResponse',
        payload: errorMessage,
      });
      throw error;
    }
  };

  // Helper to check for Shadow DOM
  function findInShadowDOM(selector: string, root: Document | ShadowRoot = document): Element | null {
    try {
      const element = root.querySelector(selector);
      if (element) return element;
      
      const allElements = root.querySelectorAll('*');
      for (const el of allElements) {
        if (el.shadowRoot) {
          const found = findInShadowDOM(selector, el.shadowRoot);
          if (found) return found;
        }
      }
    } catch (e) {
      // Closed shadow DOM or other error
    }
    return null;
  }

  // WHY: Declare inspectDOMForSelectors directly on window for Dart to diagnose the DOM
  (window as any).inspectDOMForSelectors = function(): Record<string, unknown> {
    const result: Record<string, unknown> = {
      inputs: [],
      buttons: [],
      allSelectorsTested: {},
      shadowDOMDetected: false
    };
    
    // Check for Shadow DOM
    const allElements = document.querySelectorAll('*');
    for (const el of allElements) {
      if (el.shadowRoot) {
        result.shadowDOMDetected = true;
        break;
      }
    }
    
    // Test common selectors (generic version since specific selectors are now in chatbots)
    const commonInputSelectors = [
      "textarea[placeholder*='prompt']",
      "input[placeholder*='prompt']",
      "textarea",
      "input[type='text']"
    ];
    
    const inputMatches: Record<string, Element | null> = {};
    for (const selector of commonInputSelectors) {
      try {
        inputMatches[selector] = document.querySelector(selector);
        // Also check Shadow DOM
        if (!inputMatches[selector]) {
          inputMatches[`${selector} (shadow)`] = findInShadowDOM(selector);
        }
      } catch (e) {
        inputMatches[selector] = null;
      }
    }
    (result.allSelectorsTested as Record<string, unknown>).promptInput = inputMatches;
    
    // Test common button selectors
    const commonButtonSelectors = [
      'button[aria-label*="Run"]',
      'button[aria-label*="Send"]',
      'button[type="submit"]',
      'button'
    ];
    
    const buttonMatches: Record<string, Element | null> = {};
    for (const selector of commonButtonSelectors) {
      try {
        buttonMatches[selector] = document.querySelector(selector);
        // Also check Shadow DOM
        if (!buttonMatches[selector]) {
          buttonMatches[`${selector} (shadow)`] = findInShadowDOM(selector);
        }
      } catch (e) {
        buttonMatches[selector] = null;
      }
    }
    (result.allSelectorsTested as Record<string, unknown>).sendButton = buttonMatches;
    
    // Find all inputs (including in Shadow DOM)
    const allInputs = Array.from(document.querySelectorAll('input, textarea, [contenteditable="true"]'));
    result.inputs = allInputs.map(el => {
      const htmlEl = el as HTMLElement;
      return {
        tag: el.tagName.toLowerCase(),
        type: htmlEl.getAttribute('type') || '',
        placeholder: htmlEl.getAttribute('placeholder') || '',
        ariaLabel: htmlEl.getAttribute('aria-label') || '',
        id: el.id || '',
        className: el.className || '',
        contentEditable: htmlEl.contentEditable,
        visible: htmlEl.offsetParent !== null,
        inShadowDOM: false
      };
    });
    
    // Find all buttons
    const allButtons = Array.from(document.querySelectorAll('button'));
    result.buttons = allButtons.map(el => {
      const htmlEl = el as HTMLElement;
      return {
        tag: el.tagName.toLowerCase(),
        ariaLabel: htmlEl.getAttribute('aria-label') || '',
        text: (htmlEl.innerText || '').substring(0, BUTTON_TEXT_PREVIEW_LENGTH),
        id: el.id || '',
        className: el.className || '',
        type: htmlEl.getAttribute('type') || '',
        visible: htmlEl.offsetParent !== null,
        inShadowDOM: false
      };
    });
    
    return result;
  };

  let responseObserver: MutationObserver | null = null;
  let debounceTimer: number | null = null;

  // WHY: Function that checks current page state with debouncing
  function checkUIState() {
    if (debounceTimer) {
      clearTimeout(debounceTimer);
    }

    // WHY: Launch new timer. If no new mutation arrives for 250ms, execute the check.
    debounceTimer = window.setTimeout(() => {
      const editButtons = document.querySelectorAll('button[aria-label="Edit"]');
      
      // WHY: Notify Dart only if we have at least 2 conversation turns (first + new response)
      // meaning at least 2 "Edit" buttons (one for each previous response).
      if (editButtons.length >= MIN_EDIT_BUTTONS_FOR_NOTIFICATION) {
        console.log(`[Observer] Detected ${editButtons.length} 'Edit' buttons. Notifying Dart that UI is ready for refinement.`);
        notifyDart({ type: EVENT_TYPE_NEW_RESPONSE });
        stopObserving();
      }
    }, UI_STATE_DEBOUNCE_DELAY_MS);
  }

  // WHY: Start DOM observation, ensuring no multiple observers at the same time
  function startObserving() {
    if (responseObserver) {
      stopObserving();
    }
    
    const targetNode = document.querySelector('ms-chat-session') || document.body;

    responseObserver = new MutationObserver(checkUIState);
    responseObserver.observe(targetNode, { childList: true, subtree: true });

    console.log('[Observer] Started observing DOM for new responses.');
  }

  function stopObserving() {
    if (responseObserver) {
      responseObserver.disconnect();
      responseObserver = null;
      console.log('[Observer] Stopped observing DOM.');
    }
    if (debounceTimer) {
      clearTimeout(debounceTimer);
      debounceTimer = null;
    }
  }

  // WHY: Expose global function for Dart to start observation
  (window as any).startResponseObserver = startObserving;

  console.log('[Engine] Bridge script injected. Waiting for flutter_inappwebview...');

  trySignalReady();
}
