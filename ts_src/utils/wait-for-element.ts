// ts_src/utils/wait-for-element.ts

const DEFAULT_TIMEOUT_MS = 10000;
const DEFAULT_INTERVAL_MS = 300;
const DEFAULT_RETRIES = 2;
const RETRY_DELAY_MS = 300;
const PROGRESS_LOG_INTERVAL_MS = 2000; // Log progress every 2 seconds

// Helper to get page state information for error messages
function getPageState(): { url: string; readyState: string; visibleElementsCount: number } {
  return {
    url: window.location.href,
    readyState: document.readyState,
    visibleElementsCount: document.querySelectorAll('*').length,
  };
}

// Helper to format error message with context
function formatErrorMessage(
  selectors: readonly string[],
  timeout: number,
  elapsedTime: number,
  operation: string = 'waitForElement'
): string {
  const pageState = getPageState();
  return `${operation} failed: None of the selectors [${selectors.join(', ')}] found within ${timeout}ms
Context: URL=${pageState.url}, Timeout=${timeout}ms, Elapsed=${elapsedTime}ms
Page State: Ready=${pageState.readyState}, VisibleElements=${pageState.visibleElementsCount}`;
}

// Helper to find elements by text content (for :contains() emulation)
function findElementByText(selector: string, textMatch: string, caseSensitive = false): Element | null {
  try {
    // Extract base selector (remove :contains() part)
    const baseSelector = selector.split(':contains')[0];
    const elements = document.querySelectorAll(baseSelector || '*');
    
    for (const el of elements) {
      const text = el.textContent || '';
      const matchText = caseSensitive ? text : text.toLowerCase();
      const searchText = caseSensitive ? textMatch : textMatch.toLowerCase();
      
      if (matchText.includes(searchText)) {
        return el;
      }
    }
      } catch {
        // Fallback to standard querySelector
      }
  return null;
}

