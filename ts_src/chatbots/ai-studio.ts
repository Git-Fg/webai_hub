// ts_src/chatbots/ai-studio.ts

import { Chatbot, AutomationOptions } from '../types/chatbot';
import { notifyDart } from '../utils/notify-dart';
import { waitForElement, waitForElementWithin, waitForElementByText } from '../utils/wait-for-element';
import { waitForActionableElement } from '../utils/wait-for-actionable-element';
import { assertIsElement } from '../utils/assertions';
import { getModifiedTimeout } from '../utils/timeout';
import { 
  EVENT_TYPE_LOGIN_REQUIRED
} from '../utils/bridge-constants';

// Import default timeout for consistency
const DEFAULT_TIMEOUT_MS = 10000;

// --- Constants for Timing and Timeouts ---
const TIMING = {
  READINESS_CHECK_INTERVAL_MS: 100,
  TOKEN_COUNT_UPDATE_TIMEOUT_MS: 10000, 
  TOKEN_COUNT_CHECK_INTERVAL_MS: 100,
  UI_STABILIZE_AFTER_TOKEN_COUNT_MS: 30, 
  FINALIZED_TURN_TIMEOUT_MS: 15000,
  FINALIZED_TURN_CHECK_INTERVAL_MS: 1000,
  EDIT_BUTTON_WAIT_TIMEOUT_MS: 2000,
  TEXTAREA_APPEAR_TIMEOUT_MS: 5000,
  UI_STABILIZE_DELAY_MS: 150,
  PANEL_ANIMATION_MS: 250,
  POLL_INTERVAL_MS: 100,
  POLL_TIMEOUT_MS: 5000,
  UI_STATE_DEBOUNCE_DELAY_MS: 250,
} as const;

// --- Selectors (enhanced fallbacks) ---
const SELECTORS = {
    NEW_CHAT_BUTTON: 'a[href="/prompts/new_chat"]',
    RUN_SETTINGS_TOGGLE_MOBILE: 'button.runsettings-toggle-button',
    MODEL_SELECTOR_DESKTOP: 'button.model-selector-card',
    PROMPT_INPUTS: [
        'ms-chunk-input textarea',
        "textarea[placeholder*='Start typing a prompt']",
        "textarea[aria-label*='Start typing a prompt']",
    ],
    // WHY: Add semantic type and aria-label fallbacks for robustness
    SEND_BUTTONS: [
        'ms-run-button > button[aria-label="Run"]',
        'ms-run-button > button[type="submit"]',
        'button[aria-label="Run"]',
        'ms-run-button > button',
    ],
    TOKEN_COUNT: 'span.v3-token-count-value',
    // WHY: Primary by aria-label, fallback by icon text (best-effort)
    EDIT_BUTTON: [
        'button[aria-label="Edit"]',
        'button[aria-label*="edit" i]',
        'button:has([aria-label*="edit" i])',
    ],
    EDIT_TEXTAREA: [
        'textarea',
        'div[contenteditable="true"]',
        '[contenteditable="true"]',
    ],
    STOP_EDITING_BUTTON: 'button[aria-label="Stop editing"]',
    // WHY: Prefer structural id prefix, fallback to custom element
    CHAT_TURN: [
        '[id^="turn-"]',
        'ms-chat-turn',
    ],
    // WHY: Prefer aria-label on mobile toggle, fallback to class name
    SETTINGS_PANEL_MOBILE_TOGGLE: [
        'button[aria-label="Toggle run settings panel"]',
        'button.runsettings-toggle-button',
    ],
    SETTINGS_PANEL_CLOSE_BUTTON: 'ms-run-settings button[iconname="close"]',
    MODEL_SELECTOR_CARD: 'button.model-selector-card',
    MODEL_CATEGORIES_ALL_BUTTON: 'button[data-test-category-button]',
    MODEL_CAROUSEL_BUTTON: 'ms-model-carousel-row button.content-button',
    MODEL_TITLE_TEXT: 'span.model-title-text',
    SYSTEM_PROMPT_CARD: 'button[data-test-system-instructions-card]',
    SYSTEM_PROMPT_TEXTAREA: 'ms-system-instructions textarea',
    DIALOG_CLOSE_BUTTON: 'mat-dialog-container button[data-test-close-button]',
    MODEL_DIALOG_CONTAINER: 'mat-dialog-container',
    ADVANCED_SETTINGS_TOGGLE: 'div.settings-item',
    THINKING_TOGGLE: 'mat-slide-toggle[data-test-toggle="enable-thinking"] button',
    MANUAL_BUDGET_TOGGLE: 'mat-slide-toggle[data-test-toggle="manual-budget"] button',
    BUDGET_INPUT: 'div[data-test-id="user-setting-budget-animation-wrapper"] input',
    TOOLS_TOGGLE_SELECTOR: 'div.settings-item',
    WEB_SEARCH_TOGGLE: 'div[data-test-id="searchAsAToolTooltip"] button',
    URL_CONTEXT_TOGGLE: 'div[data-test-id="browseAsAToolTooltip"] button',
};

