// ts_src/utils/wait-for-actionable-element.ts

import { getModifiedTimeout } from './timeout';

// NOTE: waitForElement and waitForElementWithin are imported for potential future use
// but currently not used in this file

const DEFAULT_TIMEOUT_MS = 10000;
const DEFAULT_RETRIES = 2;
const DEFAULT_ANIMATION_TIMEOUT_MS = 1000; // Max time to wait for animations to finish
const PROGRESS_LOG_INTERVAL_MS = 2000;

interface ActionabilityDiagnostics {
  attached: boolean;
  visible: boolean;
  stable: boolean;
  enabled: boolean;
  unoccluded: boolean;
  details: {
    isConnected?: boolean;
    checkVisibilityResult?: boolean;
    offsetParent?: Element | null;
    animationsCount?: number;
    disabled?: boolean;
    ariaDisabled?: string | null;
    inert?: boolean;
    occludingElement?: Element | null;
  };
}

/**
 * Checks if an element is attached to the DOM.
 */
function isAttached(element: Element): boolean {
  return element.isConnected === true;
}

/**
 * Checks if an element is visible using modern API or fallback.
 */
function isVisible(element: HTMLElement): boolean {
  // WHY: Use modern checkVisibility API if available (better than offsetParent)
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  if (typeof (element as any).checkVisibility === 'function') {
    try {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      return (element as any).checkVisibility({ checkOpacity: true, checkVisibilityCSS: true });
    } catch {
      // Fallback if API exists but throws
    }
  }
  
  // Fallback: offsetParent is null for hidden elements
  return element.offsetParent !== null;
}

/**
 * Checks if an element has no ongoing animations.
 * Returns a promise that resolves when animations are stable.
 */
async function isStable(element: HTMLElement, timeoutMs: number = DEFAULT_ANIMATION_TIMEOUT_MS): Promise<boolean> {
  try {
    // WHY: getAnimations() returns all active animations on the element
    const animations = element.getAnimations();
    
    if (animations.length === 0) {
      return true;
    }
    
    // WHY: Wait for all animations to finish, but with timeout to prevent infinite waits
    const animationPromises = animations.map(anim => anim.finished);
    await Promise.race([
      Promise.all(animationPromises),
      new Promise<void>((resolve) => setTimeout(resolve, timeoutMs))
    ]);
    
    // Check again - if still animating after timeout, consider it unstable
    const remainingAnimations = element.getAnimations();
    return remainingAnimations.length === 0;
  } catch {
    // If getAnimations is not available or throws, assume stable
    return true;
  }
}

/**
 * Checks if an element is enabled (not disabled or inert).
 */
function isEnabled(element: HTMLElement): boolean {
  // Check disabled attribute
  if ((element as HTMLButtonElement | HTMLInputElement).disabled === true) {
    return false;
  }
  
  // Check aria-disabled
  const ariaDisabled = element.getAttribute('aria-disabled');
  if (ariaDisabled === 'true') {
    return false;
  }
  
  // Check inert attribute (modern API)
  if (element.hasAttribute('inert')) {
    return false;
  }
  
  // Check if element is inside an inert container
  let parent: HTMLElement | null = element.parentElement;
  while (parent) {
    if (parent.hasAttribute('inert')) {
      return false;
    }
    parent = parent.parentElement;
  }
  
  return true;
}

/**
 * Checks if an element is not occluded by another element.
 * Uses elementFromPoint to verify the element is actually clickable.
 */
function isUnoccluded(element: HTMLElement): boolean {
  try {
    const rect = element.getBoundingClientRect();
    
    // WHY: Check center point of element
    const centerX = rect.left + rect.width / 2;
    const centerY = rect.top + rect.height / 2;
    
    // WHY: elementFromPoint returns the topmost element at coordinates
    const topElement = document.elementFromPoint(centerX, centerY);
    
    if (!topElement) {
      return false;
    }
    
    // WHY: Check if the element itself or one of its children is at the point
    return element.contains(topElement) || topElement === element;
    } catch {
      // If getBoundingClientRect or elementFromPoint fails, assume unoccluded
      return true;
    }
}

