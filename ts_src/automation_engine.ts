// ts_src/automation_engine.ts
import { Chatbot, AutomationOptions } from './types/chatbot';
import { AiStudioChatbot, kimiChatbot } from './chatbots';
import { notifyDart } from './utils/notify-dart';
import { EVENT_TYPE_AUTOMATION_FAILED, EVENT_TYPE_NEW_RESPONSE, READY_HANDLER } from './utils/bridge-constants';

const BRIDGE_READY_RETRY_ATTEMPTS = 100;
const BRIDGE_READY_RETRY_DELAY_MS = 300;
const INITIAL_PROCESSED_FOOTERS_COUNT = 0;
const BUTTON_TEXT_PREVIEW_LENGTH = 100;

function signalReady() {
  // WHY: This is a robust defensive check. It verifies not only that the
  // flutter_inappwebview object exists, but also that the callHandler
  // method is present and is a function before attempting to call it.
  if (window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function') {
    try {
      window.flutter_inappwebview.callHandler(READY_HANDLER);
      console.log('[Engine] Bridge ready signal sent to Flutter.');
    } catch (e) {
      console.warn('[Engine] Failed to send bridge ready signal:', e);
    }
  }
}

// WHY: Listen for the official platform ready event - this is the most reliable signal
// that the bridge is initialized, as documented in flutter_inappwebview research
// The event fires when the platform is truly ready, avoiding race conditions
document.addEventListener('flutterInAppWebViewPlatformReady', () => {
  console.log('[Engine] Received flutterInAppWebViewPlatformReady event');
  signalReady();
});

function trySignalReady(retries = BRIDGE_READY_RETRY_ATTEMPTS, delay = BRIDGE_READY_RETRY_DELAY_MS) {
  if (retries <= 0) {
    console.warn('[Engine] Max retries reached for bridge ready signal.');
    return;
  }
  
  // WHY: Using the same robust check ensures retry logic only proceeds when
  // bridge is truly available and callHandler is accessible.
  if (window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function') {
    signalReady();
  } else {
    setTimeout(() => trySignalReady(retries - 1, delay), delay);
  }
}

// WHY: Make injection idempotent - check if script already initialized to avoid redefining functions
if (window.__AI_HYBRID_HUB_INITIALIZED__) {
  console.log('[Engine] Bridge script already initialized. Checking if functions exist...');
  
  const functionsExist = 
    typeof window.startAutomation !== 'undefined' &&
    typeof window.extractFinalResponse !== 'undefined' &&
    typeof window.inspectDOMForSelectors !== 'undefined';
  
  if (functionsExist) {
    console.log('[Engine] Functions exist, signaling ready.');
    trySignalReady();
  } else {
    console.warn('[Engine] Flag set but functions missing! Force re-initialization.');
    delete window.__AI_HYBRID_HUB_INITIALIZED__;
  }
}