const CONFIG = {
  SCREEN_WIDTH_BREAKPOINT_PX: 960,
  LOG_PREVIEW_LENGTH: 50,
} as const;

// Helper interface for SettingsManager to access chatbot methods
interface ChatbotHelpers {
  retryOperation<T>(
    operation: () => Promise<T>,
    operationName: string,
    maxRetries?: number,
    delayMs?: number
  ): Promise<T>;
  createErrorWithContext(
    operation: string,
    message: string,
    additionalContext?: string
  ): Error;
}

class SettingsManager {
  constructor(private chatbot: ChatbotHelpers) {}

  // Move _setModel, _setTemperature, _setTopP, etc. here
  // Make them public within this class

  async setModel(modelId: string): Promise<void> {
    console.log(`[AI Studio Settings] Setting model to: "${modelId}"`);
    return this.chatbot.retryOperation(async () => {
      const modelSelectorEl = await waitForActionableElement<HTMLButtonElement>([SELECTORS.MODEL_SELECTOR_CARD], 'Model selector card', getModifiedTimeout(DEFAULT_TIMEOUT_MS), 2);
      const modelSelector = assertIsElement(modelSelectorEl, HTMLButtonElement, 'Model selector card');
      const currentModelNameEl = modelSelector.querySelector('span.title');
      if (currentModelNameEl && currentModelNameEl.textContent?.trim() === modelId) {
        console.log(`[AI Studio LOG] Model "${modelId}" is already selected. Skipping.`);
        return;
      }
      modelSelector.click();
      // WHY: Dynamically wait for model selection dialog to appear instead of using a fixed delay.
      await waitForElement([SELECTORS.MODEL_DIALOG_CONTAINER], getModifiedTimeout(3000));

      // WHY: Try to find element, and if occluded, wait a bit more and try clicking anyway
      let allFilterEl: HTMLButtonElement | null = null;
      try {
        allFilterEl = await waitForActionableElement<HTMLButtonElement>([SELECTORS.MODEL_CATEGORIES_ALL_BUTTON], 'Model categories all button', getModifiedTimeout(DEFAULT_TIMEOUT_MS), 2);
      } catch (error) {
        // If actionability check fails due to occlusion, try finding element anyway and clicking it
        const errorMsg = error instanceof Error ? error.message : String(error);
        if (errorMsg.includes('occluded')) {
          console.log('[AI Studio LOG] Element found but occluded. Waiting longer and attempting click anyway...');
          await new Promise(resolve => setTimeout(resolve, TIMING.PANEL_ANIMATION_MS));
          const foundElement = document.querySelector(SELECTORS.MODEL_CATEGORIES_ALL_BUTTON) as HTMLButtonElement;
          if (foundElement && foundElement.offsetParent !== null) {
            allFilterEl = foundElement;
            console.log('[AI Studio LOG] Found element despite occlusion, will attempt click.');
          } else {
            throw error;
          }
        } else {
          throw error;
        }
      }
      const allFilter = assertIsElement(allFilterEl, HTMLButtonElement, 'Model categories all button');
      // WHY: Scroll element into view before clicking to help with occlusion issues
      allFilter.scrollIntoView({ behavior: 'smooth', block: 'center' });
      await new Promise(resolve => setTimeout(resolve, TIMING.UI_STABILIZE_DELAY_MS));
      allFilter.click();
      await new Promise(resolve => setTimeout(resolve, TIMING.UI_STABILIZE_DELAY_MS));

      const modelOptions = Array.from(document.querySelectorAll(SELECTORS.MODEL_CAROUSEL_BUTTON));
      const modelButton = modelOptions.find(option => {
        const buttonText = option.textContent?.trim() || '';
        const spanText = option.querySelector(SELECTORS.MODEL_TITLE_TEXT)?.textContent?.trim() || '';
        return spanText === modelId || buttonText.startsWith(modelId);
      }) as HTMLElement | undefined;

      if (modelButton) {
        // WHY: Element already found via querySelector - verify basic visibility before clicking
        // Full actionability check not needed here since we're targeting a specific found element
        if (modelButton.offsetParent === null) {
          throw this.chatbot.createErrorWithContext('setModel', `Model button for "${modelId}" is not visible`);
        }
        modelButton.click();
        console.log(`[AI Studio LOG] Success: Clicked model button for "${modelId}".`);
        // WHY: Wait for dialog to close (it may close automatically after model selection)
        await new Promise(resolve => setTimeout(resolve, TIMING.PANEL_ANIMATION_MS));
      } else {
        const availableModels = modelOptions.map(opt => {
          const span = opt.querySelector(SELECTORS.MODEL_TITLE_TEXT);
          return span?.textContent?.trim() || opt.textContent?.trim() || 'unknown';
        }).join(', ');
        throw this.chatbot.createErrorWithContext('setModel', `Model button for "${modelId}" not found.`, `AvailableModels=[${availableModels}]`);
      }

      // WHY: Check if dialog is still open before trying to close it (some dialogs close automatically)
      if (document.querySelector('mat-dialog-container')) {
        try {
          const closeButtonEl = await waitForActionableElement<HTMLButtonElement>([SELECTORS.DIALOG_CLOSE_BUTTON], 'Dialog close button', getModifiedTimeout(2000), 0);
          const closeButton = assertIsElement(closeButtonEl, HTMLButtonElement, 'Dialog close button');
          closeButton.click();
          await new Promise(resolve => setTimeout(resolve, TIMING.PANEL_ANIMATION_MS));
        } catch {
          console.log('[AI Studio LOG] Model dialog seems to have closed automatically.');
        }
      }
    }, 'setModel', 2, 300);
  }

