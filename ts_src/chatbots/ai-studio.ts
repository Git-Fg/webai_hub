// ts_src/chatbots/ai-studio.ts
import { Chatbot } from '../types/chatbot';
import { notifyDart } from '../utils/notify-dart';
import { waitForElement } from '../utils/wait-for-element';

// --- SÉLECTEURS HAUTE-FIDÉLITÉ BASÉS SUR L'ANALYSE ---

// Pour attendre que la page soit prête (éléments stables)
const READY_SELECTORS = [
  'ms-incognito-mode-toggle > button',
  'button.runsettings-toggle-button',
  'button.model-selector-card',
  'ms-chunk-input textarea' // Fallback pour le sandbox
];

// Pour trouver le champ de saisie du prompt
const PROMPT_INPUT_SELECTOR = 'ms-chunk-input textarea';

// Pour trouver le bouton d'envoi
const SEND_BUTTON_SELECTOR = 'ms-run-button > button';

// Pour savoir si une génération est en cours
const GENERATION_INDICATOR_SELECTOR = 'mat-icon[data-mat-icon-name="stop"]';

// Pour trouver tous les tours de conversation du modèle
const MODEL_TURN_SELECTOR = 'ms-chat-turn[data-turn-role="Model"]';

// Pour détecter la fin de l'affichage d'une réponse
const RESPONSE_FOOTER_SELECTOR = 'ms-chat-turn .turn-footer button[iconname="thumb_up"]';

// Pour attendre la mise à jour du compteur de tokens
const TOKEN_COUNT_SELECTOR = 'span.v3-token-count-value';

// Sélecteurs améliorés basés sur la structure réelle d'AI Studio (fallbacks)
const PROMPT_INPUT_SELECTORS = [
  'ms-chunk-input textarea', // Sélecteur très spécifique et moderne pour AI Studio
  "textarea[placeholder*='Start typing a prompt']", // High-fidelity: real site structure
  "textarea[aria-label*='Start typing a prompt']", // Alternative aria-label
  "textarea[placeholder*='typing a prompt']",
  "input[placeholder*='Start typing a prompt']",
  "input[placeholder*='typing a prompt']",
  "textarea[placeholder*='prompt']",
  "input[placeholder*='prompt']",
  "input-area", // Original blueprint selector
  "textarea[aria-label*='prompt']",
  "textarea[name*='prompt']",
  "textarea[id*='prompt']",
  ".ql-editor",
  "div[contenteditable='true']",
  "textarea",
  "input[type='text']"
];

const SEND_BUTTON_SELECTORS = [
  'ms-run-button > button[aria-label="Run"]', // Sélecteur spécifique
  'ms-run-button > button',
  'button[aria-label="Run"]', // High-fidelity: exact match for real site
  'button[aria-label*="Run"]',
  'button[aria-label*="Append to prompt and run"]',
  'button[aria-label*="Append to Prompt and run"]',
  'button[aria-label*="run"]',
  'send-button[variant="primary"]', // Original blueprint selector
  'button[aria-label*="Send"]',
  'button:contains("Run")',
  '.send-button button',
  'button[type="submit"]',
  'button' // Fallback to any button
];

const GENERATION_INDICATOR_SELECTORS = [
  // L'icône "stop" est le meilleur indicateur que la génération est en cours.
  'mat-icon[data-mat-icon-name="stop"]',
  'ms-thought-chunk .thinking-progress-icon.in-progress',
  'ms-thought-chunk', // High-fidelity: thought chunk appears during generation
  ".generating-indicator",
  ".loading-indicator",
  "[data-testid*='generating']",
  ".spinner",
  ".loading-spinner",
  ".thinking-indicator"
];

const RESPONSE_CONTAINER_SELECTOR = 'ms-chat-turn[data-turn-role="Model"]';

// Détecte si la page actuelle est une page de login Google
function isLoginPage(): boolean {
  // Sélecteurs typiques de la page de login Google
  const loginSelectors = [
    'input[placeholder*="Email or phone"]',
    'input[type="email"]',
    'text:contains("Sign in")',
    'text:contains("Use your Google Account")',
    'button:contains("Next")',
  ];
  
  // Vérifier l'URL
  const url = window.location.href.toLowerCase();
  if (url.includes('accounts.google.com') || url.includes('/signin')) {
    return true;
  }
  
  // Vérifier les éléments du DOM
  const emailInput = document.querySelector('input[placeholder*="Email or phone"], input[type="email"]');
  const signInText = document.body?.innerText?.includes('Sign in') || 
                    document.body?.innerText?.includes('Use your Google Account');
  
  if (emailInput && signInText) {
    console.log('[AI Studio] Login page detected via DOM elements');
    return true;
  }
  
  return false;
}