/**
 * Performs comprehensive actionability check on an element.
 * Returns diagnostics for debugging.
 */
async function checkActionability(
  element: Element,
  timeoutMs: number = DEFAULT_ANIMATION_TIMEOUT_MS
): Promise<{ actionable: boolean; diagnostics: ActionabilityDiagnostics }> {
  const htmlElement = element as HTMLElement;
  
  const diagnostics: ActionabilityDiagnostics = {
    attached: false,
    visible: false,
    stable: false,
    enabled: false,
    unoccluded: false,
    details: {},
  };
  
  // Check 1: Attached
  diagnostics.attached = isAttached(element);
  diagnostics.details.isConnected = element.isConnected;
  
  if (!diagnostics.attached) {
    return { actionable: false, diagnostics };
  }
  
  // Check 2: Visible
  diagnostics.visible = isVisible(htmlElement);
  try {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    if (typeof (htmlElement as any).checkVisibility === 'function') {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      diagnostics.details.checkVisibilityResult = (htmlElement as any).checkVisibility({ 
        checkOpacity: true, 
        checkVisibilityCSS: true 
      });
    }
  } catch {
    // Ignore
  }
  diagnostics.details.offsetParent = htmlElement.offsetParent;
  
  if (!diagnostics.visible) {
    return { actionable: false, diagnostics };
  }
  
  // Check 3: Stable (async)
  diagnostics.stable = await isStable(htmlElement, timeoutMs);
  try {
    const animations = htmlElement.getAnimations();
    diagnostics.details.animationsCount = animations.length;
  } catch {
    // Ignore
  }
  
  if (!diagnostics.stable) {
    return { actionable: false, diagnostics };
  }
  
  // Check 4: Enabled
  diagnostics.enabled = isEnabled(htmlElement);
  diagnostics.details.disabled = (htmlElement as HTMLButtonElement | HTMLInputElement).disabled;
  diagnostics.details.ariaDisabled = htmlElement.getAttribute('aria-disabled');
  diagnostics.details.inert = htmlElement.hasAttribute('inert');
  
  if (!diagnostics.enabled) {
    return { actionable: false, diagnostics };
  }
  
  // Check 5: Unoccluded
  diagnostics.unoccluded = isUnoccluded(htmlElement);
  if (!diagnostics.unoccluded) {
    try {
      const rect = htmlElement.getBoundingClientRect();
      const centerX = rect.left + rect.width / 2;
      const centerY = rect.top + rect.height / 2;
      diagnostics.details.occludingElement = document.elementFromPoint(centerX, centerY);
    } catch {
      // Ignore
    }
  }
  
  const actionable = diagnostics.attached && diagnostics.visible && 
                     diagnostics.stable && diagnostics.enabled && diagnostics.unoccluded;
  
  return { actionable, diagnostics };
}

/**
 * Formats error message with actionability diagnostics.
 */
function formatActionabilityError(
  selectors: readonly string[],
  timeout: number,
  diagnostics: ActionabilityDiagnostics,
  elementName: string = 'element'
): string {
  const failures: string[] = [];
  if (!diagnostics.attached) failures.push('not attached to DOM');
  if (!diagnostics.visible) failures.push('not visible');
  if (!diagnostics.stable) failures.push('has ongoing animations');
  if (!diagnostics.enabled) failures.push('disabled or inert');
  if (!diagnostics.unoccluded) failures.push('occluded by another element');
  
  const pageState = {
    url: window.location.href,
    readyState: document.readyState,
    visibleElements: document.querySelectorAll('*').length,
  };
  
  return `${elementName} is not actionable: ${failures.join(', ')}
Selectors: [${selectors.join(', ')}]
Timeout: ${timeout}ms
Diagnostics: ${JSON.stringify(diagnostics.details, null, 2)}
Page State: URL=${pageState.url}, ReadyState=${pageState.readyState}, VisibleElements=${pageState.visibleElements}`;
}

