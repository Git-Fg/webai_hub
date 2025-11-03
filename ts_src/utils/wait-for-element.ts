// ts_src/utils/wait-for-element.ts

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

export function waitForElement(selectors: string[], timeout = 10000): Promise<Element> {
  return new Promise((resolve, reject) => {
    const intervalTime = 300;
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