  async setTemperature(temperature: number): Promise<void> {
    console.log(`[AI Studio LOG] Setting Temperature to: ${temperature}`);
    // Direct implementation instead of calling setSliderValueByLabel
    try {
      const labelElement = await waitForElementByText('h3', 'Temperature') as HTMLElement;
      if (!labelElement) {
        throw new Error(`Could not find 'Temperature' label in settings panel.`);
      }
      const container = labelElement.closest('.settings-item-column');
      if (!container) {
        throw new Error(`Could not find parent container for 'Temperature' label.`);
      }
      const inputElement = container.querySelector('input[type=number]') as HTMLInputElement;
      if (!inputElement) {
        throw new Error(`Found 'Temperature' label but could not find its input field.`);
      }
      // WHY: Verify input is actionable before setting value (visible and enabled)
      if (inputElement.offsetParent === null || inputElement.disabled) {
        throw new Error(`Input field for 'Temperature' is not actionable (visible: ${inputElement.offsetParent !== null}, disabled: ${inputElement.disabled})`);
      }
      inputElement.value = temperature.toString();
      inputElement.dispatchEvent(new Event('change', { bubbles: true }));
      console.log(`[AI Studio LOG] Set Temperature to ${temperature} successfully.`);
    } catch (error) {
      throw new Error(`Failed to set Temperature: ${error instanceof Error ? error.message : String(error)}. LabelName=Temperature, Value=${temperature}`);
    }
  }

  async setTopP(topP: number): Promise<void> {
    console.log(`[AI Studio LOG] Setting Top-P to: ${topP}`);
    const advancedToggle = await waitForElementByText('p', 'Advanced settings') as HTMLElement;
    const advancedToggleContainer = advancedToggle.closest(SELECTORS.ADVANCED_SETTINGS_TOGGLE);
    if (advancedToggleContainer && !advancedToggleContainer.classList.contains('expanded')) {
      (advancedToggleContainer as HTMLElement).click();
      await new Promise(resolve => setTimeout(resolve, TIMING.PANEL_ANIMATION_MS));
    }
    // Direct implementation instead of calling setSliderValueByLabel
    try {
      const labelElement = await waitForElementByText('h3', 'Top P') as HTMLElement;
      if (!labelElement) {
        throw new Error(`Could not find 'Top P' label in settings panel.`);
      }
      const container = labelElement.closest('.settings-item-column');
      if (!container) {
        throw new Error(`Could not find parent container for 'Top P' label.`);
      }
      const inputElement = container.querySelector('input[type=number]') as HTMLInputElement;
      if (!inputElement) {
        throw new Error(`Found 'Top P' label but could not find its input field.`);
      }
      // WHY: Verify input is actionable before setting value (visible and enabled)
      if (inputElement.offsetParent === null || inputElement.disabled) {
        throw new Error(`Input field for 'Top P' is not actionable (visible: ${inputElement.offsetParent !== null}, disabled: ${inputElement.disabled})`);
      }
      inputElement.value = topP.toString();
      inputElement.dispatchEvent(new Event('change', { bubbles: true }));
      console.log(`[AI Studio LOG] Set Top P to ${topP} successfully.`);
    } catch (error) {
      throw new Error(`Failed to set Top P: ${error instanceof Error ? error.message : String(error)}. LabelName=Top P, Value=${topP}`);
    }
  }

  async setThinkingBudget(budget?: number): Promise<void> {
    console.log(`[AI Studio LOG] Configuring thinking budget. Provided value: ${budget}`);
    const thinkingToggleEl = await waitForElement<HTMLButtonElement>([SELECTORS.THINKING_TOGGLE]);
    const thinkingToggle = assertIsElement(thinkingToggleEl, HTMLButtonElement, 'Thinking toggle');
    const isThinkingEnabled = thinkingToggle.getAttribute('aria-checked') === 'true';
    if (budget != null && !isThinkingEnabled) {
      thinkingToggle.click();
      console.log('[AI Studio LOG] Enabled "thinking" feature.');
      await new Promise(resolve => setTimeout(resolve, TIMING.PANEL_ANIMATION_MS));
    }
    const manualBudgetToggleEl = await waitForElement<HTMLButtonElement>([SELECTORS.MANUAL_BUDGET_TOGGLE]);
    const manualBudgetToggle = assertIsElement(manualBudgetToggleEl, HTMLButtonElement, 'Manual budget toggle');
    const isManualEnabled = manualBudgetToggle.getAttribute('aria-checked') === 'true';
    if (budget != null) {
      if (!isManualEnabled) {
        manualBudgetToggle.click();
        console.log('[AI Studio LOG] Enabled "manual budget".');
        await new Promise(resolve => setTimeout(resolve, TIMING.PANEL_ANIMATION_MS));
      }
      const budgetInputEl = await waitForElement<HTMLInputElement>([SELECTORS.BUDGET_INPUT]);
      const budgetInput = assertIsElement(budgetInputEl, HTMLInputElement, 'Budget input');
      budgetInput.value = budget.toString();
      budgetInput.dispatchEvent(new Event('input', { bubbles: true }));
      console.log(`[AI Studio LOG] Success: Set budget input to ${budget}.`);
    } else {
      if (isManualEnabled) {
        manualBudgetToggle.click();
        console.log('[AI Studio LOG] Success: Disabled "manual budget" as no value was provided.');
      }
    }
  }