// WHY: Check selectors against DOM - extracted for reuse in both observer and polling
function checkSelectors(
  selectors: readonly string[],
  root: ParentNode | undefined,
  operation: string
): Element | null {
  for (let i = 0; i < selectors.length; i++) {
    const selector = selectors[i];
    if (!selector) continue; // Skip undefined selectors
    
    let element: Element | null = null;
    
    // Handle :contains() pseudo-selector
    if (selector.includes(':contains(')) {
      const match = selector.match(/^(.+):contains\(['"](.+)['"]\)$/);
      if (match && match[1] && match[2]) {
        element = findElementByText(match[1], match[2]);
      }
    } else {
      // Standard CSS selector
      try {
        if (root) {
          element = (root as Element | Document).querySelector(selector);
        } else {
          element = document.querySelector(selector);
        }
      } catch (e) {
        // Invalid selector, skip
        console.warn(`[${operation}] Invalid selector "${selector}" (index ${i}):`, e);
        continue;
      }
    }
    
    if (element) {
      return element;
    }
  }
  return null;
}

// Internal implementation of waitForElement with retry support
// WHY: Uses MutationObserver for event-driven waiting (primary strategy) with polling fallback
async function waitForElementInternal<T extends Element = HTMLElement>(
  selectors: readonly string[],
  timeout: number,
  operation: string = 'waitForElement',
  root?: ParentNode
): Promise<T> {
  return new Promise((resolve, reject) => {
    const startTime = Date.now();
    let lastProgressLogTime = 0;
    let observer: MutationObserver | null = null;
    let timeoutId: number | null = null;
    let checkInterval: number | null = null;
    let firstAttemptLogged = false;

    console.log(`[${operation}] Starting search for selectors: [${selectors.join(', ')}] (timeout: ${timeout}ms)`);

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

    const checkForElement = () => {
      const elapsed = Date.now() - startTime;
      
      // Log progress periodically
      if (elapsed - lastProgressLogTime >= PROGRESS_LOG_INTERVAL_MS) {
        console.log(`[${operation}] Still searching... (elapsed: ${elapsed}ms, remaining: ${timeout - elapsed}ms)`);
        lastProgressLogTime = elapsed;
      }

      // Log first attempt failures for debugging
      if (!firstAttemptLogged) {
        const firstCheck = checkSelectors(selectors, root, operation);
        if (!firstCheck) {
          console.log(`[${operation}] Selectors not found on first attempt`);
        }
        firstAttemptLogged = true;
      }

      const element = checkSelectors(selectors, root, operation);
      
      if (element) {
        const actualTime = Date.now() - startTime;
        const foundSelector = selectors.find((sel) => {
          if (!sel) return false;
          try {
            if (root) {
              return (root as Element | Document).querySelector(sel) === element;
            }
            return document.querySelector(sel) === element;
          } catch {
            return false;
          }
        });
        console.log(`[${operation}] Found element with selector "${foundSelector || 'unknown'}" after ${actualTime}ms`);
        cleanup();
        resolve(element as T);
        return;
      }

      // Check timeout
      if (elapsed >= timeout) {
        cleanup();
        const errorMessage = formatErrorMessage(selectors, timeout, elapsed, operation);
        reject(new Error(errorMessage));
      }
    };

    // WHY: Use MutationObserver for event-driven detection (primary strategy)
    // This is more efficient than polling and responds immediately to DOM changes
    if (typeof MutationObserver !== 'undefined') {
      observer = new MutationObserver(() => {
        checkForElement();
      });
      
      // WHY: Observe the narrowest possible scope for mobile performance
      const observeTarget = root || document.body;
      observer.observe(observeTarget, { 
        childList: true, 
        subtree: true 
      });
      
      // WHY: Check immediately in case element already exists
      checkForElement();
    } else {
      // WHY: Fallback to polling if MutationObserver not available (rare edge case)
      console.warn(`[${operation}] MutationObserver not available, using polling fallback`);
      checkInterval = window.setInterval(checkForElement, DEFAULT_INTERVAL_MS);
      checkForElement();
    }

    // Set timeout
    timeoutId = window.setTimeout(() => {
      cleanup();
      const elapsed = Date.now() - startTime;
      const errorMessage = formatErrorMessage(selectors, timeout, elapsed, operation);
      reject(new Error(errorMessage));
    }, timeout);
  });
}

export function waitForElement<T extends Element = HTMLElement>(
  selectors: readonly string[],
  timeout = DEFAULT_TIMEOUT_MS,
  retries = DEFAULT_RETRIES
): Promise<T> {
  return retryOperation(
    () => waitForElementInternal<T>(selectors, timeout, 'waitForElement'),
    retries,
    'waitForElement'
  );
}

export function waitForElementWithin<T extends Element = HTMLElement>(
  root: ParentNode,
  selectors: readonly string[],
  timeout = DEFAULT_TIMEOUT_MS,
  retries = DEFAULT_RETRIES
): Promise<T> {
  return retryOperation(
    () => waitForElementInternal<T>(selectors, timeout, 'waitForElementWithin', root),
    retries,
    'waitForElementWithin'
  );
}

// Retry wrapper for operations that may fail transiently
async function retryOperation<T>(
  operation: () => Promise<T>,
  maxRetries: number,
  operationName: string
): Promise<T> {
  let lastError: Error | null = null;
  
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error));
      
      // Only retry on timeout errors (errors that mention "not found" or "timeout")
      const isTimeoutError = lastError.message.includes('not found') || 
                            lastError.message.includes('timeout') ||
                            lastError.message.includes('None of the selectors');
      
      if (!isTimeoutError || attempt >= maxRetries) {
        // Don't retry invalid selector errors or if we've exhausted retries
        throw lastError;
      }
      
      // Calculate exponential backoff delay
      const delay = RETRY_DELAY_MS * Math.pow(2, attempt);
      console.log(`[${operationName}] Retry ${attempt + 1}/${maxRetries} after ${delay}ms delay. Error: ${lastError.message.split('\n')[0]}`);
      
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
  
  // This should never be reached, but TypeScript needs it
  throw lastError || new Error(`Operation ${operationName} failed after ${maxRetries} retries`);
}
