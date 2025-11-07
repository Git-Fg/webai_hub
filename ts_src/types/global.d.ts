// ts_src/types/global.d.ts
import { AutomationOptions } from './chatbot';

declare global {
  interface Window {
    /** A flag for idempotent script injection. Set to `true` after first init. */
    __AI_HYBRID_HUB_INITIALIZED__?: boolean;

    /** Entry point for automation. Called from Dart. */
    startAutomation: (options: AutomationOptions) => Promise<void>;

    /** Extracts the final response text. Called from Dart. */
    extractFinalResponse: () => Promise<string>;

    /** Triggers DOM analysis for debugging. Called from Dart. */
    inspectDOMForSelectors: () => Record<string, unknown>;
    
    /** Starts a MutationObserver to watch for new responses. Called from Dart. */
    startResponseObserver: () => void;

    /** The communication bridge injected by `flutter_inappwebview`. */
    flutter_inappwebview?: {
      callHandler(handlerName: string, ...args: unknown[]): void;
    };
  }
}

export {}; // Required to make this a module.

