// ts_src/utils/timeout.ts

// WHY: Global timeout modifier allows user-configurable scaling of all automation timeouts.
// This makes the automation engine adaptable to slower devices and network conditions.
declare global {
  interface Window {
    __AI_TIMEOUT_MODIFIER__?: number;
  }
}

/**
 * Applies the global timeout modifier to a default timeout value.
 * 
 * The modifier is set by the automation engine when startAutomation is called,
 * based on the user's settings in the Dart app. Defaults to 1.0 if not set.
 * 
 * @param defaultTimeout The base timeout value in milliseconds
 * @returns The modified timeout value (defaultTimeout * modifier)
 */
export function getModifiedTimeout(defaultTimeout: number): number {
  const modifier = window.__AI_TIMEOUT_MODIFIER__ ?? 1.0;
  return defaultTimeout * modifier;
}

