// ts_src/utils/wait-for-element.ts

const DEFAULT_TIMEOUT_MS = 10000;
const DEFAULT_INTERVAL_MS = 300;

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
  } catch (e) {
    // Fallback to standard querySelector
  }
  return null;
}

export function waitForElement(selectors: string[], timeout = DEFAULT_TIMEOUT_MS): Promise<Element> {
  return new Promise((resolve, reject) => {
    const intervalTime = DEFAULT_INTERVAL_MS;
    let elapsedTime = 0;

    const interval = setInterval(() => {
      for (const selector of selectors) {
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
            element = document.querySelector(selector);
            if (!element && elapsedTime === 0) {
              // Log first attempt failures for debugging
              console.log(`[waitForElement] Selector "${selector}" not found on first attempt`);
            }
          } catch (e) {
            // Invalid selector, skip
            console.warn(`[waitForElement] Invalid selector "${selector}":`, e);
            continue;
          }
        }
        
        if (element) {
          console.log(`[waitForElement] Found element with selector "${selector}"`);
          clearInterval(interval);
          resolve(element);
          return;
        }
      }

      elapsedTime += intervalTime;
      if (elapsedTime >= timeout) {
        clearInterval(interval);
        reject(new Error(`None of the selectors [${selectors.join(', ')}] found within ${timeout}ms`));
      }
    }, intervalTime);
  });
}

export function waitForElementWithin(
  root: ParentNode,
  selectors: string[],
  timeout = DEFAULT_TIMEOUT_MS,
): Promise<Element> {
  return new Promise((resolve, reject) => {
    const intervalTime = DEFAULT_INTERVAL_MS;
    let elapsedTime = 0;

    const interval = setInterval(() => {
      for (const selector of selectors) {
        let element: Element | null = null;

        if (selector.includes(':contains(')) {
          const match = selector.match(/^(.+):contains\(['"](.+)['"]\)$/);
          if (match && match[1] && match[2]) {
            try {
              const baseSelector = match[1];
              const nodes = (root as Element | Document).querySelectorAll(baseSelector || '*');
              for (const el of nodes) {
                const text = el.textContent || '';
                if (text.toLowerCase().includes(match[2].toLowerCase())) {
                  element = el;
                  break;
                }
              }
            } catch (e) {
              // ignore invalid selector inside root scope
            }
          }
        } else {
          try {
            element = (root as Element | Document).querySelector(selector);
            if (!element && elapsedTime === 0) {
              console.log(`[waitForElementWithin] Selector "${selector}" not found on first attempt`);
            }
          } catch (e) {
            console.warn(`[waitForElementWithin] Invalid selector "${selector}":`, e);
            continue;
          }
        }

        if (element) {
          console.log(`[waitForElementWithin] Found element with selector "${selector}"`);
          clearInterval(interval);
          resolve(element);
          return;
        }
      }

      elapsedTime += intervalTime;
      if (elapsedTime >= timeout) {
        clearInterval(interval);
        reject(new Error(`None of the selectors [${selectors.join(', ')}] found within ${timeout}ms`));
      }
    }, intervalTime);
  });
}

