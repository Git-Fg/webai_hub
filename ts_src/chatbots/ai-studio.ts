// ts_src/chatbots/ai-studio.ts

import { Chatbot, AutomationOptions } from '../types/chatbot';
import { notifyDart } from '../utils/notify-dart';
import { waitForElement, waitForElementWithin } from '../utils/wait-for-element';
import { waitForActionableElement } from '../utils/wait-for-actionable-element';
import { assertIsElement } from '../utils/assertions';
import { 
  EVENT_TYPE_LOGIN_REQUIRED
} from '../utils/bridge-constants';

// Import default timeout for consistency
const DEFAULT_TIMEOUT_MS = 10000;

// --- Constants for Timing and Timeouts ---
const TIMING = {
  READINESS_CHECK_INTERVAL_MS: 100,
  TOKEN_COUNT_UPDATE_TIMEOUT_MS: 5000,
  TOKEN_COUNT_CHECK_INTERVAL_MS: 100,
  FINALIZED_TURN_TIMEOUT_MS: 15000,
  FINALIZED_TURN_CHECK_INTERVAL_MS: 1000,
  EDIT_BUTTON_WAIT_TIMEOUT_MS: 2000,
  TEXTAREA_APPEAR_TIMEOUT_MS: 5000,
  UI_STABILIZE_DELAY_MS: 300,
  PANEL_ANIMATION_MS: 400,
  POLL_INTERVAL_MS: 100,
  POLL_TIMEOUT_MS: 5000,
} as const;