if (!window.__AI_HYBRID_HUB_INITIALIZED__) {
  window.__AI_HYBRID_HUB_INITIALIZED__ = true;

  // Initialize global counter for tracking processed response footers
  window.__processedFootersCount = INITIAL_PROCESSED_FOOTERS_COUNT;

  // WHY: Encapsulated state management for automation engine.
  // Stores the current chatbot instance instead of just providerId for better
  // encapsulation and explicit state management.
  const automationState = {
    currentChatbot: null as Chatbot | null,
  };

  const SUPPORTED_SITES = {
    'ai_studio': new AiStudioChatbot(),
    'kimi': kimiChatbot,
    // Future: Add other providers here
    // 'chatgpt': chatGptChatbot,
    // 'claude': claudeChatbot,
  };

  // Finds the chatbot module corresponding to the providerId
  function getChatbot(providerId: string): Chatbot | null {
    const chatbot = SUPPORTED_SITES[providerId as keyof typeof SUPPORTED_SITES];
    if (chatbot) {
      console.log(`[Engine] Matched providerId: "${providerId}". Using corresponding chatbot module.`);
      return chatbot;
    }
    console.error(`[Engine] No chatbot module found for providerId: "${providerId}"`);
    return null;
  }

  // Global function called by Dart to start automation
  window.startAutomation = async function(options: AutomationOptions): Promise<void> {
    console.log('[Engine LOG] >>> Full automation cycle started by Dart. Options:', JSON.stringify(options, null, 2));
    
    // WHY: Reset the retry flag for each new automation run.
    window.__hasAttemptedRetry = false;
    
    // Set the global modifier for this run
    window.__AI_TIMEOUT_MODIFIER__ = options.timeoutModifier ?? 1.0;
    console.log(`[Engine] Using timeout modifier: ${window.__AI_TIMEOUT_MODIFIER__}x`);
    
    const chatbot = getChatbot(options.providerId);
    if (!chatbot) {
      notifyDart({ type: EVENT_TYPE_AUTOMATION_FAILED, errorCode: 'UNSUPPORTED_PROVIDER', payload: `Provider "${options.providerId}" is not supported.` });
      return;
    }

    // WHY: Store chatbot instance in state for use in extractFinalResponse
    automationState.currentChatbot = chatbot;

    const startTime = Date.now();
    let currentPhase = 'Initialization';
    
    try {
      // Phase 1: Reset the UI to a clean state (e.g., click "New Chat").
      if (chatbot.resetState) {
        currentPhase = 'Phase 1: Resetting UI state';
        console.log(`[Engine LOG] ${currentPhase}...`);
        await chatbot.resetState();
      }

      // Phase 2: Wait for the main UI to be ready and interactive.
      currentPhase = 'Phase 2: Waiting for UI to be ready';
      console.log(`[Engine LOG] ${currentPhase}...`);
      await chatbot.waitForReady();
      
      // Phase 3: Apply all configurations (Model, Temperature, System Prompt, etc.).
      currentPhase = 'Phase 3: Applying configurations';
      console.log(`[Engine LOG] ${currentPhase}...`);
      // WHY: System prompt often involves a separate dialog; handle it first
      if (options.systemPrompt && chatbot.setSystemPrompt) {
        console.log(`[Engine LOG] Setting system prompt (length: ${options.systemPrompt.length})`);
        await chatbot.setSystemPrompt(options.systemPrompt);
      }
      // Apply all other settings atomically via unified method
      if (chatbot.applyAllSettings) {
        await chatbot.applyAllSettings(options);
      }

      // Phase 4 & 5 combined: Enter prompt and wait for finalization.
      currentPhase = 'Phase 4: Sending prompt and awaiting finalization';
      console.log(`[Engine LOG] ${currentPhase}...`);
      await chatbot.sendPrompt(options.prompt);
      
      // Phase 6: Notify Dart that the response is ready for extraction.
      currentPhase = 'Phase 5: Notifying Dart of readiness';
      console.log(`[Engine LOG] ${currentPhase}...`);
      notifyDart({ type: EVENT_TYPE_NEW_RESPONSE });
      
      const elapsedTime = Date.now() - startTime;
      console.log(`[Engine LOG] Sequential automation cycle completed successfully in ${elapsedTime}ms.`);
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      const elapsedTime = Date.now() - startTime;
      const pageState = {
        url: window.location.href,
        readyState: document.readyState,
        visibleElements: document.querySelectorAll('*').length,
      };
      
      console.error(`[Engine LOG] Full automation cycle failed in ${currentPhase} after ${elapsedTime}ms!`, error);
      
      const diagnostics: Record<string, unknown> = {
        phase: currentPhase,
        elapsedTimeMs: elapsedTime,
        url: pageState.url,
        readyState: pageState.readyState,
        visibleElements: pageState.visibleElements,
        timestamp: new Date().toISOString(),
      };
      
      // Extract selector context from error message if available
      if (errorMessage.includes('Selector') || errorMessage.includes('selector')) {
        diagnostics.selectorContext = 'Error message contains selector information';
      }
      
      notifyDart({
        type: EVENT_TYPE_AUTOMATION_FAILED,
        errorCode: 'FULL_CYCLE_FAILED',
        location: 'startAutomation',
        payload: errorMessage,
        diagnostics: diagnostics,
      });
      // WHY: Re-throw error so the Future in Dart also fails
      throw error;
    }
  };

  // Global function called by Dart to extract the response
  window.extractFinalResponse = async function(): Promise<string> {
    console.log('[Engine LOG] extractFinalResponse called');
    
    const chatbot = automationState.currentChatbot;
    if (!chatbot) {
      const errorMsg = 'No chatbot available for extraction. Automation must be started first.';
      console.error('[Engine LOG] No chatbot found for extraction');
      notifyDart({ type: EVENT_TYPE_AUTOMATION_FAILED, errorCode: 'NO_CHATBOT_INSTANCE', payload: errorMsg });
      throw new Error(errorMsg);
    }

    const startTime = Date.now();
    console.log(`[Engine LOG] Starting extraction with chatbot: ${chatbot.constructor.name}`);
    
    try {
      // ENHANCED LOGGING: Log DOM state before extraction
      console.log('[Engine LOG] [ENHANCED] DOM state before extraction:', {
        url: window.location.href,
        readyState: document.readyState,
        title: document.title,
        timestamp: new Date().toISOString()
      });
      
      const result = await chatbot.extractResponse();
      const elapsedTime = Date.now() - startTime;
      console.log(`[Engine LOG] Extraction completed successfully in ${elapsedTime}ms, extracted ${result.length} chars`);
      
      // ENHANCED LOGGING: Log extraction result details
      console.log('[Engine LOG] [ENHANCED] Extraction result details:', {
        success: true,
        resultLength: result.length,
        resultPreview: result.substring(0, 100) + (result.length > 100 ? '...' : ''),
        elapsedTime: elapsedTime
      });
      
      return result;
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      const elapsedTime = Date.now() - startTime;
      
      // ENHANCED LOGGING: Log detailed error information
      console.error('[Engine LOG] [ENHANCED] Extraction failed with details:', {
        success: false,
        errorMessage: errorMessage,
        errorType: error instanceof Error ? error.constructor.name : typeof error,
        elapsedTime: elapsedTime,
        timestamp: new Date().toISOString(),
        // Log DOM state at time of error
        domState: {
          url: window.location.href,
          readyState: document.readyState,
          title: document.title,
          // Check for edit buttons
          editButtons: document.querySelectorAll('button[aria-label="Edit"]').length,
          // Check for textareas
          textareas: document.querySelectorAll('textarea, [contenteditable="true"]').length
        }
      });
      
      // Enhanced error with more context
      const enhancedErrorMessage = `Extraction failed: ${errorMessage} (Type: ${error instanceof Error ? error.constructor.name : typeof error}, Time: ${elapsedTime}ms)`;
      console.error(`[Engine LOG] ${enhancedErrorMessage}`);
      
      // Notify Dart with enhanced error information
      notifyDart({
        type: EVENT_TYPE_AUTOMATION_FAILED,
        errorCode: 'EXTRACTION_FAILED',
        payload: enhancedErrorMessage
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
    } catch {
      // Closed shadow DOM or other error
    }
    return null;
  }

  // WHY: Declare inspectDOMForSelectors directly on window for Dart to diagnose the DOM
  window.inspectDOMForSelectors = function(): Record<string, unknown> {
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
      } catch {
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
      } catch {
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

  console.log('[Engine] Bridge script injected. Waiting for flutter_inappwebview...');

  trySignalReady();
}
