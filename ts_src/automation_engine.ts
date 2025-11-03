// ts_src/automation_engine.ts
import { Chatbot } from './types/chatbot';
import { aiStudioChatbot } from './chatbots';
import { notifyDart } from './utils/notify-dart';

// --- Définition des sites supportés ---
const SUPPORTED_SITES = {
  'https://aistudio.google.com/prompts/new_chat': aiStudioChatbot,
  // À l'avenir, vous ajouterez d'autres sites ici :
  // 'https://chatgpt.com/': chatGptChatbot,
  // 'https://claude.ai/': claudeChatbot,
};

// --- Fonctions globales exposées à Flutter ---

// Trouve le module de chatbot correspondant à l'URL actuelle
function getChatbot(): Chatbot | null {
  const currentUrl = window.location.href;
  
  // Détecter le sandbox local (pour les tests) - vérifier si on est sur file:// ou si on trouve les éléments du sandbox
  const isLocalSandbox = currentUrl.startsWith('file://') || 
                         document.querySelector('ms-chunk-input textarea') !== null ||
                         document.querySelector('h1')?.textContent?.includes('High-Fidelity Sandbox');
  
  if (isLocalSandbox) {
    console.log('[Engine] Local sandbox detected. Using AI Studio chatbot module for testing.');
    return aiStudioChatbot;
  }
  
  // Détecter les vrais sites
  for (const [baseUrl, chatbot] of Object.entries(SUPPORTED_SITES)) {
    if (currentUrl.startsWith(baseUrl)) {
      console.log(`[Engine] Matched site: ${baseUrl}. Using corresponding chatbot module.`);
      return chatbot;
    }
  }
  console.error(`[Engine] No chatbot module found for current URL: ${currentUrl}`);
  return null;
}

// Fonction globale appelée par Dart pour démarrer l'automatisation
(window as any).startAutomation = async function(prompt: string): Promise<void> {
  const chatbot = getChatbot();
  if (!chatbot) {
    notifyDart({ type: 'AUTOMATION_FAILED', errorCode: 'UNSUPPORTED_SITE', payload: 'This site is not supported.' });
    return;
  }

  try {
    console.log('[Engine] Waiting for chatbot page to be ready...');
    await chatbot.waitForReady();
    console.log('[Engine] Page is ready. Sending prompt...');
    await chatbot.sendPrompt(prompt);
    console.log('[Engine] Prompt sent and generation completed successfully.');
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    notifyDart({
      type: 'AUTOMATION_FAILED',
      errorCode: 'AUTOMATION_EXECUTION_FAILED',
      location: 'startAutomation',
      payload: errorMessage,
    });
    // Il est important de re-throw l'erreur pour que le Future en Dart échoue aussi.
    throw error;
  }
};

// Fonction globale appelée par Dart pour extraire la réponse
(window as any).extractFinalResponse = async function(): Promise<string> {
  const chatbot = getChatbot();
  if (!chatbot) {
    const errorMsg = 'This site is not supported for extraction.';
    notifyDart({ type: 'AUTOMATION_FAILED', errorCode: 'UNSUPPORTED_SITE', payload: errorMsg });
    throw new Error(errorMsg);
  }

  try {
    return await chatbot.extractResponse();
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    notifyDart({
      type: 'AUTOMATION_FAILED',
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

// Déclarer inspectDOMForSelectors DIRECTEMENT sur window
// Cette fonction est utilisée par Dart pour diagnostiquer le DOM
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
  
  // Test common selectors (version générique car les sélecteurs spécifiques sont maintenant dans les chatbots)
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
      text: (htmlEl.innerText || '').substring(0, 100),
      id: el.id || '',
      className: el.className || '',
      type: htmlEl.getAttribute('type') || '',
      visible: htmlEl.offsetParent !== null,
      inShadowDOM: false
    };
  });
  
  return result;
};

// --- Initialisation du Bridge ---

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
      windowWithFlutter.flutter_inappwebview.callHandler('bridgeReady');
      console.log('[Engine] Bridge ready signal sent to Flutter.');
    } catch (e) {
      console.warn('[Engine] Failed to send bridge ready signal:', e);
    }
  }
}

function trySignalReady(retries = 100, delay = 300) {
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

console.log('[Engine] Bridge script injected. Waiting for flutter_inappwebview...');
console.log('[Engine] startAutomation available:', typeof (window as any).startAutomation);
console.log('[Engine] extractFinalResponse available:', typeof (window as any).extractFinalResponse);
console.log('[Engine] window.flutter_inappwebview available:', typeof (window as WindowWithFlutterInAppWebView).flutter_inappwebview);
console.log('[Engine] Document ready state:', document.readyState);
console.log('[Engine] Document body exists:', !!document.body);

trySignalReady();
