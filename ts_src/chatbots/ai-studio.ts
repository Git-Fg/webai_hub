// ts_src/chatbots/ai-studio.ts

// --- MODIFIÉ : Fichier entièrement mis à jour avec la logique de webuiselector.md ---

import { Chatbot } from '../types/chatbot';
import { notifyDart } from '../utils/notify-dart';
import { waitForElement } from '../utils/wait-for-element';
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
    console.log('[AI Studio] Found input area:', (inputArea as HTMLElement).tagName);
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
          console.log('[AI Studio] Token count updated:', text);
          resolve();
        } else {
          setTimeout(checkTokenCount, 100);
        }
      };
      checkTokenCount();
    });
    // 3. Trouver et cliquer sur le bouton d'envoi
    const sendButton = await waitForElement(SEND_BUTTON_SELECTORS) as HTMLElement;
    console.log('[AI Studio] Found send button, clicking it.');
    sendButton.click();
  },
  // --- NOUVEAU : Extraction par simulation de clics (menu kebab → Copier en Markdown) ---
  // Avec fallback DOM direct si le clipboard échoue
  extractResponse: async (): Promise<string> => {
    console.log('[AI Studio] Starting extraction...');

    // 1. Trouver le dernier message de l'IA
    // Stratégie améliorée : chercher tous les turns et prendre le dernier
    const findLastModelTurn = (): HTMLElement | null => {
      console.log('[AI Studio] Searching for last model turn...');
      
      // Stratégie 1: Chercher avec data-turn-role="Model" (case-sensitive)
      let turnsWithDataRole = document.querySelectorAll('ms-chat-turn[data-turn-role="Model"]');
      if (turnsWithDataRole.length > 0) {
        console.log(`[AI Studio] Found ${turnsWithDataRole.length} turns with data-turn-role="Model"`);
        return turnsWithDataRole[turnsWithDataRole.length - 1] as HTMLElement;
      }
      
      // Stratégie 2: Chercher avec data-turn-role="model" (lowercase)
      turnsWithDataRole = document.querySelectorAll('ms-chat-turn[data-turn-role="model"]');
      if (turnsWithDataRole.length > 0) {
        console.log(`[AI Studio] Found ${turnsWithDataRole.length} turns with data-turn-role="model"`);
        return turnsWithDataRole[turnsWithDataRole.length - 1] as HTMLElement;
      }
      
      // Stratégie 3: Chercher avec role="model"
      const turnsWithRole = document.querySelectorAll('ms-chat-turn[role="model"]');
      if (turnsWithRole.length > 0) {
        console.log(`[AI Studio] Found ${turnsWithRole.length} turns with role="model"`);
        return turnsWithRole[turnsWithRole.length - 1] as HTMLElement;
      }
      
      // Stratégie 4: Chercher tous les ms-chat-turn et vérifier les attributs
      const allTurns = document.querySelectorAll('ms-chat-turn');
      console.log(`[AI Studio] Found ${allTurns.length} total ms-chat-turn elements`);
      
      for (let i = allTurns.length - 1; i >= 0; i--) {
        const turn = allTurns[i] as HTMLElement;
        const dataRole = turn.getAttribute('data-turn-role');
        const role = turn.getAttribute('role');
        
        // Log pour debugging
        if (i === allTurns.length - 1) {
          console.log(`[AI Studio] Last turn attributes - data-turn-role: "${dataRole}", role: "${role}"`);
        }
        
        if (dataRole === 'Model' || dataRole === 'model' || role === 'model' || role === 'Model') {
          console.log(`[AI Studio] Found model turn at index ${i}`);
          return turn;
        }
      }
      
      // Stratégie 5: Si aucun turn avec role n'est trouvé, chercher par contenu (texte "Model" ou "Assistant")
      for (let i = allTurns.length - 1; i >= 0; i--) {
        const turn = allTurns[i] as HTMLElement;
        const text = turn.textContent || '';
        const innerText = turn.innerText || '';
        
        // Vérifier si c'est un message du modèle (pas de l'utilisateur)
        // Les messages du modèle ne contiennent généralement pas "User:" en début
        // et peuvent contenir beaucoup de texte
        if (text.length > 50 && !text.toLowerCase().includes('user:')) {
          // Vérifier aussi si ce n'est pas un message utilisateur
          const hasUserLabel = turn.querySelector('[class*="user"]') || 
                               turn.querySelector('[class*="User"]') ||
                               turn.querySelector('div[class*="author"]')?.textContent?.toLowerCase().includes('user');
          
          if (!hasUserLabel) {
            console.log(`[AI Studio] Found potential model turn at index ${i} by content analysis`);
            return turn;
          }
        }
      }
      
      console.warn('[AI Studio] Could not find any model turn');
      return null;
    };

    // Attendre que l'élément soit disponible avec un timeout
    const lastTurn = await new Promise<HTMLElement>((resolve, reject) => {
      const timeout = 10000;
      const startTime = Date.now();
      const checkInterval = 300;
      
      const checkForElement = () => {
        const turn = findLastModelTurn();
        if (turn) {
          console.log('[AI Studio] Found last model response turn.');
          resolve(turn);
          return;
        }
        
        const elapsed = Date.now() - startTime;
        if (elapsed >= timeout) {
          reject(new Error('Could not find the last model response turn within timeout.'));
          return;
        }
        
        setTimeout(checkForElement, checkInterval);
      };
      
      checkForElement();
    });

    if (!lastTurn) {
      throw new Error('Could not find the last model response turn.');
    }

    // Essayer d'abord l'extraction DOM directe (plus fiable)
    // Stratégie 1: Chercher ms-cmark-node
    let extractedText = '';
    const cmark = lastTurn.querySelector('ms-cmark-node') as HTMLElement | null;
    if (cmark && (cmark.innerText || cmark.textContent)) {
      extractedText = (cmark.innerText || cmark.textContent || '').trim();
    }
    
    // Stratégie 2: Si ms-cmark-node est vide, chercher tous les éléments de texte dans le turn
    if (!extractedText || extractedText.length < 10) {
      // Nettoyer le turn en enlevant les éléments UI
      const clone = lastTurn.cloneNode(true) as HTMLElement;
      clone.querySelector('.turn-footer')?.remove();
      clone.querySelector('.author-label')?.remove();
      clone.querySelector('ms-thought-chunk')?.remove();
      clone.querySelectorAll('button, nav, [role="button"]').forEach(el => el.remove());
      
      extractedText = (clone.innerText || clone.textContent || '').trim();
      extractedText = extractedText.replace(/\n{3,}/g, '\n\n');
    }
    
    if (extractedText && extractedText.length > 0) {
      console.log(`[AI Studio] Direct DOM extraction successful: ${extractedText.length} chars`);
      return extractedText;
    }

    // Si l'extraction DOM directe échoue, essayer le clipboard avec simulation de clics
    console.log('[AI Studio] Direct DOM extraction failed, trying clipboard method...');
    
    // Trouver le conteneur parent depuis le turn
    const lastTurnContainer = lastTurn.querySelector('.chat-turn-container') as HTMLElement;
    
    if (!lastTurnContainer) {
      // Dernier fallback: extraire depuis le turn entier
      const fallbackText = (lastTurn.innerText || lastTurn.textContent || '').trim();
      if (fallbackText && fallbackText.length > 0) {
        console.log(`[AI Studio] Final fallback extraction successful: ${fallbackText.length} chars`);
        return fallbackText;
      }
      throw new Error('Could not find the last model response container and all fallbacks failed.');
    }
    console.log('[AI Studio] Found last model response container.');

    // 2. Trouver et cliquer sur le bouton d'options (menu kebab)
    const optionsButton = lastTurnContainer.querySelector(
      'ms-chat-turn-options > div > button'
    ) as HTMLElement;
    
    if (!optionsButton) {
      throw new Error('Could not find the options button in the chat turn.');
    }
    console.log('[AI Studio] Found options button, clicking it.');
    optionsButton.click();

    // TIMING: Attendre que le menu apparaisse après le clic sur le bouton d'options
    // Le menu est ajouté au DOM de manière asynchrone
    await new Promise(resolve => setTimeout(resolve, 300));

    // 3. Attendre que le menu apparaisse et cliquer sur le bouton "Copier en Markdown"
    // Le menu est ajouté au body, donc on le cherche globalement.
    let copyButton: HTMLElement | null = null;
    
    // Stratégie 1: Chercher parmi tous les boutons de menu Material
    const menuButtons = Array.from(document.querySelectorAll('button.mat-mdc-menu-item'));
    copyButton = menuButtons.find((button) => {
      const text = button.textContent?.toLowerCase() || '';
      const ariaLabel = button.getAttribute('aria-label')?.toLowerCase() || '';
      return text.includes('copy') || text.includes('markdown') || 
             ariaLabel.includes('copy') || ariaLabel.includes('markdown');
    }) as HTMLElement | null;

    // Stratégie 2: Chercher par l'icône Material avec data-mat-icon-name
    if (!copyButton) {
      try {
        const iconButtons = Array.from(document.querySelectorAll('mat-icon[data-mat-icon-name]'));
        const markdownIcon = iconButtons.find(icon => 
          icon.getAttribute('data-mat-icon-name')?.includes('markdown') ||
          icon.getAttribute('data-mat-icon-name')?.includes('copy')
        );
        if (markdownIcon) {
          copyButton = markdownIcon.closest('button') as HTMLElement | null;
        }
      } catch (e) {
        console.log('[AI Studio] Icon-based search failed:', e);
      }
    }

    // Stratégie 3: Chercher parmi tous les boutons celui qui contient 'markdown_copy' dans son texte
    if (!copyButton) {
      const allButtons = Array.from(document.querySelectorAll('button'));
      copyButton = allButtons.find((button) => {
        const text = button.textContent || '';
        const ariaLabel = button.getAttribute('aria-label') || '';
        return text.includes('markdown_copy') || ariaLabel.includes('markdown_copy');
      }) as HTMLElement | null;
    }

    if (!copyButton) {
      // Fallback: essayer d'extraire directement depuis le DOM
      console.warn('[AI Studio] Could not find copy button, falling back to DOM extraction');
      const cmark = lastTurnContainer.querySelector('ms-cmark-node') as HTMLElement | null;
      if (cmark && (cmark.innerText || cmark.textContent)) {
        const text = (cmark.innerText || cmark.textContent || '').trim();
        if (text && text.length > 0) {
          console.log(`[AI Studio] Fallback extraction successful: ${text.length} chars`);
          return text;
        }
      }
      throw new Error('Could not find the "Copy as Markdown" button in the menu and fallback extraction failed.');
    }
    console.log('[AI Studio] Found copy button, clicking it.');
    copyButton.click();

    // 4. Attendre que le clipboard se mette à jour
    // TIMING: Attente de 500ms pour permettre au clipboard de se mettre à jour après le clic.
    // Aucune callback JS n'est disponible pour cet événement.
    await new Promise(resolve => setTimeout(resolve, 500));

    // 5. Lire le contenu du presse-papiers et le retourner
    // C'est la méthode moderne et sécurisée pour lire le clipboard en JS
    try {
      const clipboardText = await navigator.clipboard.readText();
      if (!clipboardText || clipboardText.trim().length === 0) {
        throw new Error('Clipboard content is empty.');
      }
      console.log(`[AI Studio] Successfully extracted ${clipboardText.length} chars from clipboard.`);
      return clipboardText.trim();
    } catch (err) {
      console.warn('[AI Studio] Failed to read from clipboard, falling back to DOM extraction:', err);
      
      // Fallback: extraction DOM directe
      const cmark = lastTurnContainer.querySelector('ms-cmark-node') as HTMLElement | null;
      if (cmark && (cmark.innerText || cmark.textContent)) {
        const text = (cmark.innerText || cmark.textContent || '').trim();
        if (text && text.length > 0) {
          console.log(`[AI Studio] Fallback DOM extraction successful: ${text.length} chars`);
          return text;
        }
      }
      
      // Dernier essai: extraire depuis le turn entier
      const fallbackText = (lastTurn.innerText || lastTurn.textContent || '').trim();
      if (fallbackText && fallbackText.length > 0) {
        console.log(`[AI Studio] Final fallback extraction successful: ${fallbackText.length} chars`);
        return fallbackText;
      }
      
      throw new Error(`Could not read from clipboard: ${err instanceof Error ? err.message : String(err)} and all fallbacks failed.`);
    }
  },
  // --- SUPPRIMÉ ---
  // Toute l'implémentation de `waitForResponse` avec le MutationObserver est supprimée.
};