// --- Selectors (enhanced fallbacks) ---
const SELECTORS = {
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
        'button:has(span:contains("edit"))',
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

export class AiStudioChatbot implements Chatbot {
  // --- Private Helper Methods ---

  private getPageStateContext(): string {
    const visibleElements = document.querySelectorAll('*').length;
    return `URL=${window.location.href}, ReadyState=${document.readyState}, VisibleElements=${visibleElements}`;
  }

  private createErrorWithContext(operation: string, message: string, additionalContext?: string): Error {
    const context = this.getPageStateContext();
    const fullContext = additionalContext ? `${context}, ${additionalContext}` : context;
    return new Error(`${operation} failed: ${message}\nContext: ${fullContext}`);
  }

  private async retryOperation<T>(
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
          DEFAULT_TIMEOUT_MS,
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
      try {
        const closeButtonEl = await waitForActionableElement<HTMLButtonElement>(
          [SELECTORS.SETTINGS_PANEL_CLOSE_BUTTON],
          'Settings panel close button',
          DEFAULT_TIMEOUT_MS,
          0
        );
        const closeButton = assertIsElement(closeButtonEl, HTMLButtonElement, 'Settings panel close button');
        if (closeButton) {
          closeButton.click();
          await new Promise(resolve => setTimeout(resolve, TIMING.PANEL_ANIMATION_MS));
          
          // Verify panel is actually closed
          const panelClosed = !document.querySelector(SELECTORS.SETTINGS_PANEL_CLOSE_BUTTON);
          if (!panelClosed) {
            console.warn('[AI Studio LOG] Settings panel may not have closed properly. Waiting longer...');
            await new Promise(resolve => setTimeout(resolve, TIMING.PANEL_ANIMATION_MS));
          }
          console.log('[AI Studio LOG] Settings panel closed successfully.');
        }
      } catch (error) {
        throw this.createErrorWithContext('closeSettingsPanel', `Failed to close settings panel: ${error instanceof Error ? error.message : String(error)}`);
      }
    }
  }

  private async waitForElementByText(tagName: string, text: string): Promise<Element> {
    return new Promise((resolve, reject) => {
      const intervalTime = TIMING.POLL_INTERVAL_MS;
      let elapsedTime = 0;
      const interval = setInterval(() => {
        const elements = Array.from(document.querySelectorAll(tagName));
        const targetElement = elements.find(el => el.textContent?.trim().toLowerCase() === text.toLowerCase());
        if (targetElement) {
          clearInterval(interval);
          resolve(targetElement);
          return;
        }
        elapsedTime += intervalTime;
        if (elapsedTime >= TIMING.POLL_TIMEOUT_MS) {
          clearInterval(interval);
          reject(new Error(`Element <${tagName}> with text "${text}" not found within ${TIMING.POLL_TIMEOUT_MS}ms.`));
        }
      }, intervalTime);
    });
  }

  private async setSliderValueByLabel(labelName: string, value: number): Promise<void> {
    try {
      const labelElement = await this.waitForElementByText('h3', labelName) as HTMLElement;
      if (!labelElement) {
        throw this.createErrorWithContext('setSliderValueByLabel', `Could not find the '${labelName}' label in the settings panel.`);
      }
      const container = labelElement.closest('.settings-item-column');
      if (!container) {
        throw this.createErrorWithContext('setSliderValueByLabel', `Could not find parent container for the '${labelName}' label.`);
      }
      const inputElement = container.querySelector('input[type=number]') as HTMLInputElement;
      if (!inputElement) {
        throw this.createErrorWithContext('setSliderValueByLabel', `Found '${labelName}' label but could not find its input field.`);
      }
      // WHY: Verify input is actionable before setting value (visible and enabled)
      if (inputElement.offsetParent === null || inputElement.disabled) {
        throw this.createErrorWithContext('setSliderValueByLabel', `Input field for '${labelName}' is not actionable (visible: ${inputElement.offsetParent !== null}, disabled: ${inputElement.disabled})`);
      }
      inputElement.value = value.toString();
      inputElement.dispatchEvent(new Event('change', { bubbles: true }));
      console.log(`[AI Studio LOG] Set ${labelName} to ${value} successfully.`);
    } catch (error) {
      throw this.createErrorWithContext('setSliderValueByLabel', `Failed to set ${labelName}: ${error instanceof Error ? error.message : String(error)}`, `LabelName=${labelName}, Value=${value}`);
    }
  }

  // --- Internal helpers that assume settings panel is already open ---
  // WHY: Consolidate settings application to avoid repeated open/close cycles

  private async _setModel(modelId: string): Promise<void> {
    console.log(`[AI Studio LOG] Setting model to: "${modelId}"`);
    return this.retryOperation(async () => {
      const modelSelectorEl = await waitForActionableElement<HTMLButtonElement>([SELECTORS.MODEL_SELECTOR_CARD], 'Model selector card', DEFAULT_TIMEOUT_MS, 2);
      const modelSelector = assertIsElement(modelSelectorEl, HTMLButtonElement, 'Model selector card');
      const currentModelNameEl = modelSelector.querySelector('span.title');
      if (currentModelNameEl && currentModelNameEl.textContent?.trim() === modelId) {
        console.log(`[AI Studio LOG] Model "${modelId}" is already selected. Skipping.`);
        return;
      }
      modelSelector.click();
      await new Promise(resolve => setTimeout(resolve, TIMING.PANEL_ANIMATION_MS));

      const allFilterEl = await waitForActionableElement<HTMLButtonElement>([SELECTORS.MODEL_CATEGORIES_ALL_BUTTON], 'Model categories all button', DEFAULT_TIMEOUT_MS, 2);
      const allFilter = assertIsElement(allFilterEl, HTMLButtonElement, 'Model categories all button');
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
          throw this.createErrorWithContext('_setModel', `Model button for "${modelId}" is not visible`);
        }
        modelButton.click();
        console.log(`[AI Studio LOG] Success: Clicked model button for "${modelId}".`);
      } else {
        const availableModels = modelOptions.map(opt => {
          const span = opt.querySelector(SELECTORS.MODEL_TITLE_TEXT);
          return span?.textContent?.trim() || opt.textContent?.trim() || 'unknown';
        }).join(', ');
        throw this.createErrorWithContext('_setModel', `Model button for "${modelId}" not found.`, `AvailableModels=[${availableModels}]`);
      }

      const closeButtonEl = await waitForActionableElement<HTMLButtonElement>([SELECTORS.DIALOG_CLOSE_BUTTON], 'Dialog close button', DEFAULT_TIMEOUT_MS, 2);
      const closeButton = assertIsElement(closeButtonEl, HTMLButtonElement, 'Dialog close button');
      closeButton.click();
      await new Promise(resolve => setTimeout(resolve, TIMING.PANEL_ANIMATION_MS));
    }, '_setModel', 2, 300);
  }

  private async _setTemperature(temperature: number): Promise<void> {
    console.log(`[AI Studio LOG] Setting Temperature to: ${temperature}`);
    await this.setSliderValueByLabel('Temperature', temperature);
  }

  private async _setTopP(topP: number): Promise<void> {
    console.log(`[AI Studio LOG] Setting Top-P to: ${topP}`);
    const advancedToggle = await this.waitForElementByText('p', 'Advanced settings') as HTMLElement;
    const advancedToggleContainer = advancedToggle.closest(SELECTORS.ADVANCED_SETTINGS_TOGGLE);
    if (advancedToggleContainer && !advancedToggleContainer.classList.contains('expanded')) {
      (advancedToggleContainer as HTMLElement).click();
      await new Promise(resolve => setTimeout(resolve, TIMING.PANEL_ANIMATION_MS));
    }
    await this.setSliderValueByLabel('Top P', topP);
  }

  private async _setThinkingBudget(budget?: number): Promise<void> {
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

  private async _setAdvancedOptions(options: { useWebSearch?: boolean; disableThinking?: boolean; urlContext?: boolean; }, modelId?: string): Promise<void> {
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
      const toolsToggle = await this.waitForElementByText('p', 'Tools') as HTMLElement;
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

  // --- Public Chatbot Interface Implementation ---

  async waitForReady(): Promise<void> {
    await waitForElement<HTMLElement>([
        SELECTORS.MODEL_SELECTOR_DESKTOP,
        SELECTORS.RUN_SETTINGS_TOGGLE_MOBILE,
    ]);
    console.log('[AI Studio] UI is ready.');
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
        await this._setModel(options.model);
      }
      if (options.temperature !== undefined) {
        await this._setTemperature(options.temperature);
      }
      if (options.topP !== undefined) {
        await this._setTopP(options.topP);
      }
      if (options.thinkingBudget !== undefined) {
        await this._setThinkingBudget(options.thinkingBudget);
      }
      const advancedOptions = {
        useWebSearch: options.useWebSearch,
        disableThinking: options.disableThinking,
        urlContext: options.urlContext,
      };
      if (Object.values(advancedOptions).some(v => v !== undefined)) {
        await this._setAdvancedOptions(advancedOptions, options.model);
      }
    } finally {
      await this.closeSettingsPanel();
    }
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
      const inputAreaEl = await waitForActionableElement<HTMLTextAreaElement | HTMLInputElement>(SELECTORS.PROMPT_INPUTS, 'Prompt input area', DEFAULT_TIMEOUT_MS, 2);
      if (inputAreaEl instanceof HTMLTextAreaElement || inputAreaEl instanceof HTMLInputElement) {
        inputAreaEl.value = prompt;
        inputAreaEl.dispatchEvent(new Event('input', { bubbles: true }));
        inputAreaEl.dispatchEvent(new Event('change', { bubbles: true }));
        console.log('[AI Studio LOG] Prompt entered into input area, waiting for token count update...');
      } else {
        const elementType = inputAreaEl ? (inputAreaEl as HTMLElement).constructor.name : 'null';
        throw this.createErrorWithContext('sendPrompt', 'Input area is not a valid textarea or input element.', `ElementType=${elementType}`);
      }
      
      await new Promise<void>((resolve) => {
        const timeout = TIMING.TOKEN_COUNT_UPDATE_TIMEOUT_MS;
        const startTime = Date.now();
        
        const checkTokenCount = () => {
          const elapsed = Date.now() - startTime;
          if (elapsed > timeout) {
            console.warn('[AI Studio LOG] Token count timeout - proceeding anyway');
            resolve();
            return;
          }
          
          const tokenCountElement = document.querySelector(SELECTORS.TOKEN_COUNT);
          const text = tokenCountElement?.textContent?.trim();
          if (text && !text.startsWith('0')) {
            console.log(`[AI Studio LOG] Token count updated: ${text}`);
            resolve();
          } else {
            setTimeout(checkTokenCount, TIMING.TOKEN_COUNT_CHECK_INTERVAL_MS);
          }
        };
        checkTokenCount();
      });
      
      return this.retryOperation(async () => {
        const sendButtonEl = await waitForActionableElement<HTMLElement>(SELECTORS.SEND_BUTTONS, 'Send button', DEFAULT_TIMEOUT_MS, 2);
        const sendButton = assertIsElement(sendButtonEl, HTMLElement, 'Send button');
        sendButton.click();
        console.log('[AI Studio LOG] Send button clicked successfully.');
      }, 'sendPrompt (click send button)', 2, 300);
    } catch (error) {
      throw this.createErrorWithContext('sendPrompt', `Failed to send prompt: ${error instanceof Error ? error.message : String(error)}`, `PromptLength=${prompt.length}`);
    }
  }
  
  async extractResponse(): Promise<string> {
    console.log(`[AI Studio LOG] Starting extraction process... (timeout: ${TIMING.FINALIZED_TURN_TIMEOUT_MS}ms)`);
    
    const findTurnContainerFromEditButton = (editButton: HTMLElement): HTMLElement => {
      // WHY: Bottom-up approach (starting from Edit button, traversing up to find turn)
      // This is more reliable than top-down because:
      // 1. querySelectorAll(CHAT_TURN_SELECTOR) returns turns in DOM order, which may not match Edit button order
      // 2. The last turn in querySelectorAll result might not contain the last Edit button
      // 3. closest() traverses up from Edit button, guaranteeing we find the correct parent turn
      // This matches the validation script approach which works reliably in browsers
      const CHAT_TURN_SELECTOR = Array.isArray(SELECTORS.CHAT_TURN) ? SELECTORS.CHAT_TURN.join(',') : SELECTORS.CHAT_TURN;
      const explicit = editButton.closest(CHAT_TURN_SELECTOR);
      if (explicit) return explicit as HTMLElement;

      // Heuristic fallback: climb ancestors and pick the first with likely turn hints
      let cursor: HTMLElement | null = editButton as HTMLElement;
      const turnHints = [
        (el: HTMLElement) => el.id?.startsWith('turn-'),
        (el: HTMLElement) => el.tagName.toLowerCase() === 'ms-chat-turn',
        (el: HTMLElement) => /\bchat-?turn\b/i.test(el.className),
        (el: HTMLElement) => el.getAttribute('data-test-id')?.toLowerCase().includes('turn') === true,
      ];
      while (cursor && cursor !== document.body) {
        // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
        if (turnHints.some(fn => fn(cursor!))) {
          return cursor;
        }
        cursor = cursor.parentElement;
      }
      // Last resort: use the edit button's nearest sizeable container
      return (editButton.parentElement as HTMLElement) || document.body as unknown as HTMLElement;
    };

    // WHY: Return both turn container and Edit button to avoid redundant search
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
          const candidateTurn = findTurnContainerFromEditButton(lastEditButton);

          if (candidateTurn) {
            const hasStopEditingButton = candidateTurn.querySelector('button[aria-label="Stop editing"]');
            
            if (!hasStopEditingButton && lastEditButton.offsetParent !== null && !(lastEditButton as HTMLButtonElement).disabled) {
              console.log('[AI Studio LOG] Found finalized turn via MutationObserver check.');
              cleanup();
              resolve({ turn: candidateTurn, editButton: lastEditButton });
            }
          }
        };

        // WHY: Use a MutationObserver instead of setInterval to avoid crashing the JS context.
        // This is far more performant as it only runs 'check' when the DOM actually changes.
        observer = new MutationObserver(check);
        observer.observe(document.body, {
          childList: true,
          subtree: true,
          attributes: true, // Watch for changes to aria-label, disabled, etc.
          attributeFilter: ['aria-label', 'disabled']
        });

        timeoutId = window.setTimeout(() => {
          cleanup();
          const allEditButtons = document.querySelectorAll(EDIT_BUTTON_SELECTOR);
          const errorMessage = `Extraction timed out via MutationObserver. Final state: ${allEditButtons.length} edit buttons found.`;
          console.error(`[AI Studio LOG] ${errorMessage}`);
          reject(new Error(errorMessage));
        }, timeout);

        // Perform an initial check in case the element is already present
        check();
      });
    };

    const {turn: lastTurn, editButton: editButtonToClick} = await waitForFinalizedTurn();
    console.log('[AI Studio LOG] Finalized turn found, clicking edit button...');
    
    // ENHANCED LOGGING: Add visual indicator and detailed logging before clicking
    console.log(`[AI Studio LOG] [ENHANCED] Edit button details:`, {
      tagName: editButtonToClick.tagName,
      outerHTML: editButtonToClick.outerHTML.substring(0, 200),
      offsetParent: editButtonToClick.offsetParent !== null,
      // Fix: Check if element is HTMLButtonElement before accessing disabled property
      disabled: editButtonToClick instanceof HTMLButtonElement ? editButtonToClick.disabled : 'N/A',
      ariaLabel: editButtonToClick.getAttribute('aria-label'),
      className: editButtonToClick.className
    });
    
    // Add visual highlight to edit button before clicking
    const originalStyle = editButtonToClick.style.border;
    editButtonToClick.style.border = '3px solid red';
    console.log('[AI Studio LOG] [ENHANCED] Edit button highlighted in red before clicking');
    
    // Click the edit button
    editButtonToClick.click();
    
    // Wait a moment and check if anything changed
    await new Promise(resolve => setTimeout(resolve, 500));
    console.log(`[AI Studio LOG] [ENHANCED] Edit button state after clicking:`, {
      tagName: editButtonToClick.tagName,
      // Fix: Check if element is HTMLButtonElement before accessing disabled property
      disabled: editButtonToClick instanceof HTMLButtonElement ? editButtonToClick.disabled : 'N/A',
      offsetParent: editButtonToClick.offsetParent !== null,
      border: editButtonToClick.style.border
    });
    
    // Restore original style
    editButtonToClick.style.border = originalStyle;

    console.log('[AI Studio LOG] Waiting for textarea to appear...');
    const textareaSelectors = Array.isArray(SELECTORS.EDIT_TEXTAREA) ? SELECTORS.EDIT_TEXTAREA : [SELECTORS.EDIT_TEXTAREA];
    
    // ENHANCED LOGGING: Log all textarea search attempts
    console.log(`[AI Studio LOG] [ENHANCED] Searching for textarea with selectors: ${textareaSelectors.join(', ')}`);
    console.log(`[AI Studio LOG] [ENHANCED] Search root: lastTurn with ID: ${lastTurn.id || 'no-id'}, tagName: ${lastTurn.tagName}`);
    
    let textareaEl: HTMLTextAreaElement | HTMLDivElement;
    try {
      // First try to find textarea within the last turn
      console.log(`[AI Studio LOG] [ENHANCED] Attempting to find textarea within last turn...`);
      const textareasInTurn = Array.from(lastTurn.querySelectorAll(textareaSelectors.join(', ')));
      console.log(`[AI Studio LOG] [ENHANCED] Found ${textareasInTurn.length} textarea(s) within last turn`);
      
      if (textareasInTurn.length > 0) {
        textareaEl = textareasInTurn[0] as HTMLTextAreaElement | HTMLDivElement;
        console.log(`[AI Studio LOG] [ENHANCED] Using first textarea found in turn:`, {
          tagName: textareaEl.tagName,
          id: textareaEl.id || 'no-id',
          className: textareaEl.className || 'no-class',
          value: textareaEl instanceof HTMLTextAreaElement ? textareaEl.value.substring(0, 100) : 'N/A',
          innerText: textareaEl instanceof HTMLDivElement ? textareaEl.innerText.substring(0, 100) : 'N/A',
          offsetParent: textareaEl.offsetParent !== null
        });
      } else {
        throw new Error('No textarea found within last turn');
      }
    } catch (error) {
      console.warn(`[AI Studio LOG] [ENHANCED] Error finding textarea within last turn: ${error}`);
      // Fallback: editor may render outside of turn container
      console.log('[AI Studio LOG] [ENHANCED] Textarea not found within last turn, trying global search...');
      
      try {
        const allTextareas = Array.from(document.querySelectorAll(textareaSelectors.join(', ')));
        console.log(`[AI Studio LOG] [ENHANCED] Found ${allTextareas.length} textarea(s) globally`);
        
        // Filter out prompt input textareas
        const editTextareas = allTextareas.filter(el => el.closest('ms-chunk-input') === null);
        console.log(`[AI Studio LOG] [ENHANCED] Found ${editTextareas.length} edit textarea(s) after filtering out prompt inputs`);
        
        if (editTextareas.length > 0) {
          textareaEl = editTextareas[editTextareas.length - 1] as HTMLTextAreaElement | HTMLDivElement;
          console.log(`[AI Studio LOG] [ENHANCED] Using last edit textarea found globally:`, {
            tagName: textareaEl.tagName,
            id: textareaEl.id || 'no-id',
            className: textareaEl.className || 'no-class',
            value: textareaEl instanceof HTMLTextAreaElement ? textareaEl.value.substring(0, 100) : 'N/A',
            innerText: textareaEl instanceof HTMLDivElement ? textareaEl.innerText.substring(0, 100) : 'N/A',
            offsetParent: textareaEl.offsetParent !== null
          });
        } else {
          throw new Error('No edit textarea found globally');
        }
      } catch (globalError) {
        console.error(`[AI Studio LOG] [ENHANCED] Error in global textarea search: ${globalError}`);
        throw globalError;
      }
    }
    
    const textarea = textareaEl;
    console.log('[AI Studio LOG] Textarea appeared, waiting for UI to stabilize...');
    
    // Add visual highlight to textarea
    if (textarea) {
      const originalTextareaStyle = textarea.style.border;
      textarea.style.border = '3px solid blue';
      console.log('[AI Studio LOG] [ENHANCED] Textarea highlighted in blue');
    
    await new Promise(resolve => setTimeout(resolve, TIMING.UI_STABILIZE_DELAY_MS));
      
      // Log textarea details after stabilization
      console.log(`[AI Studio LOG] [ENHANCED] Textarea details after stabilization:`, {
        tagName: textarea.tagName,
        value: textarea instanceof HTMLTextAreaElement ? textarea.value.substring(0, 100) : 'N/A',
        innerText: textarea instanceof HTMLDivElement ? textarea.innerText.substring(0, 100) : 'N/A',
        valueLength: textarea instanceof HTMLTextAreaElement ? textarea.value.length : 
                     textarea instanceof HTMLDivElement ? textarea.innerText.length : 0,
        offsetParent: textarea.offsetParent !== null,
        disabled: textarea instanceof HTMLTextAreaElement ? textarea.disabled : 'N/A'
      });
      
      // Restore original style
      textarea.style.border = originalTextareaStyle;
    }
    
    const extractedContent = (
      (textarea as HTMLTextAreaElement).value ?? (textarea as HTMLElement).innerText ?? ''
    ).trim();
    const preview = extractedContent.substring(0, 100);
    const previewText = extractedContent.length > 100 ? `${preview}...` : preview;
    console.log(`[AI Studio LOG] Extracted ${extractedContent.length} chars successfully. Preview: "${previewText}"`);

    if (!extractedContent) {
        const textareaValueLength = (textarea instanceof HTMLTextAreaElement) 
          ? textarea.value.length 
          : (textarea as HTMLElement).innerText.length;
        const errorMessage = `Textarea was found but it was empty.
Context: URL=${window.location.href}, TextareaVisible=${textarea.offsetParent !== null}, TextareaValueLength=${textareaValueLength}`;
        console.error(`[AI Studio LOG] ${errorMessage}`);
        throw new Error(errorMessage);
    }

    try {
      console.log('[AI Studio LOG] Looking for stop editing button...');
      const stopEditingButtonEl = await waitForElementWithin<HTMLElement>(lastTurn, [SELECTORS.STOP_EDITING_BUTTON], TIMING.EDIT_BUTTON_WAIT_TIMEOUT_MS);
      const stopEditingButton = assertIsElement(stopEditingButtonEl, HTMLElement, 'Stop editing button');
      if (stopEditingButton) {
        await new Promise(resolve => setTimeout(resolve, TIMING.UI_STABILIZE_DELAY_MS));
        stopEditingButton.click();
        console.log('[AI Studio LOG] Exited edit mode successfully.');
      }
    } catch (e) {
      console.warn('[AI Studio LOG] Could not exit edit mode, but extraction was successful. This is non-critical.', e);
    }
    
    return extractedContent;
  }
}

// Export class and instance for backward compatibility
export const aiStudioChatbot = new AiStudioChatbot();
