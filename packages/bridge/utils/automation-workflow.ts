// ts_src/utils/automation-workflow.ts

import { Chatbot, AutomationOptions } from '../types/chatbot';
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
    currentPhase = 'Phase 3: Applying configurations';
    console.log(`[Engine LOG] ${currentPhase}...`);
    if (chatbot.applyAllSettings) {
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

    // Check if it's our custom error and add its diagnostics
    // WHY: This explicit check allows us to destructure the custom error and enrich
    // the diagnostic payload sent to Dart for better debugging.
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    if (error instanceof Error && (error as any).name === 'ActionabilityError') {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      diagnostics.actionability = (error as any).diagnostics;
    }

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