  async setAdvancedOptions(options: { useWebSearch?: boolean; disableThinking?: boolean; urlContext?: boolean; }, modelId?: string): Promise<void> {
    console.log('[AI Studio LOG] Setting advanced options:', options);
    if (options.disableThinking !== undefined) {
      const lower = modelId?.toLowerCase();
      if (lower === 'gemini-2.5-pro') {
        console.log('[AI Studio LOG] Skipping "disableThinking" toggle as it is not applicable for gemini-2.5-pro.');
      } else {
        const el = await waitForElement<HTMLButtonElement>([SELECTORS.THINKING_TOGGLE]);
        const thinkingToggle = assertIsElement(el, HTMLButtonElement, 'Thinking toggle');
        const isThinkingEnabled = thinkingToggle.getAttribute('aria-checked') === 'true';
        const shouldBeEnabled = !options.disableThinking;
        if (shouldBeEnabled !== isThinkingEnabled) {
          thinkingToggle.click();
          console.log(`[AI Studio LOG] Toggled thinking to: ${shouldBeEnabled ? 'enabled' : 'disabled'}`);
        }
      }
    }
    if (options.useWebSearch !== undefined || options.urlContext !== undefined) {
      const toolsToggle = await waitForElementByText('p', 'Tools') as HTMLElement;
      const toolsToggleContainer = toolsToggle.closest(SELECTORS.TOOLS_TOGGLE_SELECTOR);
      if (toolsToggleContainer && !toolsToggleContainer.classList.contains('expanded')) {
        (toolsToggleContainer as HTMLElement).click();
        await new Promise(resolve => setTimeout(resolve, TIMING.PANEL_ANIMATION_MS));
      }
      if (options.useWebSearch !== undefined) {
        const webSearchEl = await waitForElement<HTMLButtonElement>([SELECTORS.WEB_SEARCH_TOGGLE]);
        const webSearchToggle = assertIsElement(webSearchEl, HTMLButtonElement, 'Web search toggle');
        if (options.useWebSearch !== (webSearchToggle.getAttribute('aria-checked') === 'true')) {
          webSearchToggle.click();
          console.log(`[AI Studio LOG] Toggled web search to: ${options.useWebSearch}`);
        }
      }
      if (options.urlContext !== undefined) {
        const urlContextEl = await waitForElement<HTMLButtonElement>([SELECTORS.URL_CONTEXT_TOGGLE]);
        const urlContextToggle = assertIsElement(urlContextEl, HTMLButtonElement, 'URL context toggle');
        if (options.urlContext !== (urlContextToggle.getAttribute('aria-checked') === 'true')) {
          urlContextToggle.click();
          console.log(`[AI Studio LOG] Toggled URL context to: ${options.urlContext}`);
        }
      }
    }
  }
}

export class AiStudioChatbot implements Chatbot {
  private settingsManager: SettingsManager;

  constructor() {
    this.settingsManager = new SettingsManager(this);
  }

  // --- Private Helper Methods ---
  private getPageStateContext(): string {
    const visibleElements = document.querySelectorAll('*').length;
    return `URL=${window.location.href}, ReadyState=${document.readyState}, VisibleElements=${visibleElements}`;
  }

  // WHY: Public methods needed by SettingsManager for proper type safety
  createErrorWithContext(operation: string, message: string, additionalContext?: string): Error {
    const context = this.getPageStateContext();
    const fullContext = additionalContext ? `${context}, ${additionalContext}` : context;
    return new Error(`${operation} failed: ${message}\nContext: ${fullContext}`);
  }

  // WHY: Public method needed by SettingsManager for proper type safety
  async retryOperation<T>(
    operation: () => Promise<T>,
    operationName: string,
    maxRetries: number = 2,
    delayMs: number = 300
  ): Promise<T> {
    let lastError: Error | null = null;
    
    for (let attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await operation();
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error));
        
        if (attempt >= maxRetries) {
          throw this.createErrorWithContext(
            operationName,
            lastError.message,
            `Retries=${maxRetries}, Attempt=${attempt + 1}`
          );
        }
        