// Debug function to inspect DOM elements
function debugDOMStructure(): void {
  const allInputs = Array.from(document.querySelectorAll('input, textarea, [contenteditable="true"]'));
  const allButtons = Array.from(document.querySelectorAll('button'));
  
  console.log('[AI Studio] Found inputs:', allInputs.map(el => ({
    tag: el.tagName,
    type: (el as HTMLElement).getAttribute('type'),
    placeholder: (el as HTMLElement).getAttribute('placeholder'),
    ariaLabel: (el as HTMLElement).getAttribute('aria-label'),
    id: el.id,
    className: el.className,
    contentEditable: (el as HTMLElement).contentEditable
  })));
  
  console.log('[AI Studio] Found buttons:', allButtons.slice(0, 10).map(el => ({
    tag: el.tagName,
    ariaLabel: el.getAttribute('aria-label'),
    text: el.innerText?.substring(0, 50),
    id: el.id,
    className: el.className,
    type: el.getAttribute('type')
  })));
}

// Helper pour extraire uniquement le texte de la réponse, en excluant les éléments UI
function extractCleanResponseText(element: HTMLElement): string {
  // Créer une copie pour ne pas modifier l'original
  const clone = element.cloneNode(true) as HTMLElement;
  
  // Nettoyage ciblé basé sur la structure d'AI Studio
  clone.querySelector('.turn-footer')?.remove();
  clone.querySelector('.author-label')?.remove();
  clone.querySelector('.actions-container')?.remove();
  clone.querySelector('ms-thought-chunk')?.remove();
  
  // Supprimer tous les éléments UI (boutons, navigation, etc.)
  const uiElements = clone.querySelectorAll('button, nav, [role="button"], [aria-label*="Edit"], [aria-label*="Rerun"], [aria-label*="Good"], [aria-label*="Bad"], [aria-label*="More"], .scrollbar-item, .navigation, [data-testid*="button"]');
  uiElements.forEach(el => el.remove());
  
  // Extraire le texte propre
  let text = (clone.textContent || clone.innerText || "").trim();
  
  // Nettoyer le texte : supprimer les séparateurs répétitifs et les lignes vides multiples
  text = text.replace(/\n{3,}/g, '\n\n'); // Max 2 sauts de ligne consécutifs
  text = text.replace(/^\s+|\s+$/gm, ''); // Supprimer les espaces en début/fin de ligne
  
  return text;
}