/**
 * Waits for an element to be actionable (ready for interaction).
 * Implements comprehensive 5-point check: Attached, Visible, Stable, Enabled, Unoccluded.
 * 
 * @param selectors Array of CSS selectors to try (in order)
 * @param elementName Human-readable name for error messages
 * @param timeout Maximum time to wait in milliseconds
 * @param root Optional root node to search within
 * @returns Promise resolving to an actionable HTMLElement
 */
async function waitForActionableElementInternal<T extends HTMLElement = HTMLElement>(
  selectors: readonly string[],
  elementName: string,
  timeout: number,
  root?: ParentNode
): Promise<T> {
  const startTime = Date.now();
  let lastProgressLogTime = 0;
  
  console.log(`[waitForActionableElement] Starting search for actionable ${elementName} with selectors: [${selectors.join(', ')}] (timeout: ${timeout}ms)`);
  
  // WHY: Use MutationObserver for event-driven waiting instead of polling
  return new Promise((resolve, reject) => {
    let observer: MutationObserver | null = null;
    let timeoutId: number | null = null;
    let checkInterval: number | null = null;
    
    const cleanup = () => {
      if (observer) {
        observer.disconnect();
        observer = null;
      }
      if (timeoutId !== null) {
        clearTimeout(timeoutId);
        timeoutId = null;
      }
      if (checkInterval !== null) {
        clearInterval(checkInterval);
        checkInterval = null;
      }
    };
    
    const checkActionabilityForSelectors = async () => {
      const elapsed = Date.now() - startTime;
      
      // Log progress periodically
      if (elapsed - lastProgressLogTime >= PROGRESS_LOG_INTERVAL_MS) {
        console.log(`[waitForActionableElement] Still checking actionability for ${elementName}... (elapsed: ${elapsed}ms)`);
        lastProgressLogTime = elapsed;
      }
      
      for (const selector of selectors) {
        if (!selector) continue;
        
        let element: Element | null = null;
        
        try {
          if (root) {
            element = (root as Element | Document).querySelector(selector);
          } else {
            element = document.querySelector(selector);
          }
        } catch (e) {
          console.warn(`[waitForActionableElement] Invalid selector "${selector}":`, e);
          continue;
        }
        
        if (element) {
          const { actionable, diagnostics } = await checkActionability(element as HTMLElement);
          
          if (actionable) {
            const actualTime = Date.now() - startTime;
            console.log(`[waitForActionableElement] Found actionable ${elementName} with selector "${selector}" after ${actualTime}ms`);
            cleanup();
            resolve(element as T);
            return;
          } else {
            // Element exists but not actionable - log diagnostics
            console.log(`[waitForActionableElement] Element found but not actionable: ${JSON.stringify(diagnostics.details)}`);
          }
        }
      }
      
      // Check timeout
      if (elapsed >= timeout) {
        cleanup();
        // Try one final check to get diagnostics
        let finalElement: Element | null = null;
        for (const selector of selectors) {
          try {
            if (root) {
              finalElement = (root as Element | Document).querySelector(selector);
            } else {
              finalElement = document.querySelector(selector);
            }
            if (finalElement) break;
          } catch {
            // Ignore
          }
        }
        
        if (finalElement) {
          const { diagnostics } = await checkActionability(finalElement as HTMLElement);
          reject(new Error(formatActionabilityError(selectors, timeout, diagnostics, elementName)));
        } else {
          reject(new Error(`waitForActionableElement failed: None of the selectors [${selectors.join(', ')}] found within ${timeout}ms`));
        }
      }
    };
    
    // WHY: Use MutationObserver for event-driven detection (primary strategy)
    if (typeof MutationObserver !== 'undefined') {
      observer = new MutationObserver(() => {
        checkActionabilityForSelectors();
      });
      
      const observeTarget = root || document.body;
      observer.observe(observeTarget, { 
        childList: true, 
        subtree: true,
        attributes: true, // WHY: Watch for attribute changes (disabled, inert, etc.)
        attributeFilter: ['disabled', 'aria-disabled', 'inert', 'style', 'class'] // WHY: Filter to relevant attributes for performance
      });
      
      // WHY: Check immediately in case element already exists
      checkActionabilityForSelectors();
    } else {
      // Fallback: Polling if MutationObserver not available
      console.warn('[waitForActionableElement] MutationObserver not available, using polling fallback');
      checkInterval = window.setInterval(checkActionabilityForSelectors, 100);
      checkActionabilityForSelectors();
    }
    
    // Set timeout
    timeoutId = window.setTimeout(() => {
      cleanup();
      checkActionabilityForSelectors();
    }, timeout);
  });
}

