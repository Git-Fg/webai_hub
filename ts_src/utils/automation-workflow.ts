// ts_src/utils/automation-workflow.ts

import { Chatbot, AutomationOptions } from '../types/chatbot';
import { AiStudioChatbot } from '../chatbots/ai-studio';
import { notifyDart } from './notify-dart';
import { EVENT_TYPE_AUTOMATION_FAILED, EVENT_TYPE_NEW_RESPONSE } from './bridge-constants';

/**
 * Runs the complete chatbot automation workflow.
 * 
 * This function encapsulates the common sequence of:
 * 1. Reset state (if exists)
 * 2. Wait for ready
 * 3. Apply all settings
 * 4. Send prompt
 * 
 * It includes centralized error handling, phase tracking, and Dart notifications.
 * 
 * @param chatbot The chatbot instance to run the workflow for
 * @param options The automation options from Dart
 * @throws Error if any phase fails
 */
export async function runChatbotWorkflow(
  chatbot: Chatbot,
  options: AutomationOptions
): Promise<void> {
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

    // Phase 3: Apply all configurations (System Prompt, Model, Temperature, etc.).
    // WHY: System prompt must be set FIRST as a separate operation because it opens/closes
    // its own settings panel and dialog. Then applyAllSettings is called separately
    // to set model, temperature, etc. This matches the old working logic.
    currentPhase = 'Phase 3: Applying configurations';
    console.log(`[Engine LOG] ${currentPhase}...`);
    // Check if the chatbot is an instance of AiStudioChatbot
    if (chatbot instanceof AiStudioChatbot) {
      // Step 3a: Set system prompt FIRST (handles its own panel open/close)
      if (options.systemPrompt) {
        console.log(`[Engine LOG] Setting system prompt (length: ${options.systemPrompt.length})`);
        await chatbot.settingsManager.setSystemPrompt(options.systemPrompt);
      }
      // Step 3b: Apply all other settings AFTER (handles its own panel open/close)
      // WHY: Exclude systemPrompt from applyAllSettings since it's already handled above
      const settingsWithoutSystemPrompt: AutomationOptions = {
        ...options,
        systemPrompt: undefined, // Exclude system prompt from applyAllSettings
      };
      await chatbot.settingsManager.applyAllSettings(settingsWithoutSystemPrompt);
    } else if (chatbot.applyAllSettings) {
      // WHY: For other chatbots (like Kimi), applyAllSettings is called directly
      // if the method exists. Kimi doesn't have a separate system prompt step.
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
      location: 'runChatbotWorkflow',
      payload: errorMessage,
      diagnostics: diagnostics,
    });
    // WHY: Re-throw error so the Future in Dart also fails
    throw error;
  }
}

