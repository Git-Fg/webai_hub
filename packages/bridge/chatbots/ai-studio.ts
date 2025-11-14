// ts_src/chatbots/ai-studio.ts

import { Chatbot, AutomationOptions } from '../types/chatbot';
import { notifyDart } from '../utils/notify-dart';
import { waitForElement, waitForElementWithin, waitForElementByText } from '../utils/wait-for-element';
import { waitForActionableElement, waitForAnimationEnd } from '../utils/wait-for-actionable-element';
import { assertIsElement } from '../utils/assertions';
import { getModifiedTimeout } from '../utils/timeout';
import { retryOperation } from '../utils/retry';
import {
  EVENT_TYPE_LOGIN_REQUIRED,
} from '../utils/bridge-constants';

// Import default timeout for consistency
const DEFAULT_TIMEOUT_MS = 10000;

// --- Constants for Timing and Timeouts ---
const TIMING = {
  READINESS_CHECK_INTERVAL_MS: 100,
  TOKEN_COUNT_UPDATE_TIMEOUT_MS: 10000,
  TOKEN_COUNT_CHECK_INTERVAL_MS: 100,
  UI_STABILIZE_AFTER_TOKEN_COUNT_MS: 30,
  FINALIZED_TURN_TIMEOUT_MS: 30000, // WHY: Increased from 15s to 30s to accommodate slower AI responses
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
export const SELECTORS = {
  // WHY: Dialog selectors for initial page load cleanup
  // These dialogs can block interaction with the main UI, so we dismiss them proactively
  AUTOSAVE_DIALOG_BUTTON: 'ms-autosave-enabled-by-default-dialog button[jslog*="273915"]',
  COOKIE_CONSENT_BUTTON: '.glue-cookie-notification-bar__accept',
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
  SETTINGS_PANEL_CLOSE_BUTTON:
    'ms-run-settings button[iconname="close"], button[aria-label="Close run settings panel"]',
  TOOLS_SECTION_TOGGLE:
    'button[aria-label="Expand or collapse tools"], button[aria-label="Grounding with Google Search"] + button[aria-label="Expand or collapse tools"]',
  ADVANCED_SECTION_TOGGLE:
    'button[aria-label="Expand or collapse advanced settings"]',
  MODEL_SELECTOR_CARD: 'button.model-selector-card',
  MODEL_CATEGORIES_ALL_BUTTON: 'button[data-test-category-button]',
  MODEL_CAROUSEL_BUTTON: 'ms-model-carousel-row button.content-button',
  MODEL_TITLE_TEXT: 'span.model-title-text',
  SYSTEM_PROMPT_CARD: 'button[data-test-system-instructions-card]',
  SYSTEM_PROMPT_TEXTAREA: 'ms-system-instructions textarea',
  // WHY: Use data-test-close-button attribute directly for maximum specificity and reliability
  // This selector is stable and works regardless of the dialog container structure
  DIALOG_CLOSE_BUTTON: 'button[data-test-close-button]',
  MODEL_DIALOG_CONTAINER: 'mat-dialog-container',
  ADVANCED_SETTINGS_TOGGLE: 'div.settings-item',
  THINKING_TOGGLE:
    'button[aria-label="Toggle thinking mode"], button#mat-mdc-slide-toggle-0-button',
  MANUAL_BUDGET_TOGGLE:
    'button[aria-label="Toggle thinking budget between auto and manual"], button#mat-mdc-slide-toggle-1-button',
  BUDGET_INPUT: 'div[data-test-id="user-setting-budget-animation-wrapper"] input',
  TOOLS_TOGGLE_SELECTOR: 'div[data-test-id="tools-group"], div.settings-item',
  WEB_SEARCH_TOGGLE:
    'div[data-test-id="searchAsAToolTooltip"] button[role="switch"], button#mat-mdc-slide-toggle-5-button',
  URL_CONTEXT_TOGGLE:
    'div[data-test-id="browseAsAToolTooltip"] button[role="switch"], button#mat-mdc-slide-toggle-6-button',
};

const CONFIG = {
  SCREEN_WIDTH_BREAKPOINT_PX: 960,
  LOG_PREVIEW_LENGTH: 50,
} as const;

const delay = (ms: number) =>
  new Promise<void>(resolve => {
    // WHY: Provide deterministic UI-settling delays when no actionable element is available (e.g., animations).
    // eslint-disable-next-line custom/disallow-timeout-for-waits
    setTimeout(resolve, ms);
  });

export class AiStudioChatbot implements Chatbot {
  // --- Settings Management Methods (formerly in SettingsManager) ---

  async setModel(modelId: string): Promise<void> {
    console.log(`[AI Studio Settings] Setting model to: "${modelId}"`);
    return retryOperation(async () => {
      const modelSelectorEl = await waitForActionableElement<HTMLButtonElement>(
        [SELECTORS.MODEL_SELECTOR_CARD],
        'Model selector card',
        getModifiedTimeout(DEFAULT_TIMEOUT_MS),
        2,
      );
      const modelSelector = assertIsElement(modelSelectorEl, HTMLButtonElement, 'Model selector card');
      const currentModelNameEl = modelSelector.querySelector('span.title');
      if (currentModelNameEl && currentModelNameEl.textContent?.trim() === modelId) {
        console.log(`[AI Studio LOG] Model "${modelId}" is already selected. Skipping.`);
        return;
      }
      modelSelector.click();
      // WHY: Dynamically wait for model selection dialog to appear instead of using a fixed delay.
      const modelDialogContainer = await waitForElement(
        [SELECTORS.MODEL_DIALOG_CONTAINER],
        getModifiedTimeout(3000),
      );
      await waitForAnimationEnd(
        modelDialogContainer as HTMLElement,
        getModifiedTimeout(TIMING.PANEL_ANIMATION_MS),
      );

      // WHY: Try to find element, and if occluded, wait a bit more and try clicking anyway
      let allFilterEl: HTMLButtonElement | null = null;
      try {
        allFilterEl = await waitForActionableElement<HTMLButtonElement>(
          [SELECTORS.MODEL_CATEGORIES_ALL_BUTTON],
          'Model categories all button',
          getModifiedTimeout(DEFAULT_TIMEOUT_MS),
          2,
        );
      } catch (error) {
        // If actionability check fails due to occlusion, try finding element anyway and clicking it
        const errorMsg = error instanceof Error ? error.message : String(error);
        if (errorMsg.includes('occluded')) {
          console.log('[AI Studio LOG] Element found but occluded. Waiting longer and attempting click anyway...');
          // WHY: Wait for UI to stabilize after occlusion detection, not a UI wait for element
          await delay(TIMING.PANEL_ANIMATION_MS);
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
      // WHY: Wait for smooth scroll animation to complete before clicking
      await waitForAnimationEnd(allFilter, getModifiedTimeout(TIMING.UI_STABILIZE_DELAY_MS));
      allFilter.click();
      // WHY: Wait for UI animation to complete after click before proceeding
      await waitForAnimationEnd(allFilter, getModifiedTimeout(TIMING.UI_STABILIZE_DELAY_MS));

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
          throw this.createErrorWithContext('setModel', `Model button for "${modelId}" is not visible`);
        }
        modelButton.click();
        console.log(`[AI Studio LOG] Success: Clicked model button for "${modelId}".`);
        // WHY: Wait for dialog close animation to complete (it may close automatically after model selection)
        await waitForAnimationEnd(modelButton, getModifiedTimeout(TIMING.PANEL_ANIMATION_MS));
      } else {
        const availableModels = modelOptions
          .map(opt => {
            const span = opt.querySelector(SELECTORS.MODEL_TITLE_TEXT);
            return span?.textContent?.trim() || opt.textContent?.trim() || 'unknown';
          })
          .join(', ');
        throw this.createErrorWithContext(
          'setModel',
          `Model button for "${modelId}" not found.`,
          `AvailableModels=[${availableModels}]`,
        );
      }

      // WHY: Check if dialog is still open before trying to close it (some dialogs close automatically)
      if (document.querySelector('mat-dialog-container')) {
        try {
          const closeButtonEl = await waitForActionableElement<HTMLButtonElement>(
            [SELECTORS.DIALOG_CLOSE_BUTTON],
            'Dialog close button',
            getModifiedTimeout(2000),
            0,
          );
          const closeButton = assertIsElement(closeButtonEl, HTMLButtonElement, 'Dialog close button');
          closeButton.click();
          // WHY: Wait for dialog close animation to complete
          await waitForAnimationEnd(closeButton, getModifiedTimeout(TIMING.PANEL_ANIMATION_MS));
        } catch {
          console.log('[AI Studio LOG] Model dialog seems to have closed automatically.');
        }
      }
    }, 'setModel', 2, 300);
  }

  async setTemperature(temperature: number): Promise<void> {
    console.log(`[AI Studio LOG] Setting Temperature to: ${temperature}`);
    try {
      // WHY: Wait for settings panel content to be fully loaded before accessing elements
      await delay(TIMING.UI_STABILIZE_DELAY_MS);

      const labelElement = (await waitForElementByText(
        'h3',
        'Temperature',
        getModifiedTimeout(DEFAULT_TIMEOUT_MS),
      )) as HTMLElement;
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
        throw new Error(
          `Input field for 'Temperature' is not actionable (visible: ${inputElement.offsetParent !== null}, disabled: ${inputElement.disabled})`,
        );
      }
      inputElement.value = temperature.toString();
      inputElement.dispatchEvent(new Event('change', { bubbles: true }));
      console.log(`[AI Studio LOG] Set Temperature to ${temperature} successfully.`);
    } catch (error) {
      throw new Error(
        `Failed to set Temperature: ${error instanceof Error ? error.message : String(error)}. LabelName=Temperature, Value=${temperature}`,
      );
    }
  }

  async setTopP(topP: number): Promise<void> {
    console.log(`[AI Studio LOG] Setting Top-P to: ${topP}`);
    const advancedToggle = (await waitForElementByText(
      'p',
      'Advanced settings',
      getModifiedTimeout(DEFAULT_TIMEOUT_MS),
    )) as HTMLElement;
    const advancedToggleContainer = advancedToggle.closest(SELECTORS.ADVANCED_SETTINGS_TOGGLE);
    if (advancedToggleContainer && !advancedToggleContainer.classList.contains('expanded')) {
      (advancedToggleContainer as HTMLElement).click();
      // WHY: Wait for panel expansion animation to complete
      await waitForAnimationEnd(
        advancedToggleContainer as HTMLElement,
        getModifiedTimeout(TIMING.PANEL_ANIMATION_MS),
      );
    }
    try {
      const labelElement = (await waitForElementByText(
        'h3',
        'Top P',
        getModifiedTimeout(DEFAULT_TIMEOUT_MS),
      )) as HTMLElement;
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
        throw new Error(
          `Input field for 'Top P' is not actionable (visible: ${inputElement.offsetParent !== null}, disabled: ${inputElement.disabled})`,
        );
      }
      inputElement.value = topP.toString();
      inputElement.dispatchEvent(new Event('change', { bubbles: true }));
      console.log(`[AI Studio LOG] Set Top P to ${topP} successfully.`);
    } catch (error) {
      throw new Error(
        `Failed to set Top P: ${error instanceof Error ? error.message : String(error)}. LabelName=Top P, Value=${topP}`,
      );
    }
  }

  async setThinkingBudget(budget?: number): Promise<void> {
    console.log(`[AI Studio LOG] Configuring thinking budget. Provided value: ${budget}`);
    try {
      const advancedToggleEl = await waitForElement<HTMLButtonElement>(
        [SELECTORS.ADVANCED_SECTION_TOGGLE],
        getModifiedTimeout(DEFAULT_TIMEOUT_MS),
      );
      const advancedToggle = assertIsElement(advancedToggleEl, HTMLButtonElement, 'Advanced settings toggle');
      const advancedExpanded =
        advancedToggle.getAttribute('aria-expanded') === 'true' || advancedToggle.classList.contains('expanded');
      if (!advancedExpanded) {
        advancedToggle.click();
        // WHY: Wait for section expansion animation to complete
        await waitForAnimationEnd(advancedToggle, getModifiedTimeout(TIMING.PANEL_ANIMATION_MS));
      }
    } catch (error) {
      console.warn('[AI Studio LOG] Unable to expand advanced settings before configuring thinking budget:', error);
    }
    const thinkingToggleEl = await waitForElement<HTMLButtonElement>([SELECTORS.THINKING_TOGGLE]);
    const thinkingToggle = assertIsElement(thinkingToggleEl, HTMLButtonElement, 'Thinking toggle');
    const isThinkingEnabled = thinkingToggle.getAttribute('aria-checked') === 'true';
    if (budget != null && !isThinkingEnabled) {
      thinkingToggle.click();
      console.log('[AI Studio LOG] Enabled "thinking" feature.');
      // WHY: Wait for toggle animation to complete
      await waitForAnimationEnd(thinkingToggle, getModifiedTimeout(TIMING.PANEL_ANIMATION_MS));
    }
    const manualBudgetToggleEl = await waitForElement<HTMLButtonElement>([SELECTORS.MANUAL_BUDGET_TOGGLE]);
    const manualBudgetToggle = assertIsElement(manualBudgetToggleEl, HTMLButtonElement, 'Manual budget toggle');
    const isManualEnabled = manualBudgetToggle.getAttribute('aria-checked') === 'true';
    if (budget != null) {
      if (!isManualEnabled) {
        manualBudgetToggle.click();
        console.log('[AI Studio LOG] Enabled "manual budget".');
        // WHY: Wait for toggle animation to complete
        await waitForAnimationEnd(manualBudgetToggle, getModifiedTimeout(TIMING.PANEL_ANIMATION_MS));
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

  async setAdvancedOptions(
    options: { useWebSearch?: boolean; disableThinking?: boolean; urlContext?: boolean },
    modelId?: string,
  ): Promise<void> {
    console.log('[AI Studio LOG] Setting advanced options:', options);
    if (options.disableThinking !== undefined) {
      const lower = modelId?.toLowerCase();
      if (lower === 'gemini-2.5-pro') {
        console.log('[AI Studio LOG] Skipping "disableThinking" toggle as it is not applicable for gemini-2.5-pro.');
      } else {
        try {
          const advancedToggleEl = await waitForElement<HTMLButtonElement>(
            [SELECTORS.ADVANCED_SECTION_TOGGLE],
            getModifiedTimeout(DEFAULT_TIMEOUT_MS),
          );
          const advancedToggle = assertIsElement(advancedToggleEl, HTMLButtonElement, 'Advanced settings toggle');
          const isExpanded =
            advancedToggle.getAttribute('aria-expanded') === 'true' || advancedToggle.classList.contains('expanded');
          if (!isExpanded) {
            advancedToggle.click();
            // WHY: Wait for section expansion animation to complete
            await waitForAnimationEnd(advancedToggle, getModifiedTimeout(TIMING.PANEL_ANIMATION_MS));
          }
        } catch (error) {
          console.warn('[AI Studio LOG] Unable to expand advanced settings before toggling thinking:', error);
        }
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
      try {
        const toolsToggleButtonEl = await waitForElement<HTMLButtonElement>(
          [SELECTORS.TOOLS_SECTION_TOGGLE],
          getModifiedTimeout(DEFAULT_TIMEOUT_MS),
        );
        const toolsToggleButton = assertIsElement(toolsToggleButtonEl, HTMLButtonElement, 'Tools section toggle');
        const isExpanded =
          toolsToggleButton.getAttribute('aria-expanded') === 'true' || toolsToggleButton.classList.contains('expanded');
        if (!isExpanded) {
          toolsToggleButton.click();
          // WHY: Wait for panel expansion animation to complete
          await waitForAnimationEnd(toolsToggleButton, getModifiedTimeout(TIMING.PANEL_ANIMATION_MS));
        }
      } catch (error) {
        console.warn(
          '[AI Studio LOG] Unable to locate tools section toggle. Proceeding without explicit expansion.',
          error,
        );
      }

      try {
        const scrollContainer = document.querySelector<HTMLElement>('div.settings-items-wrapper [msscrollable], div.settings-items-wrapper');
        if (scrollContainer) {
          scrollContainer.scrollTop = scrollContainer.scrollHeight;
          await delay(TIMING.UI_STABILIZE_DELAY_MS);
        }
      } catch (error) {
        console.warn('[AI Studio LOG] Failed to scroll tools section into view:', error);
      }

      if (options.useWebSearch !== undefined) {
        try {
          const webSearchEl = await waitForElement<HTMLButtonElement>(
            [SELECTORS.WEB_SEARCH_TOGGLE],
            getModifiedTimeout(DEFAULT_TIMEOUT_MS),
          );
          const webSearchToggle = assertIsElement(webSearchEl, HTMLButtonElement, 'Web search toggle');
          if (options.useWebSearch !== (webSearchToggle.getAttribute('aria-checked') === 'true')) {
            webSearchToggle.click();
            console.log(`[AI Studio LOG] Toggled web search to: ${options.useWebSearch}`);
          }
        } catch (error) {
          console.warn('[AI Studio LOG] Web search toggle not available for current UI. Skipping toggle update.', error);
        }
      }

      if (options.urlContext !== undefined) {
        try {
          const urlContextEl = await waitForElement<HTMLButtonElement>(
            [SELECTORS.URL_CONTEXT_TOGGLE],
            getModifiedTimeout(DEFAULT_TIMEOUT_MS),
          );
          const urlContextToggle = assertIsElement(urlContextEl, HTMLButtonElement, 'URL context toggle');
          if (options.urlContext !== (urlContextToggle.getAttribute('aria-checked') === 'true')) {
            urlContextToggle.click();
            console.log(`[AI Studio LOG] Toggled URL context to: ${options.urlContext}`);
          }
        } catch (error) {
          console.warn('[AI Studio LOG] URL context toggle not available for current UI. Skipping toggle update.', error);
        }
      }
    }
  }

  async setSystemPrompt(systemPrompt: string): Promise<void> {
    if (!systemPrompt) return;
    console.log('[AI Studio LOG] Setting system prompt.');
    await this.openSettingsPanel();
    try {
      const systemPromptButtonEl = await waitForElement<HTMLButtonElement>([SELECTORS.SYSTEM_PROMPT_CARD]);
      const systemPromptButton = assertIsElement(systemPromptButtonEl, HTMLButtonElement, 'System prompt card');
      systemPromptButton.click();
      // WHY: Wait for dialog open animation to complete
      await waitForAnimationEnd(systemPromptButton, getModifiedTimeout(TIMING.PANEL_ANIMATION_MS));
      const textareaEl = await waitForElement<HTMLTextAreaElement>([SELECTORS.SYSTEM_PROMPT_TEXTAREA]);
      const textarea = assertIsElement(textareaEl, HTMLTextAreaElement, 'System prompt textarea');
      textarea.value = systemPrompt;
      textarea.dispatchEvent(new Event('input', { bubbles: true }));
      console.log('[AI Studio LOG] Success: System prompt entered.');
      const closeButtonEl = await waitForElement<HTMLButtonElement>([SELECTORS.DIALOG_CLOSE_BUTTON]);
      const closeButton = assertIsElement(closeButtonEl, HTMLButtonElement, 'Dialog close button');
      closeButton.click();
      // WHY: Wait for dialog close animation to complete
      await waitForAnimationEnd(closeButton, getModifiedTimeout(TIMING.PANEL_ANIMATION_MS));
    } finally {
      await this.closeSettingsPanel();
    }
  }

  async applyAllSettings(options: AutomationOptions): Promise<void> {
    // WHY: Handle system prompt first as a separate operation since it opens/closes
    // its own settings panel and dialog. This matches the original working logic.
    if (options.systemPrompt) {
      await this.setSystemPrompt(options.systemPrompt);
    }
    const anyOtherSetting =
      options.model ||
      options.temperature !== undefined ||
      options.topP !== undefined ||
      options.thinkingBudget !== undefined ||
      options.useWebSearch !== undefined ||
      options.disableThinking !== undefined ||
      options.urlContext !== undefined;
    if (!anyOtherSetting) {
      console.log('[AI Studio LOG] No other settings to apply. Skipping panel.');
      return;
    }
    await this.openSettingsPanel();

    // WHY: Wait for settings panel content to be fully loaded, especially after tab switches
    await delay(TIMING.UI_STABILIZE_DELAY_MS * 2);

    // WHY: Verify that settings panel content is actually loaded by checking for a common element
    try {
      const settingsContentCheck = document.querySelector('.settings-item-column, input[type="number"]');
      if (!settingsContentCheck) {
        console.warn('[AI Studio LOG] Settings panel content not yet loaded, waiting additional time...');
        await delay(TIMING.UI_STABILIZE_DELAY_MS);
      }
    } catch {
      // Ignore errors in content check, proceed with settings application
    }

    try {
      if (options.model) {
        await this.setModel(options.model);
        // WHY: Model selection may cause page navigation which closes the settings panel.
        await delay(TIMING.UI_STABILIZE_DELAY_MS * 2);
        const panelStillOpen = document.querySelector(SELECTORS.SETTINGS_PANEL_CLOSE_BUTTON);
        if (!panelStillOpen) {
          console.log('[AI Studio LOG] Settings panel closed after model selection, reopening...');
          await this.openSettingsPanel();
          await delay(TIMING.UI_STABILIZE_DELAY_MS * 2);
          const settingsContentCheck = document.querySelector('.settings-item-column, input[type="number"]');
          if (!settingsContentCheck) {
            console.warn('[AI Studio LOG] Settings panel content not yet loaded after reopening, waiting additional time...');
            await delay(TIMING.UI_STABILIZE_DELAY_MS);
          }
        }
      }
      if (options.temperature !== undefined) {
        await this.setTemperature(options.temperature);
      }
      if (options.topP !== undefined) {
        await this.setTopP(options.topP);
      }
      if (options.thinkingBudget !== undefined) {
        await this.setThinkingBudget(options.thinkingBudget);
      }
      const advancedOptions = {
        useWebSearch: options.useWebSearch,
        disableThinking: options.disableThinking,
        urlContext: options.urlContext,
      };
      if (Object.values(advancedOptions).some(v => v !== undefined)) {
        await this.setAdvancedOptions(advancedOptions, options.model);
      }
    } finally {
      await this.closeSettingsPanel();
    }
  }

  // --- Private Helper Methods ---

  /**
   * Proactively dismisses known overlays and dialogs that might occlude UI elements.
   * This is called before critical actions to ensure the UI path is clear.
   * Uses synchronous DOM queries for speed and doesn't fail if dialogs aren't present.
   */
  private async _dismissOverlays(): Promise<void> {
    console.log('[AI Studio] Proactively dismissing known overlays...');
    // WHY: Clear any CDK overlay backdrops that might occlude UI elements.
    try {
      document.querySelectorAll('.cdk-overlay-backdrop').forEach(overlay => {
        const element = overlay as HTMLElement;
        element.click();
        element.style.pointerEvents = 'none';
      });
    } catch {
      // Ignore errors if overlays are not present
    }
    const clickIfExists = async (selector: string, description: string) => {
      try {
        const element = document.querySelector(selector) as HTMLElement | null;
        if (element && element.offsetParent !== null) {
          console.log(`[AI Studio] Found and clicking overlay: "${description}"`);
          element.click();
          await delay(500);
        }
      } catch (error) {
        console.warn(`[AI Studio] Could not dismiss overlay "${description}":`, error);
      }
    };
    await clickIfExists(SELECTORS.AUTOSAVE_DIALOG_BUTTON, 'Auto-save Dialog');
    await clickIfExists(SELECTORS.COOKIE_CONSENT_BUTTON, 'Cookie Banner');
    try {
      document.querySelectorAll('.cdk-overlay-backdrop').forEach(overlay => {
        const element = overlay as HTMLElement;
        element.click();
        element.style.pointerEvents = 'none';
      });
      await delay(500);
    } catch {
      // Ignore errors if overlays are not present
    }
  }

  private getPageStateContext(): string {
    const visibleElements = document.querySelectorAll('*').length;
    return `URL=${window.location.href}, ReadyState=${document.readyState}, VisibleElements=${visibleElements}`;
  }

  // WHY: Creates an error with contextual information for better debugging
  createErrorWithContext(operation: string, message: string, additionalContext?: string): Error {
    const context = this.getPageStateContext();
    const fullContext = additionalContext ? `${context}, ${additionalContext}` : context;
    return new Error(`${operation} failed: ${message}\nContext: ${fullContext}`);
  }

  // --- Public Chatbot Interface Implementation ---

  async resetState(): Promise<void> {
    console.log('[AI Studio] Preparing to reset UI state...');
    try {
      const settingsToggleSelector = Array.isArray(SELECTORS.SETTINGS_PANEL_MOBILE_TOGGLE)
        ? SELECTORS.SETTINGS_PANEL_MOBILE_TOGGLE[0]
        : SELECTORS.SETTINGS_PANEL_MOBILE_TOGGLE;
      const oldSettingsButton = settingsToggleSelector ? document.querySelector(settingsToggleSelector) : null;
      const newChatButton = document.querySelector(SELECTORS.NEW_CHAT_BUTTON) as HTMLElement;
      if (!newChatButton || newChatButton.offsetParent === null) {
        console.warn('[AI Studio] "New Chat" button not found, assuming clean state and proceeding.');
        await this.waitForReady();
        return;
      }
      newChatButton.click();
      console.log('[AI Studio] "New Chat" clicked. Waiting for UI transition...');
      if (oldSettingsButton) {
        const timeout = getModifiedTimeout(5000);
        const startTime = Date.now();
        while (document.body.contains(oldSettingsButton)) {
          if (Date.now() - startTime > timeout) {
            throw this.createErrorWithContext(
              'resetState',
              'Old settings button did not disappear within timeout.',
              `Timeout=${timeout}ms`,
            );
          }
          await delay(50);
        }
        console.log('[AI Studio] Old UI elements have been removed.');
      }
      await this.waitForReady();
      console.log('[AI Studio] State reset completed successfully.');
    } catch (error) {
      console.error(
        '[AI Studio] A non-critical error occurred during state reset. Continuing under assumption that UI is ready.',
        error,
      );
      await this.waitForReady();
    }
  }

  async waitForReady(): Promise<void> {
    await this._dismissOverlays();
    await waitForActionableElement<HTMLElement>(SELECTORS.PROMPT_INPUTS, 'Prompt Input Area');
    console.log('[AI Studio] UI is fully actionable and ready (prompt input is available).');
    await delay(TIMING.UI_STABILIZE_DELAY_MS);
  }

  private async _waitForResponseFinalization(): Promise<void> {
    console.log('[AI Studio] Now waiting for AI response to finalize...');
    return new Promise((resolve, reject) => {
      const timeout = getModifiedTimeout(TIMING.FINALIZED_TURN_TIMEOUT_MS);
      const EDIT_BUTTON_SELECTOR = Array.isArray(SELECTORS.EDIT_BUTTON)
        ? SELECTORS.EDIT_BUTTON.join(',')
        : SELECTORS.EDIT_BUTTON;
      const CHAT_TURN_SELECTOR = Array.isArray(SELECTORS.CHAT_TURN)
        ? SELECTORS.CHAT_TURN.join(',')
        : SELECTORS.CHAT_TURN;

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
      // WHY: Hard timeout so automation can't hang indefinitely while waiting for UI events.
      // eslint-disable-next-line custom/disallow-timeout-for-waits
      const timeoutId = setTimeout(() => {
        observer.disconnect();
        // WHY: Enhanced error message with diagnostic information to help debug timeout issues
        const allTurns = document.querySelectorAll(CHAT_TURN_SELECTOR);
        const allEditButtons = document.querySelectorAll(EDIT_BUTTON_SELECTOR);
        const diagnosticInfo = `Turns found: ${allTurns.length}, Edit buttons found: ${allEditButtons.length}, URL: ${window.location.href}`;
        reject(new Error(`Timed out after ${timeout}ms waiting for response to finalize. ${diagnosticInfo}`));
      }, timeout);

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
        payload: 'User needs to sign in to Google Account',
      });
      return new Promise(() => {});
    }

    try {
      const inputAreaEl = await waitForActionableElement<HTMLTextAreaElement | HTMLInputElement>(
        SELECTORS.PROMPT_INPUTS,
        'Prompt input area',
        getModifiedTimeout(DEFAULT_TIMEOUT_MS),
        2,
      );
      if (inputAreaEl instanceof HTMLTextAreaElement || inputAreaEl instanceof HTMLInputElement) {
        inputAreaEl.value = prompt;
        inputAreaEl.dispatchEvent(new Event('input', { bubbles: true }));
        inputAreaEl.dispatchEvent(new Event('change', { bubbles: true }));
        console.log('[AI Studio LOG] Prompt entered into input area, waiting for token count update...');
      } else {
        const elementType = inputAreaEl ? (inputAreaEl as HTMLElement).constructor.name : 'null';
        throw this.createErrorWithContext(
          'sendPrompt',
          'Input area is not a valid textarea or input element.',
          `ElementType=${elementType}`,
        );
      }

      await new Promise<void>((resolve, reject) => {
        const timeout = getModifiedTimeout(TIMING.TOKEN_COUNT_UPDATE_TIMEOUT_MS);
        const startTime = Date.now();

        const checkTokenCount = () => {
          const elapsed = Date.now() - startTime;
          if (elapsed > timeout) {
            reject(new Error(`Token count did not update within ${timeout}ms.`));
            return;
          }

          const tokenCountElement = document.querySelector(SELECTORS.TOKEN_COUNT);
          const text = tokenCountElement?.textContent?.trim();
          if (text && !text.startsWith('0')) {
            console.log(`[AI Studio LOG] Token count updated: ${text}`);
            resolve();
          } else {
            // WHY: Poll token counter because UI does not provide actionable hook while typing.
            // eslint-disable-next-line custom/disallow-timeout-for-waits
            setTimeout(checkTokenCount, TIMING.TOKEN_COUNT_CHECK_INTERVAL_MS);
          }
        };
        checkTokenCount();
      });
      await delay(TIMING.UI_STABILIZE_AFTER_TOKEN_COUNT_MS);
      console.log('[AI Studio LOG] UI stabilized after token count, proceeding to send.');
      await this.closeSettingsPanel();

      await retryOperation(async () => {
        const sendButtonEl = await waitForActionableElement<HTMLElement>(
          SELECTORS.SEND_BUTTONS,
          'Send button',
          getModifiedTimeout(DEFAULT_TIMEOUT_MS),
          2,
        );
        const sendButton = assertIsElement(sendButtonEl, HTMLElement, 'Send button');
        sendButton.click();
        console.log('[AI Studio LOG] Send button clicked successfully.');
      }, 'sendPrompt (click send button)', 2, 300);

      await this._waitForResponseFinalization();
    } catch (error) {
      throw this.createErrorWithContext(
        'sendPrompt',
        `Failed to send prompt: ${error instanceof Error ? error.message : String(error)}`,
        `PromptLength=${prompt.length}`,
      );
    }
  }

  private findTurnContainerFromEditButton(editButton: HTMLElement): HTMLElement | null {
    const CHAT_TURN_SELECTOR = Array.isArray(SELECTORS.CHAT_TURN)
      ? SELECTORS.CHAT_TURN.join(',')
      : SELECTORS.CHAT_TURN;
    const turnContainer = editButton.closest(CHAT_TURN_SELECTOR);
    return turnContainer as HTMLElement | null;
  }

  async extractResponse(): Promise<string> {
    console.log(
      `[AI Studio LOG] Starting extraction process... (timeout: ${TIMING.FINALIZED_TURN_TIMEOUT_MS}ms)`,
    );
    const waitForFinalizedTurn = (
      timeout = TIMING.FINALIZED_TURN_TIMEOUT_MS,
    ): Promise<{ turn: HTMLElement; editButton: HTMLElement }> => {
      return new Promise((resolve, reject) => {
        const EDIT_BUTTON_SELECTOR = Array.isArray(SELECTORS.EDIT_BUTTON)
          ? SELECTORS.EDIT_BUTTON.join(',')
          : SELECTORS.EDIT_BUTTON;
        let observer: MutationObserver | null = null;
        let timeoutId: number | null = null;
        const cleanup = () => {
          if (observer) observer.disconnect();
          if (timeoutId) clearTimeout(timeoutId);
        };
        const check = () => {
          const allEditButtons = document.querySelectorAll(EDIT_BUTTON_SELECTOR);
          if (allEditButtons.length === 0) {
            return;
          }
          const lastEditButton = allEditButtons[allEditButtons.length - 1] as HTMLElement;
          const candidateTurn = this.findTurnContainerFromEditButton(lastEditButton);
          if (candidateTurn) {
            const hasStopEditingButton = candidateTurn.querySelector('button[aria-label="Stop editing"]');

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
          attributeFilter: ['aria-label', 'disabled'],
        });
        // WHY: Abort extraction if UI never exposes a finalized edit button, preventing infinite waits.
        // eslint-disable-next-line custom/disallow-timeout-for-waits
        timeoutId = window.setTimeout(() => {
          cleanup();
          const allEditButtons = document.querySelectorAll(EDIT_BUTTON_SELECTOR);
          const errorMessage = `Extraction timed out. Final state: ${allEditButtons.length} edit buttons found.`;
          console.error(`[AI Studio LOG] ${errorMessage}`);
          reject(new Error(errorMessage));
        }, timeout);
        check();
      });
    };

    const { turn: lastTurn, editButton: editButtonToClick } = await waitForFinalizedTurn();
    console.log('[AI Studio LOG] Finalized turn found, clicking edit button...');

    editButtonToClick.click();

    console.log('[AI Studio LOG] Waiting for textarea to appear...');
    const textarea = await waitForElementWithin<HTMLTextAreaElement | HTMLDivElement>(
      lastTurn,
      SELECTORS.EDIT_TEXTAREA,
      TIMING.TEXTAREA_APPEAR_TIMEOUT_MS,
    );

    console.log('[AI Studio LOG] Textarea appeared, waiting for UI to stabilize...');
    await delay(TIMING.UI_STABILIZE_DELAY_MS);
    let extractedContent =
      ((textarea as HTMLTextAreaElement).value ?? (textarea as HTMLElement).innerText ?? '').trim();
    if (!extractedContent) {
      const fallbackRaw = lastTurn?.innerText?.trim() ?? '';
      if (fallbackRaw) {
        console.log(`[AI Studio LOG] Primary textarea empty, using fallback turn text (${fallbackRaw.length} chars).`);
        extractedContent = fallbackRaw;
      }
    }
    if (!extractedContent) {
      const errorMessage = `Extraction failed: Textarea and fallback turn content were empty.`;
      console.error(`[AI Studio LOG] ${errorMessage}`);
      throw this.createErrorWithContext('extractResponse', errorMessage, 'No content available for extraction after fallback');
    }

    console.log(`[AI Studio LOG] Extracted ${extractedContent.length} chars successfully.`);
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

  async openSettingsPanel(): Promise<void> {
    await this._dismissOverlays();
    if (window.innerWidth <= CONFIG.SCREEN_WIDTH_BREAKPOINT_PX) {
      if (document.querySelector(SELECTORS.SETTINGS_PANEL_CLOSE_BUTTON)) {
        console.log('[AI Studio LOG] Settings panel is already open.');
        await delay(TIMING.UI_STABILIZE_DELAY_MS);
        return;
      }
      try {
        const tuneButtonEl = await waitForActionableElement<HTMLButtonElement>(
          Array.isArray(SELECTORS.SETTINGS_PANEL_MOBILE_TOGGLE)
            ? SELECTORS.SETTINGS_PANEL_MOBILE_TOGGLE
            : [SELECTORS.SETTINGS_PANEL_MOBILE_TOGGLE],
          'Settings panel toggle button',
          getModifiedTimeout(DEFAULT_TIMEOUT_MS),
          2,
        );
        const tuneButton = assertIsElement(tuneButtonEl, HTMLButtonElement, 'Settings panel toggle button');
        tuneButton.click();
        const settingsPanel = document
          .querySelector(SELECTORS.SETTINGS_PANEL_CLOSE_BUTTON)
          ?.closest('ms-run-settings') as HTMLElement | null;
        if (settingsPanel) {
          await waitForAnimationEnd(settingsPanel, getModifiedTimeout(TIMING.PANEL_ANIMATION_MS));
        } else {
          await delay(TIMING.PANEL_ANIMATION_MS);
        }
        await delay(TIMING.UI_STABILIZE_DELAY_MS);
        console.log('[AI Studio LOG] Settings panel opened successfully.');
      } catch (error) {
        throw this.createErrorWithContext(
          'openSettingsPanel',
          `Failed to open settings panel: ${error instanceof Error ? error.message : String(error)}`,
        );
      }
    }
  }

  async closeSettingsPanel(): Promise<void> {
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
          0,
        );
        const closeButton = assertIsElement(closeButtonEl, HTMLButtonElement, 'Settings panel close button');
        const settingsPanel = closeButton.closest('ms-run-settings') as HTMLElement | null;
        closeButton.click();
        if (settingsPanel) {
          await waitForAnimationEnd(settingsPanel, getModifiedTimeout(TIMING.PANEL_ANIMATION_MS));
        } else {
          await delay(TIMING.PANEL_ANIMATION_MS);
        }
        console.log('[AI Studio LOG] Settings panel closed successfully.');
      } catch (error) {
        console.warn('[AI Studio LOG] Could not close settings panel, but continuing:', error);
      }
    }
  }
}

// Export class and instance for backward compatibility
export const aiStudioChatbot = new AiStudioChatbot();

