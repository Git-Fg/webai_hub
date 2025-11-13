// ts_src/types/global.d.ts

declare global {
  interface Window {
    /** A flag for idempotent script injection. Set to `true` after first init. */
    __AI_HYBRID_HUB_INITIALIZED__?: boolean;

    /** User-configurable multiplier for all automation timeouts. */
    __AI_TIMEOUT_MODIFIER__?: number;

    /** Internal counter for tracking processed response footers. */
    __processedFootersCount?: number;

    /** Flag to prevent infinite retry loops for transient errors. */
    __hasAttemptedRetry?: boolean;

    /** Entry point for automation. Called from Dart. */
    startAutomation: (
      providerId: string,
      prompt: string,
      settingsJson: string,
      timeoutModifier: number
    ) => Promise<void>;

    /** Extracts the final response text. Called from Dart. */
    extractFinalResponse: () => Promise<string>;

    /** Triggers DOM analysis for debugging. Called from Dart. */
    inspectDOMForSelectors: () => Record<string, unknown>;

    /** The communication bridge injected by `flutter_inappwebview`. */
    flutter_inappwebview?: {
      callHandler(handlerName: string, ...args: unknown[]): Promise<unknown>;
    };
  }
}

export {}; // Required to make this a module.

