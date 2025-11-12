// ts_src/utils/wait-for-visible-element.ts

import { waitForElement } from './wait-for-element';
import { getModifiedTimeout } from './timeout';

const DEFAULT_TIMEOUT_MS = 10000;
const DEFAULT_RETRIES = 2;
const DEFAULT_THRESHOLD = 0.1; // Element is considered visible when 10% is in viewport

interface IntersectionObserverOptions {
  root?: Element | null;
  rootMargin?: string;
  threshold?: number | number[];
}

/**
 * Waits for an element to become visible in the viewport using IntersectionObserver.
 * This is the most performant solution for visibility checks, especially for
 * lazy-loaded content and virtualized lists.
 * 
 * @param selectors Array of CSS selectors to try (in order)
 * @param timeout Maximum time to wait in milliseconds (default: 10000)
 * @param retries Number of retry attempts (default: 2)
 * @param options Optional IntersectionObserver configuration
 * @returns Promise resolving to a visible HTMLElement
 */
export function waitForVisibleElement<T extends HTMLElement = HTMLElement>(
  selectors: readonly string[],
  timeout: number = DEFAULT_TIMEOUT_MS,
  retries: number = DEFAULT_RETRIES,
  options: IntersectionObserverOptions = {}
): Promise<T> {
  // Apply the modifier to the timeout before passing it to the internal function
  const modifiedTimeout = getModifiedTimeout(timeout);
  return retryOperation(
    () => waitForVisibleElementInternal<T>(selectors, modifiedTimeout, options),
    retries,
    'waitForVisibleElement'
  );
}

/**
 * Internal implementation using IntersectionObserver.
 */
async function waitForVisibleElementInternal<T extends HTMLElement = HTMLElement>(
  selectors: readonly string[],
  timeout: number,
  options: IntersectionObserverOptions
): Promise<T> {
  return new Promise((resolve, reject) => {
    const startTime = Date.now();
    let observer: IntersectionObserver | null = null;
    let timeoutId: number | null = null;
    let foundElement: T | null = null;

    console.log(`[waitForVisibleElement] Starting visibility check for selectors: [${selectors.join(', ')}] (timeout: ${timeout}ms)`);

    const cleanup = () => {
      if (observer) {
        observer.disconnect();
        observer = null;
      }
      if (timeoutId !== null) {
        clearTimeout(timeoutId);
        timeoutId = null;
      }
    };

    // WHY: First, wait for element to exist in DOM
    waitForElement<T>(selectors, timeout, 0)
      .then((element) => {
        foundElement = element;
        
        // WHY: Check if already visible using modern API
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        if (typeof (foundElement as any).checkVisibility === 'function') {
          try {
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            const isVisible = (foundElement as any).checkVisibility({ 
              checkOpacity: true, 
              checkVisibilityCSS: true 
            });
            if (isVisible && foundElement.offsetParent !== null) {
              const actualTime = Date.now() - startTime;
              console.log(`[waitForVisibleElement] Element already visible after ${actualTime}ms`);
              cleanup();
              resolve(foundElement as T);
              return;
            }
          } catch {
            // Fallback to IntersectionObserver
          }
        }
        
        // WHY: Fallback check using offsetParent
        if (foundElement.offsetParent !== null) {
          // Quick visibility check - if offsetParent exists, element is likely visible
          // But use IntersectionObserver for more accurate viewport visibility
        }
        
        // WHY: Use IntersectionObserver for accurate viewport visibility detection
        // This is essential for lazy-loaded content and virtualized lists
        if (typeof IntersectionObserver !== 'undefined') {
          observer = new IntersectionObserver(
            (entries) => {
              for (const entry of entries) {
                // WHY: entry.isIntersecting indicates element is in viewport
                // entry.intersectionRatio > threshold ensures sufficient portion is visible
                const threshold: number = Array.isArray(options.threshold) 
                  ? (options.threshold[0] ?? DEFAULT_THRESHOLD)
                  : (options.threshold ?? DEFAULT_THRESHOLD);
                
                if (entry.isIntersecting && entry.intersectionRatio >= threshold) {
                  const actualTime = Date.now() - startTime;
                  console.log(`[waitForVisibleElement] Element became visible after ${actualTime}ms (intersectionRatio: ${entry.intersectionRatio})`);
                  cleanup();
                  resolve(entry.target as T);
                  return;
                }
              }
            },
            {
              root: options.root || null,
              rootMargin: options.rootMargin || '0px',
              threshold: options.threshold ?? DEFAULT_THRESHOLD,
            }
          );
          
          observer.observe(foundElement);
          
          // WHY: Check immediately in case element is already visible
          // IntersectionObserver may not fire if element is already intersecting
          const rect = foundElement.getBoundingClientRect();
          const isInViewport = rect.top < window.innerHeight && 
                              rect.bottom > 0 && 
                              rect.left < window.innerWidth && 
                              rect.right > 0;
          
          if (isInViewport) {
            const threshold: number = Array.isArray(options.threshold) 
              ? (options.threshold[0] ?? DEFAULT_THRESHOLD)
              : (options.threshold ?? DEFAULT_THRESHOLD);
            const intersectionRatio = Math.min(
              (Math.min(rect.bottom, window.innerHeight) - Math.max(rect.top, 0)) / rect.height,
              (Math.min(rect.right, window.innerWidth) - Math.max(rect.left, 0)) / rect.width
            );
            
            if (intersectionRatio >= threshold) {
              const actualTime = Date.now() - startTime;
              console.log(`[waitForVisibleElement] Element already in viewport after ${actualTime}ms (intersectionRatio: ${intersectionRatio})`);
              cleanup();
              resolve(foundElement as T);
              return;
            }
          }
        } else {
          // WHY: Fallback if IntersectionObserver not available
          console.warn('[waitForVisibleElement] IntersectionObserver not available, using offsetParent check');
          if (foundElement.offsetParent !== null) {
            const actualTime = Date.now() - startTime;
            console.log(`[waitForVisibleElement] Element visible (offsetParent check) after ${actualTime}ms`);
            cleanup();
            resolve(foundElement as T);
            return;
          } else {
            cleanup();
            reject(new Error(`Element found but not visible (offsetParent is null)`));
            return;
          }
        }
      })
      .catch((error) => {
        cleanup();
        reject(error);
      });

    // Set timeout
    // WHY: Timeout handler for cleanup, not a UI wait
     
    timeoutId = window.setTimeout(() => {
      cleanup();
      if (foundElement) {
        reject(new Error(`Element found but did not become visible within ${timeout}ms`));
      } else {
        reject(new Error(`waitForVisibleElement failed: None of the selectors [${selectors.join(', ')}] found within ${timeout}ms`));
      }
    }, timeout);
  });
}

// Retry wrapper (reused pattern)
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
                            lastError.message.includes('not visible');
      
      if (!isTimeoutError || attempt >= maxRetries) {
        throw lastError;
      }
      
      const delay = RETRY_DELAY_MS * Math.pow(2, attempt);
      console.log(`[waitForVisibleElement] Retry ${attempt + 1}/${maxRetries} after ${delay}ms delay. Error: ${lastError.message.split('\n')[0]}`);
      
      // WHY: Exponential backoff delay for retry mechanism, not a UI wait
       
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
  
  throw lastError || new Error(`Operation ${operationName} failed after ${maxRetries} retries`);
}