// Implémentation de l'interface Chatbot pour Google AI Studio
export const aiStudioChatbot: Chatbot = {
  waitForReady: async () => {
    // On attend un des éléments clés de l'interface. `waitForElement`
    // s'arrêtera dès que le premier est trouvé.
    await waitForElement(READY_SELECTORS, 20000);
    console.log('[AI Studio] UI is ready.');
  },

  sendPrompt: async (prompt: string) => {
    console.log('[AI Studio] Starting automation with prompt:', prompt.substring(0, 50));
    
    // Vérifier si on est sur une page de login
    if (isLoginPage()) {
      console.log('[AI Studio] Login page detected. Pausing automation.');
      notifyDart({ 
        type: 'LOGIN_REQUIRED',
        location: 'sendPrompt',
        payload: 'User needs to sign in to Google Account'
      });
      return; // Arrêter ici, attendre que l'utilisateur se connecte
    }
    
    // Debug DOM structure
    debugDOMStructure();

    // 1. Trouver et remplir la zone de texte
    console.log('[AI Studio] Waiting for input area...');
    const inputArea = await waitForElement([PROMPT_INPUT_SELECTOR, ...PROMPT_INPUT_SELECTORS]);
    console.log('[AI Studio] Found input area:', inputArea.tagName, inputArea.className);

    if (inputArea.tagName === 'TEXTAREA' || inputArea.tagName === 'INPUT') {
      const input = inputArea as HTMLInputElement | HTMLTextAreaElement;
      input.value = prompt;
      inputArea.dispatchEvent(new Event('input', { bubbles: true }));
      inputArea.dispatchEvent(new Event('change', { bubbles: true }));
    } else if (inputArea instanceof HTMLElement && inputArea.contentEditable === 'true') {
      const editable = inputArea as HTMLElement;
      editable.innerText = prompt;
      inputArea.dispatchEvent(new Event('input', { bubbles: true }));
    } else {
      const element = inputArea as HTMLElement;
      element.click();
      await new Promise<void>(resolve => setTimeout(() => resolve(), 500));
      const fallbackInput = element as HTMLInputElement;
      if (fallbackInput.value !== undefined) {
        fallbackInput.value = prompt;
      }
    }

    // 2. Attendre que le compteur de tokens se mette à jour (plus fiable qu'un délai fixe)
    await new Promise<void>((resolve) => {
      const checkTokenCount = () => {
        const tokenCountElement = document.querySelector(TOKEN_COUNT_SELECTOR);
        const text = tokenCountElement?.textContent?.trim();
        // On attend que le texte existe et ne soit pas "0"
        if (text && !text.startsWith('0')) {
          console.log('[AI Studio] Token count updated.');
          resolve();
        } else {
          setTimeout(checkTokenCount, 100);
        }
      };
      checkTokenCount();
    });

    // 3. Trouver et cliquer sur le bouton d'envoi
    console.log('[AI Studio] Waiting for send button...');
    const sendButton = await waitForElement([SEND_BUTTON_SELECTOR, ...SEND_BUTTON_SELECTORS]) as HTMLElement;
    console.log('[AI Studio] Found send button:', sendButton.tagName, sendButton.className, sendButton.getAttribute('aria-label'));
    sendButton.click();
    console.log('[AI Studio] Clicked send button');
    
    // 4. Attendre la fin de la génération
    // On attend d'abord que l'indicateur APPARAISSE...
    try {
      await waitForElement([GENERATION_INDICATOR_SELECTOR, ...GENERATION_INDICATOR_SELECTORS], 10000);
      console.log('[AI Studio] Generation started, observing for completion...');
    } catch (e) {
      console.log('[AI Studio] Generation indicator not found, assuming generation is fast and complete.');
      notifyDart({ type: 'GENERATION_COMPLETE' });
      return;
    }

    // ...puis on attend qu'il DISPARAISSE.
    await new Promise<void>((resolve) => {
      const observer = new MutationObserver(() => {
        if (!document.querySelector(GENERATION_INDICATOR_SELECTOR)) {
          console.log('[AI Studio] Generation indicator disappeared.');
          // On notifie immédiatement Dart de la fin de la génération.
          notifyDart({ type: 'GENERATION_COMPLETE' });
          observer.disconnect();
          clearTimeout(fallbackTimeout);
          resolve();
        }
      });

      observer.observe(document.body, { childList: true, subtree: true });

      const fallbackTimeout = setTimeout(() => {
        console.warn('[AI Studio] Generation observer timed out.');
        notifyDart({ type: 'GENERATION_COMPLETE' });
        observer.disconnect();
        resolve();
      }, 60000);
    });
  },

  extractResponse: async () => {
    console.log('[AI Studio] Starting extraction...');
    
    // Attendre que la dernière réponse soit stable (que son footer soit visible)
    try {
      await waitForElement([RESPONSE_FOOTER_SELECTOR], 3000);
      console.log('[AI Studio] Response footer detected, response is stable.');
    } catch (e) {
      console.log('[AI Studio] Footer not found, assuming response is ready.');
    }
    
    // Cibler tous les tours du modèle
    const modelTurns = document.querySelectorAll(MODEL_TURN_SELECTOR);
    console.log(`[AI Studio] Found ${modelTurns.length} model turn(s)`);
    
    if (modelTurns.length === 0) {
        throw new Error("No model turns found on the page.");
    }

    // Prendre le tout dernier tour
    const lastElement = modelTurns[modelTurns.length - 1] as HTMLElement;
    
    // Extraire le texte propre en excluant les éléments UI
    const responseText = extractCleanResponseText(lastElement);

    if (!responseText) {
      throw new Error("Extraction resulted in an empty string after cleaning.");
    }

    console.log('[AI Studio] Returning value:', `"${responseText.substring(0, 100)}..."`, 'with type:', typeof responseText);
    return responseText;
  },
};