        const backoffDelay = delayMs * Math.pow(2, attempt);
        console.log(`[AI Studio LOG] ${operationName} failed, retrying ${attempt + 1}/${maxRetries} after ${backoffDelay}ms. Error: ${lastError.message.split('\n')[0]}`);
        await new Promise(resolve => setTimeout(resolve, backoffDelay));
      }
    }
    
    throw lastError || new Error(`${operationName} failed after ${maxRetries} retries`);
  }

  // --- Public Chatbot Interface Implementation ---

  async resetState(): Promise<void> {
    console.log('[AI Studio] Preparing to reset UI state...');
    try {
      // Step 1: Get a reference to CURRENT instance of settings button.
      const settingsToggleSelector = Array.isArray(SELECTORS.SETTINGS_PANEL_MOBILE_TOGGLE) 
        ? SELECTORS.SETTINGS_PANEL_MOBILE_TOGGLE[0] 
        : SELECTORS.SETTINGS_PANEL_MOBILE_TOGGLE;
      const oldSettingsButton = settingsToggleSelector ? document.querySelector(settingsToggleSelector) : null;

      const newChatButton = document.querySelector(SELECTORS.NEW_CHAT_BUTTON) as HTMLElement;
      if (!newChatButton || newChatButton.offsetParent === null) {
        console.warn('[AI Studio] "New Chat" button not found, assuming clean state and proceeding.');
        await this.waitForReady(); // Still ensure the current state is ready.
        return;
      }

      // Step 2: Trigger the UI reset.
      newChatButton.click();
      console.log('[AI Studio] "New Chat" clicked. Waiting for UI transition...');

      // Step 3: Wait for the OLD button instance to disappear.
      // This is the most reliable signal that the page is unloading.
      if (oldSettingsButton) {
        const timeout = getModifiedTimeout(5000);
        const startTime = Date.now();
        while (document.body.contains(oldSettingsButton)) {
          if (Date.now() - startTime > timeout) {
            throw this.createErrorWithContext(
              'resetState',
              'Old settings button did not disappear within timeout.',
              `Timeout=${timeout}ms`
            );
          }
          await new Promise(resolve => setTimeout(resolve, 50));
        }
        console.log('[AI Studio] Old UI elements have been removed.');
      }

      // Step 4: Now that the old state is gone, wait for the NEW state to be fully ready.
      await this.waitForReady();
      console.log('[AI Studio] State reset completed successfully.');

    } catch (error) {
      console.error('[AI Studio] A non-critical error occurred during state reset. Continuing under assumption that UI is ready.', error);
      // On failure, still attempt a waitForReady as a safety net.
      await this.waitForReady();
    }
  }

  async waitForReady(): Promise<void> {
    // WHY: The prompt input area is one of the last elements to become fully
    // interactive after a page load or reset. Waiting for it to be actionable
    // is a much more reliable signal that the entire UI is ready for automation
    // than waiting for the settings toggle button, which can appear prematurely.
    await waitForActionableElement<HTMLElement>(
      SELECTORS.PROMPT_INPUTS,
      'Prompt Input Area'
    );
    console.log('[AI Studio] UI is fully actionable and ready (prompt input is available).');
  }
  
  // WHY: setSystemPrompt remains a separate public method because it opens a different modal
  async setSystemPrompt(systemPrompt: string): Promise<void> {
    if (!systemPrompt) return;
    console.log('[AI Studio LOG] Setting system prompt.');
    await this.openSettingsPanel();
    try {
      const systemPromptButtonEl = await waitForElement<HTMLButtonElement>([SELECTORS.SYSTEM_PROMPT_CARD]);
      const systemPromptButton = assertIsElement(systemPromptButtonEl, HTMLButtonElement, 'System prompt card');
      systemPromptButton.click();
      await new Promise(resolve => setTimeout(resolve, TIMING.PANEL_ANIMATION_MS));

      const textareaEl = await waitForElement<HTMLTextAreaElement>([SELECTORS.SYSTEM_PROMPT_TEXTAREA]);
      const textarea = assertIsElement(textareaEl, HTMLTextAreaElement, 'System prompt textarea');
      textarea.value = systemPrompt;
      textarea.dispatchEvent(new Event('input', { bubbles: true }));
      console.log('[AI Studio LOG] Success: System prompt entered.');

      const closeButtonEl = await waitForElement<HTMLButtonElement>([SELECTORS.DIALOG_CLOSE_BUTTON]);
      const closeButton = assertIsElement(closeButtonEl, HTMLButtonElement, 'Dialog close button');
      closeButton.click();
      await new Promise(resolve => setTimeout(resolve, TIMING.PANEL_ANIMATION_MS));
    } finally {
      await this.closeSettingsPanel();
    }
  }

  // NEW unified method
  async applyAllSettings(options: AutomationOptions): Promise<void> {
    const anySetting = (
      options.model || options.temperature !== undefined || options.topP !== undefined ||
      options.thinkingBudget !== undefined || options.useWebSearch !== undefined ||
      options.disableThinking !== undefined || options.urlContext !== undefined
    );
    if (!anySetting) {
      console.log('[AI Studio LOG] No settings to apply. Skipping panel.');
      return;
    }
    await this.openSettingsPanel();
    try {
      if (options.model) {
        await this.settingsManager.setModel(options.model);
      }
      if (options.temperature !== undefined) {
        await this.settingsManager.setTemperature(options.temperature);
      }
      if (options.topP !== undefined) {
        await this.settingsManager.setTopP(options.topP);
      }
      if (options.thinkingBudget !== undefined) {
        await this.settingsManager.setThinkingBudget(options.thinkingBudget);
      }
      const advancedOptions = {
        useWebSearch: options.useWebSearch,
        disableThinking: options.disableThinking,
        urlContext: options.urlContext,
      };
      if (Object.values(advancedOptions).some(v => v !== undefined)) {
        await this.settingsManager.setAdvancedOptions(advancedOptions, options.model);
      }
    } finally {
      await this.closeSettingsPanel();
    }
  }

  private async _waitForResponseFinalization(): Promise<void> {
    console.log('[AI Studio] Now waiting for AI response to finalize...');
    
    return new Promise((resolve, reject) => {
      const timeout = getModifiedTimeout(TIMING.FINALIZED_TURN_TIMEOUT_MS);
      const EDIT_BUTTON_SELECTOR = Array.isArray(SELECTORS.EDIT_BUTTON) ? SELECTORS.EDIT_BUTTON.join(',') : SELECTORS.EDIT_BUTTON;
      const CHAT_TURN_SELECTOR = Array.isArray(SELECTORS.CHAT_TURN) ? SELECTORS.CHAT_TURN.join(',') : SELECTORS.CHAT_TURN;
      
      const observer = new MutationObserver(() => {
        const allTurns = document.querySelectorAll(CHAT_TURN_SELECTOR);
        if (allTurns.length === 0) return;

        const lastTurn = allTurns[allTurns.length - 1] as HTMLElement;
        const editButton = lastTurn.querySelector<HTMLButtonElement>(EDIT_BUTTON_SELECTOR);
        const isEditing = lastTurn.querySelector(SELECTORS.STOP_EDITING_BUTTON);

        if (editButton && !isEditing && editButton.offsetParent !== null && !editButton.disabled) {
          console.log('[AI Studio] Response finalized. Ready for extraction.');
          observer.disconnect();
          clearTimeout(timeoutId);
          resolve();
        }
      });

      observer.observe(document.body, { childList: true, subtree: true, attributes: true });

      const timeoutId = setTimeout(() => {
        observer.disconnect();
        reject(new Error(`Timed out after ${timeout}ms waiting for response to finalize.`));
      }, timeout);

      // Perform an initial check in case the element is already present and ready.
      const allTurns = document.querySelectorAll(CHAT_TURN_SELECTOR);
      if (allTurns.length > 0) {
        const lastTurn = allTurns[allTurns.length - 1] as HTMLElement;
        const editButton = lastTurn.querySelector<HTMLButtonElement>(EDIT_BUTTON_SELECTOR);
        const isEditing = lastTurn.querySelector(SELECTORS.STOP_EDITING_BUTTON);
        if (editButton && !isEditing && editButton.offsetParent !== null && !editButton.disabled) {
          observer.disconnect();
          clearTimeout(timeoutId);
          resolve();
        }
      }
    });
  }

  async sendPrompt(prompt: string): Promise<void> {
    console.log('[AI Studio LOG] Starting automation with prompt:', prompt.substring(0, CONFIG.LOG_PREVIEW_LENGTH));
    
    if (this.isLoginPage()) {
      console.log('[AI Studio LOG] Login page detected. Notifying Dart.');
      notifyDart({ 
        type: EVENT_TYPE_LOGIN_REQUIRED,
        location: 'sendPrompt',
        payload: 'User needs to sign in to Google Account'
      });
      return new Promise(() => {});
    }
    
    try {
      const inputAreaEl = await waitForActionableElement<HTMLTextAreaElement | HTMLInputElement>(SELECTORS.PROMPT_INPUTS, 'Prompt input area', getModifiedTimeout(DEFAULT_TIMEOUT_MS), 2);
      if (inputAreaEl instanceof HTMLTextAreaElement || inputAreaEl instanceof HTMLInputElement) {
        inputAreaEl.value = prompt;
        inputAreaEl.dispatchEvent(new Event('input', { bubbles: true }));
        inputAreaEl.dispatchEvent(new Event('change', { bubbles: true }));
        console.log('[AI Studio LOG] Prompt entered into input area, waiting for token count update...');
      } else {
        const elementType = inputAreaEl ? (inputAreaEl as HTMLElement).constructor.name : 'null';
        throw this.createErrorWithContext('sendPrompt', 'Input area is not a valid textarea or input element.', `ElementType=${elementType}`);
      }
      
      await new Promise<void>((resolve, reject) => {
        const timeout = getModifiedTimeout(TIMING.TOKEN_COUNT_UPDATE_TIMEOUT_MS);
        const startTime = Date.now();
        
        const checkTokenCount = () => {
          const elapsed = Date.now() - startTime;
          if (elapsed > timeout) {
            // Instead of resolving, we now reject with a clear error.
            reject(new Error(`Token count did not update within ${timeout}ms.`));
            return;
          }
          
          const tokenCountElement = document.querySelector(SELECTORS.TOKEN_COUNT);
          const text = tokenCountElement?.textContent?.trim();
          // The condition remains the same: wait for a non-zero token count.
          if (text && !text.startsWith('0')) {
            console.log(`[AI Studio LOG] Token count updated: ${text}`);
            resolve();
          } else {
            setTimeout(checkTokenCount, TIMING.TOKEN_COUNT_CHECK_INTERVAL_MS);
          }
        };
        checkTokenCount();
      });

      // WHY: Add a small delay after token count updates to allow the UI to stabilize
      // before attempting to click the send button, preventing potential race conditions.
      await new Promise(resolve => setTimeout(resolve, TIMING.UI_STABILIZE_AFTER_TOKEN_COUNT_MS));
      console.log('[AI Studio LOG] UI stabilized after token count, proceeding to send.');

      // WHY: This is the critical fix inspired by the original logic.
      // Ensure the settings panel is closed before attempting to click the send
      // button to prevent it from being occluded, especially on mobile views.
      await this.closeSettingsPanel();
      
      await this.retryOperation(async () => {
        const sendButtonEl = await waitForActionableElement<HTMLElement>(SELECTORS.SEND_BUTTONS, 'Send button', getModifiedTimeout(DEFAULT_TIMEOUT_MS), 2);
        const sendButton = assertIsElement(sendButtonEl, HTMLElement, 'Send button');
        sendButton.click();
        console.log('[AI Studio LOG] Send button clicked successfully.');
      }, 'sendPrompt (click send button)', 2, 300);

      // *** NEW LOGIC: Await finalization directly ***
      await this._waitForResponseFinalization();
    } catch (error) {
      throw this.createErrorWithContext('sendPrompt', `Failed to send prompt: ${error instanceof Error ? error.message : String(error)}`, `PromptLength=${prompt.length}`);
    }
  }
  
  private findTurnContainerFromEditButton(editButton: HTMLElement): HTMLElement | null {
    const CHAT_TURN_SELECTOR = Array.isArray(SELECTORS.CHAT_TURN) ? SELECTORS.CHAT_TURN.join(',') : SELECTORS.CHAT_TURN;
    const turnContainer = editButton.closest(CHAT_TURN_SELECTOR);
    return turnContainer as HTMLElement | null;
  }

  async extractResponse(): Promise<string> {
    console.log(`[AI Studio LOG] Starting extraction process... (timeout: ${TIMING.FINALIZED_TURN_TIMEOUT_MS}ms)`);

    // WHY: This function waits for the UI to be in a "finalized" state, meaning
    // an "Edit" button is present and actionable, and the turn is not in edit mode.
    // It uses a MutationObserver to react to DOM changes efficiently, which is more
    // performant and reliable than polling with setInterval.
    const waitForFinalizedTurn = (timeout = TIMING.FINALIZED_TURN_TIMEOUT_MS): Promise<{turn: HTMLElement, editButton: HTMLElement}> => {
      return new Promise((resolve, reject) => {
        const EDIT_BUTTON_SELECTOR = Array.isArray(SELECTORS.EDIT_BUTTON) ? SELECTORS.EDIT_BUTTON.join(',') : SELECTORS.EDIT_BUTTON;
        let observer: MutationObserver | null = null;
        let timeoutId: number | null = null;

        const cleanup = () => {
          if (observer) observer.disconnect();
          if (timeoutId) clearTimeout(timeoutId);
        };

        const check = () => {
          const allEditButtons = document.querySelectorAll(EDIT_BUTTON_SELECTOR);
          if (allEditButtons.length === 0) {
            return; // Not ready yet
          }

          const lastEditButton = allEditButtons[allEditButtons.length - 1] as HTMLElement;
          const candidateTurn = this.findTurnContainerFromEditButton(lastEditButton);

          if (candidateTurn) {
            const hasStopEditingButton = candidateTurn.querySelector('button[aria-label="Stop editing"]');
            
            // The critical check: ensure the button is visible (offsetParent) and enabled.
            if (!hasStopEditingButton && lastEditButton.offsetParent !== null && !(lastEditButton as HTMLButtonElement).disabled) {
              console.log('[AI Studio LOG] Found finalized turn via MutationObserver check.');
              cleanup();
              resolve({ turn: candidateTurn, editButton: lastEditButton });
            }
          }
        };

        observer = new MutationObserver(check);
        observer.observe(document.body, {
          childList: true,
          subtree: true,
          attributes: true, 
          attributeFilter: ['aria-label', 'disabled']
        });

        timeoutId = window.setTimeout(() => {
          cleanup();
          const allEditButtons = document.querySelectorAll(EDIT_BUTTON_SELECTOR);
          const errorMessage = `Extraction timed out. Final state: ${allEditButtons.length} edit buttons found. The last response may still be generating or UI has changed.`;
          console.error(`[AI Studio LOG] ${errorMessage}`);
          reject(new Error(errorMessage));
        }, timeout);

        // Perform an initial check in case the element is already present and ready.
        check();
      });
    };

    const {turn: lastTurn, editButton: editButtonToClick} = await waitForFinalizedTurn();
    console.log('[AI Studio LOG] Finalized turn found, clicking edit button...');
    
    // This is the working logic: a direct click after the state has been confirmed.
    editButtonToClick.click();
    
    console.log('[AI Studio LOG] Waiting for textarea to appear...');
    // Use waitForElementWithin to scope the search, which is robust.
    const textarea = await waitForElementWithin<HTMLTextAreaElement | HTMLDivElement>(
        lastTurn,
        SELECTORS.EDIT_TEXTAREA,
        TIMING.TEXTAREA_APPEAR_TIMEOUT_MS
    );
    
    console.log('[AI Studio LOG] Textarea appeared, waiting for UI to stabilize...');
    await new Promise(resolve => setTimeout(resolve, TIMING.UI_STABILIZE_DELAY_MS));

    const extractedContent = (
      (textarea as HTMLTextAreaElement).value ?? (textarea as HTMLElement).innerText ?? ''
    ).trim();
    
    if (!extractedContent) {
        const errorMessage = `Textarea was found but it was empty.`;
        console.error(`[AI Studio LOG] ${errorMessage}`);
        throw this.createErrorWithContext(
          'extractResponse',
          errorMessage,
          'Textarea was found but contained no content'
        );
    }
    
    console.log(`[AI Studio LOG] Extracted ${extractedContent.length} chars successfully.`);

    // Gracefully attempt to exit edit mode, but don't fail if the button isn't found.
    try {
      const stopEditingButton = lastTurn.querySelector<HTMLElement>(SELECTORS.STOP_EDITING_BUTTON);
      if (stopEditingButton) {
        stopEditingButton.click();
        console.log('[AI Studio LOG] Exited edit mode successfully.');
      }
    } catch (e) {
      console.warn('[AI Studio LOG] Could not exit edit mode, but extraction was successful. This is non-critical.', e);
    }
    
    return extractedContent;
  }


  // Add missing methods
  private isLoginPage(): boolean {
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

  private async openSettingsPanel(): Promise<void> {
    if (window.innerWidth <= CONFIG.SCREEN_WIDTH_BREAKPOINT_PX) {
      if (document.querySelector(SELECTORS.SETTINGS_PANEL_CLOSE_BUTTON)) {
        console.log('[AI Studio LOG] Settings panel is already open.');
        return;
      }

      try {
        const tuneButtonEl = await waitForActionableElement<HTMLButtonElement>(
          Array.isArray(SELECTORS.SETTINGS_PANEL_MOBILE_TOGGLE) ? SELECTORS.SETTINGS_PANEL_MOBILE_TOGGLE : [SELECTORS.SETTINGS_PANEL_MOBILE_TOGGLE],
          'Settings panel toggle button',
          getModifiedTimeout(DEFAULT_TIMEOUT_MS),
          2
        );
        const tuneButton = assertIsElement(tuneButtonEl, HTMLButtonElement, 'Settings panel toggle button');
        tuneButton.click();
        await new Promise(resolve => setTimeout(resolve, TIMING.PANEL_ANIMATION_MS));
        
        // Verify panel is actually open
        const panelOpen = document.querySelector(SELECTORS.SETTINGS_PANEL_CLOSE_BUTTON);
        if (!panelOpen) {
          console.warn('[AI Studio LOG] Settings panel may not have opened properly. Retrying...');
          await new Promise(resolve => setTimeout(resolve, TIMING.PANEL_ANIMATION_MS));
        }
        console.log('[AI Studio LOG] Settings panel opened successfully.');
      } catch (error) {
        throw this.createErrorWithContext('openSettingsPanel', `Failed to open settings panel: ${error instanceof Error ? error.message : String(error)}`);
      }
    }
  }

  private async closeSettingsPanel(): Promise<void> {
    if (window.innerWidth <= CONFIG.SCREEN_WIDTH_BREAKPOINT_PX) {
      if (!document.querySelector(SELECTORS.SETTINGS_PANEL_CLOSE_BUTTON)) {
        console.log('[AI Studio LOG] Settings panel appears to be already closed.');
        return;
      }

      try {
        const closeButtonEl = await waitForActionableElement<HTMLButtonElement>(
          [SELECTORS.SETTINGS_PANEL_CLOSE_BUTTON],
          'Settings panel close button',
          getModifiedTimeout(2000),
          0
        );
        const closeButton = assertIsElement(closeButtonEl, HTMLButtonElement, 'Settings panel close button');
        closeButton.click();
        await new Promise(resolve => setTimeout(resolve, TIMING.PANEL_ANIMATION_MS));
        console.log('[AI Studio LOG] Settings panel closed successfully.');
      } catch (error) {
        console.warn('[AI Studio LOG] Could not close settings panel, but continuing:', error);
      }
    }
  }
}

// Export class and instance for backward compatibility
export const aiStudioChatbot = new AiStudioChatbot();