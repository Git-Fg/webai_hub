// ts_src/types/chatbot.ts

// WHY: Defines a strong type for the options passed from Dart.
// This improves type safety and autocompletion when implementing a new chatbot.
export interface AutomationOptions {
  providerId: string;
  prompt: string;
  model?: string;
  systemPrompt?: string;
  temperature?: number;
  topP?: number;
  thinkingBudget?: number;
  useWebSearch?: boolean;
  disableThinking?: boolean;
  urlContext?: boolean;
  timeoutModifier?: number;
}

/**
 * Interface describing the core capabilities of a chatbot module.
 * 
 * **Best Practices:**
 * 
 * - **Sequence:** Implementations should follow the "Prepare Environment, then Act" principle.
 *   All configuration (model, settings) should be done before interacting with the prompt input.
 * 
 * - **Actionability:** Always use `waitForActionableElement` before critical interactions.
 * 
 * - **Mobile Performance:** Follow "Observe Narrowly, Process Lightly" principles.
 * 
 * @see BLUEPRINT_FULL.md §4.10 for comprehensive documentation on selector strategies and waiting patterns.
 */
export interface Chatbot {
  /**
   * (Optional) Resets the web UI to a clean state, ready for a new prompt.
   * Typically involves clicking a "New Chat" button. If not implemented,
   * the engine assumes the UI is already in a clean state.
   */
  resetState?: () => Promise<void>;

  /**
   * Waits until the chatbot page is fully loaded and ready for automation.
   * 
   * **Implementation Notes:**
   * - Should wait for a stable element that appears only when the page is fully ready
   * - Use `waitForElement` with selectors following the Priority Pyramid
   * - Prefer ARIA labels or stable IDs over auto-generated classes
   */
  waitForReady: () => Promise<void>;

  /**
   * Applies all model and run configurations in a single, efficient operation.
   * This method should handle opening and closing any necessary settings panels.
   * 
   * **Implementation Notes:**
   * - Should minimize panel open/close cycles for performance
   * - Use `waitForActionableElement` before all interactions (clicks, value setting)
   * - Handle mobile vs desktop UI differences if applicable
   * 
   * @param options The full set of automation options from Dart.
   */
  applyAllSettings?: (options: AutomationOptions) => Promise<void>;

  /**
   * Enters a system prompt or instructions for the AI model.
   * 
   * **Implementation Notes:**
   * - May open a separate dialog/modal
   * - Use `waitForActionableElement` before interacting with input fields
   * - Ensure proper cleanup (close dialogs) after setting
   * 
   * @param systemPrompt The instructions to provide.
   */
  setSystemPrompt?: (systemPrompt: string) => Promise<void>;

  /**
   * Finds the input area, inserts the prompt, clicks submit, AND
   * WAITS until the AI response is fully generated and ready for extraction.
   * This is a long-running method that resolves only upon completion.
   * 
   * **Implementation Notes:**
   * - Use `waitForActionableElement` for both input field and submit button
   * - Wait for token count or similar indicator that input was processed
   * - Handle login page detection and notify Dart appropriately
   * - After clicking send, must wait for response finalization (e.g., presence of "Edit" button)
   * - This method should NOT return until the response is ready for extraction
   * 
   * @param prompt The message to send.
   */
  sendPrompt: (prompt: string) => Promise<void>;

  /**
   * Extracts the cleaned text of the latest model response.
   * This is called AFTER `sendPrompt` has successfully resolved.
   * 
   * **Implementation Notes:**
   * - Use "reliable-to-uncertain" strategy: find stable button (e.g., "Edit"), traverse up to container
   * - The response should already be finalized when this is called (sendPrompt handles waiting)
   * - Use `waitForElementWithin` to scope searches to specific containers
   * - Handle extraction errors gracefully (return partial results if possible)
   * 
   * @returns The extracted response text
   */
  extractResponse: () => Promise<string>;

  // REMOVED: This method is no longer required.
  // waitForResponse: (timeout: number) => Promise<void>;
}