/**
 * Waits for an element to be actionable (ready for interaction).
 * 
 * @param selectors Array of CSS selectors to try (in order)
 * @param elementName Human-readable name for error messages (e.g., "Send button")
 * @param timeout Maximum time to wait in milliseconds (default: 10000)
 * @param retries Number of retry attempts (default: 2)
 * @returns Promise resolving to an actionable HTMLElement
 */
export function waitForActionableElement<T extends HTMLElement = HTMLElement>(
  selectors: readonly string[],
  elementName: string = 'element',
  timeout: number = DEFAULT_TIMEOUT_MS,
  retries: number = DEFAULT_RETRIES
): Promise<T> {
  // Apply the modifier to the timeout before passing it to the internal function
  const modifiedTimeout = getModifiedTimeout(timeout);
  return retryOperation(
    () => waitForActionableElementInternal<T>(selectors, elementName, modifiedTimeout),
    retries,
    `waitForActionableElement(${elementName})`
  );
}

/**
 * Waits for an element to be actionable within a specific root node.
 * 
 * @param root Root node to search within
 * @param selectors Array of CSS selectors to try (in order)
 * @param elementName Human-readable name for error messages
 * @param timeout Maximum time to wait in milliseconds (default: 10000)
 * @param retries Number of retry attempts (default: 2)
 * @returns Promise resolving to an actionable HTMLElement
 */
export function waitForActionableElementWithin<T extends HTMLElement = HTMLElement>(
  root: ParentNode,
  selectors: readonly string[],
  elementName: string = 'element',
  timeout: number = DEFAULT_TIMEOUT_MS,
  retries: number = DEFAULT_RETRIES
): Promise<T> {
  // Apply the modifier to the timeout before passing it to the internal function
  const modifiedTimeout = getModifiedTimeout(timeout);
  return retryOperation(
    () => waitForActionableElementInternal<T>(selectors, elementName, modifiedTimeout, root),
    retries,
    `waitForActionableElementWithin(${elementName})`
  );
}

// Retry wrapper (reused from wait-for-element.ts pattern)
async function retryOperation<T>(
  operation: () => Promise<T>,
  maxRetries: number,
  operationName: string
): Promise<T> {
  let lastError: Error | null = null;
  const RETRY_DELAY_MS = 300;
  
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error));
      
      const isTimeoutError = lastError.message.includes('not found') || 
                            lastError.message.includes('timeout') ||
                            lastError.message.includes('None of the selectors') ||
                            lastError.message.includes('not actionable');
      
      if (!isTimeoutError || attempt >= maxRetries) {
        throw lastError;
      }
      
      const delay = RETRY_DELAY_MS * Math.pow(2, attempt);
      console.log(`[${operationName}] Retry ${attempt + 1}/${maxRetries} after ${delay}ms delay. Error: ${lastError.message.split('\n')[0]}`);
      
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
  
  throw lastError || new Error(`Operation ${operationName} failed after ${maxRetries} retries`);
}

