// ts_src/chatbots/ai-studio.ts

// --- MODIFIÉ : Fichier entièrement mis à jour avec la logique de webuiselector.md ---

import { Chatbot } from '../types/chatbot';
import { notifyDart } from '../utils/notify-dart';
import { waitForElement, waitForElementWithin } from '../utils/wait-for-element';
import { 
  EVENT_TYPE_AUTOMATION_FAILED,
  EVENT_TYPE_LOGIN_REQUIRED,
  EVENT_TYPE_NEW_RESPONSE
} from '../utils/bridge-constants';

// --- NOUVEAU : Sélecteurs haute-fidélité basés sur la nouvelle analyse ---

// NOTE: READY_SELECTORS removed; readiness handled by explicit conditional checks below.

// Pour trouver le champ de saisie du prompt
const PROMPT_INPUT_SELECTORS = [
  'ms-chunk-input textarea', // Sélecteur très spécifique et moderne pour AI Studio
  "textarea[placeholder*='Start typing a prompt']",
  "textarea[aria-label*='Start typing a prompt']",
];

// Pour trouver le bouton d'envoi
const SEND_BUTTON_SELECTORS = [
  'ms-run-button > button[aria-label="Run"]', // Sélecteur spécifique
  'ms-run-button > button',
];

// Pour trouver tous les tours de conversation du modèle
const MODEL_TURN_SELECTOR = 'ms-chat-turn[data-turn-role="Model"]';

// Pour attendre la mise à jour du compteur de tokens (fiabilise l'envoi)
const TOKEN_COUNT_SELECTOR = 'span.v3-token-count-value';

// Détecte si la page actuelle est une page de login Google
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


