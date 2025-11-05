// ts_src/types/chatbot.ts

// Interface describing the core capabilities of a chatbot module.
// For the MVP, we focus on the essentials only.
export interface Chatbot {
  /**
   * Waits until the chatbot page is fully loaded and ready for automation.
   */
  waitForReady: () => Promise<void>;

  /**
   * Finds the input area, inserts the prompt, and clicks the submit button.
   * Resolves only after the response generation is complete.
   * @param prompt The message to send.
   */
  sendPrompt: (prompt: string) => Promise<void>;

  /**
   * Extracts the cleaned text of the latest model response.
   */
  extractResponse: () => Promise<string>;

  // REMOVED: This method is no longer required.
  // waitForResponse: (timeout: number) => Promise<void>;
}