// Implémentation de l'interface Chatbot pour Google AI Studio
export const aiStudioChatbot: Chatbot = {
  // --- MODIFIÉ : Logique plus robuste pour la détection de l'état "prêt" ---
  waitForReady: async () => {
    // Cette nouvelle logique vérifie différents éléments en fonction de la taille de l'écran,
    // ce qui la rend plus robuste que l'ancienne.
    await new Promise<void>((resolve) => {
      const check_for_element = () => {
        if (!document.querySelector('ms-incognito-mode-toggle > button')) {
          setTimeout(check_for_element, 100);
          return;
        }
        if (window.innerWidth <= 960) {
          if (document.querySelector('button.runsettings-toggle-button')) {
            resolve();
          } else {
            setTimeout(check_for_element, 100);
          }
        } else {
          if (document.querySelector('button.model-selector-card')) {
            resolve();
          } else {
            setTimeout(check_for_element, 100);
          }
        }
      };
      check_for_element();
    });
    console.log('[AI Studio] UI is ready.');
  },
  // --- MODIFIÉ : Remplacement du délai fixe par une attente intelligente ---
  sendPrompt: async (prompt: string) => {
    console.log('[AI Studio] Starting automation with prompt:', prompt.substring(0, 50));
    
    if (isLoginPage()) {
      console.log('[AI Studio] Login page detected. Notifying Dart.');
      notifyDart({ 
        type: EVENT_TYPE_LOGIN_REQUIRED,
        location: 'sendPrompt',
        payload: 'User needs to sign in to Google Account'
      });
      // On retourne une promesse qui ne se résout jamais pour stopper le workflow
      return new Promise(() => {});
    }
    
    // 1. Trouver et remplir la zone de texte
    const inputArea = await waitForElement(PROMPT_INPUT_SELECTORS);
    // console.log('[AI Studio] Found input area:', (inputArea as HTMLElement).tagName);
    if (inputArea instanceof HTMLTextAreaElement || inputArea instanceof HTMLInputElement) {
      inputArea.value = prompt;
      inputArea.dispatchEvent(new Event('input', { bubbles: true }));
      inputArea.dispatchEvent(new Event('change', { bubbles: true }));
    } else {
      throw new Error("Input area is not a valid textarea or input element.");
    }
    
    // 2. NOUVELLE LOGIQUE : Attendre que le compteur de tokens se mette à jour
    // TIMING: Attente avec timeout pour éviter de bloquer indéfiniment si le compteur ne se met pas à jour
    await new Promise<void>((resolve, reject) => {
      const timeout = 5000; // 5 secondes max
      const startTime = Date.now();
      
      const checkTokenCount = () => {
        const elapsed = Date.now() - startTime;
        if (elapsed > timeout) {
          console.warn('[AI Studio] Token count timeout - proceeding anyway');
          resolve(); // On continue même si le compteur ne s'est pas mis à jour
          return;
        }
        
        const tokenCountElement = document.querySelector(TOKEN_COUNT_SELECTOR);
        const text = tokenCountElement?.textContent?.trim();
        // On attend que le texte existe et ne soit pas "0"
        if (text && !text.startsWith('0')) {
          // console.log('[AI Studio] Token count updated:', text);
          resolve();
        } else {
          setTimeout(checkTokenCount, 100);
        }
      };
      checkTokenCount();
    });
    // 3. Trouver et cliquer sur le bouton d'envoi
    const sendButton = await waitForElement(SEND_BUTTON_SELECTORS) as HTMLElement;
    // console.log('[AI Studio] Found send button, clicking it.');
    sendButton.click();
  },
  // --- NOUVEAU : Extraction alignée sur le flux validé (clic "Edit" → textarea.value) ---
  extractResponse: async (): Promise<string> => {
    console.log('[AI Studio] Starting extraction process...');
    
    // Fonction d'attente améliorée avec des logs de débogage
    // Nouvelle stratégie : partir du bouton "Edit" pour remonter au conteneur parent
    // Cela évite les problèmes avec querySelectorAll sur ms-chat-turn[data-turn-role="Model"]
    const waitForFinalizedTurn = (timeout = 15000): Promise<HTMLElement> => {
      return new Promise((resolve, reject) => {
        const intervalTime = 1000; // Augmenter l'intervalle pour être moins agressif
        let elapsedTime = 0;
        let checks = 0;

        const interval = setInterval(() => {
          checks++;
          
          // --- NOUVELLE STRATÉGIE : PARTIR DU BOUTON "EDIT" ---
          // 1. Trouver tous les boutons "Edit" sur la page. C'est un sélecteur simple et fiable.
          const allEditButtons = document.querySelectorAll('button[aria-label="Edit"]');
          
          // console.log(`[AI Studio] Check #${checks}: Found ${allEditButtons.length} 'Edit' button(s).`);

          if (allEditButtons.length > 0) {
            // 2. Prendre le dernier bouton "Edit" trouvé.
            const lastEditButton = allEditButtons[allEditButtons.length - 1] as HTMLElement;
            
            // 3. Remonter au conteneur `ms-chat-turn` parent.
            const parentTurn = lastEditButton.closest('ms-chat-turn');
            
            if (parentTurn) {
              const lastElement = parentTurn as HTMLElement;
              // Vérifier si l'élément est visible et non déjà en mode édition
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
            // Lancer l'inspection DOM automatique en cas d'échec pour aider au débogage
            console.error('[AI Studio] Timeout reached. Automatically running DOM inspection...');
            try {
              (window as any).inspectDOMForSelectors(); // Assurez-vous que cette fonction est globale
            } catch(e) {
              console.error('[AI Studio] Failed to run inspectDOMForSelectors.', e);
            }
            reject(new Error(`Extraction timed out: No 'Edit' button found on any model response within ${timeout}ms.`));
          }
        }, intervalTime);
      });
    };

    const lastTurn = await waitForFinalizedTurn();
    
    // --- AJOUTER CE LOG POUR LE DÉBOGAGE ---
    console.log('[AI Studio] Target turn element for extraction (outerHTML):', lastTurn.outerHTML);
    // -----------------------------------------
    
    // Le reste de la logique est correct
    const editButton = await waitForElementWithin(lastTurn, ['button[aria-label="Edit"]'], 2000) as HTMLElement;
    if (!editButton) {
      throw new Error("Could not find the 'Edit' button within the last assistant turn.");
    }
    editButton.click();
    console.log('[AI Studio] Clicked "Edit" button.');

    const textarea = await waitForElementWithin(lastTurn, ['textarea'], 5000) as HTMLTextAreaElement;
    
    // --- AJOUT D'UN DÉLAI N°1 ---
    // TIMING: Laisse le temps au framework de stabiliser l'UI après l'apparition du textarea.
    // Ce délai permet au framework d'achever les micro-tâches (écouteurs d'événements, remplissage de la valeur).
    await new Promise(resolve => setTimeout(resolve, 300));
    
    // --- MODIFICATION CLÉ : CAPTURER LA VALEUR IMMÉDIATEMENT ---
    const extractedContent = (textarea.value || '').trim();
    // On passe le contenu en tant que second argument pour éviter la troncature.
    console.log(`[AI Studio] Extracted ${extractedContent.length} chars successfully:`, extractedContent);

    // Si le contenu est vide à ce stade, c'est une vraie erreur.
    if (!extractedContent) {
        throw new Error('Textarea was found but it was empty.');
    }

    // --- BLINDAGE DES OPÉRATIONS DE NETTOYAGE ---
    // Les étapes suivantes sont pour l'UX, mais ne doivent pas faire échouer l'extraction.
    try {
      const stopEditingButton = await waitForElementWithin(lastTurn, ['button[aria-label="Stop editing"]'], 2000) as HTMLElement;
      if (stopEditingButton) {
        // --- AJOUT D'UN DÉLAI N°2 ---
        // TIMING: Laisse du temps avant de quitter le mode édition.
        // Ce délai permet aux appels de télémétrie de Google de se terminer sans être interrompus
        // par notre clic sur "Stop editing", évitant ainsi les erreurs TextDecoder.
        await new Promise(resolve => setTimeout(resolve, 300)); // 100ms
        
        stopEditingButton.click();
        console.log('[AI Studio] Exited edit mode.');
      }
    } catch (e) {
      // On ignore volontairement cette erreur. L'important est d'avoir le texte.
      console.warn('[AI Studio] Could not exit edit mode, but extraction was successful. This is non-critical.');
    }
    
    // On retourne la valeur capturée quoi qu'il arrive.
    return extractedContent;
  },
  // --- SUPPRIMÉ ---
  // Toute l'implémentation de `waitForResponse` avec le MutationObserver est supprimée.
};

