// Selectors based on actual DOM inspection via mobile-mcp
// Input detected: EditText with label "Start typing a prompt"
const PROMPT_INPUT_SELECTORS = [
    "textarea[placeholder*='Start typing a prompt']",
    "textarea[placeholder*='typing a prompt']",
    "input[placeholder*='Start typing a prompt']",
    "input[placeholder*='typing a prompt']",
    "textarea[placeholder*='prompt']",
    "input[placeholder*='prompt']",
    "input-area",  // Original blueprint selector
    "textarea[aria-label*='prompt']",
    "textarea[name*='prompt']",
    "textarea[id*='prompt']",
    ".ql-editor",
    "div[contenteditable='true']",
    "textarea",
    "input[type='text']"
];

// Button detected: aria-label "Append to prompt and run (Ctrl + Enter)" and text "Run"
const SEND_BUTTON_SELECTORS = [
    'button[aria-label*="Append to prompt and run"]',
    'button[aria-label*="Append to Prompt and run"]',
    'button[aria-label*="run" i]',
    'button[aria-label*="Run"]',
    'send-button[variant="primary"]',  // Original blueprint selector
    'button[aria-label*="Send"]',
    'button:contains("Run")',
    '.send-button button',
    'button[type="submit"]'
];

const RESPONSE_CONTAINER_SELECTORS = [
    "response-container",
    ".response-message",
    ".message-response",
    ".markdown",
    ".response-content",
    "[data-testid*='response']",
    ".message-content"
];

const GENERATION_INDICATOR_SELECTORS = [
    'mat-icon[data-mat-icon-name="stop"]',
    ".generating-indicator",
    ".loading-indicator",
    "[data-testid*='generating']",
    ".spinner",
    ".loading-spinner",
    ".thinking-indicator"
];

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

function waitForElement(selectors: string[], timeout = 10000): Promise<Element> {
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

interface FlutterInAppWebView {
    callHandler(handlerName: string, ...args: unknown[]): void;
}

interface WindowWithFlutterInAppWebView extends Window {
    flutter_inappwebview?: FlutterInAppWebView;
    startAutomation?: (prompt: string) => Promise<void>;
    extractFinalResponse?: () => Promise<string>;
}

function notifyDart(event: { 
    type: 'GENERATION_COMPLETE' | 'AUTOMATION_FAILED', 
    payload?: string,
    errorCode?: string,
    location?: string,
    diagnostics?: Record<string, unknown>
}) {
    const windowWithFlutter = window as WindowWithFlutterInAppWebView;
    if (windowWithFlutter.flutter_inappwebview) {
        windowWithFlutter.flutter_inappwebview.callHandler('automationBridge', event);
    }
}

function getPageDiagnostics(): Record<string, unknown> {
    return {
        'documentReadyState': document.readyState,
        'hasFlutterBridge': !!(window as WindowWithFlutterInAppWebView).flutter_inappwebview,
        'hasStartAutomation': typeof (window as WindowWithFlutterInAppWebView).startAutomation !== 'undefined',
        'hasExtractFinalResponse': typeof (window as WindowWithFlutterInAppWebView).extractFinalResponse !== 'undefined',
        'url': window.location.href,
        'timestamp': new Date().toISOString(),
    };
}

// Debug function to inspect DOM elements
function debugDOMStructure(): void {
    const allInputs = Array.from(document.querySelectorAll('input, textarea, [contenteditable="true"]'));
    const allButtons = Array.from(document.querySelectorAll('button'));
    
    console.log('[DEBUG] Found inputs:', allInputs.map(el => ({
        tag: el.tagName,
        type: (el as HTMLElement).getAttribute('type'),
        placeholder: (el as HTMLElement).getAttribute('placeholder'),
        ariaLabel: (el as HTMLElement).getAttribute('aria-label'),
        id: el.id,
        className: el.className,
        contentEditable: (el as HTMLElement).contentEditable
    })));
    
    console.log('[DEBUG] Found buttons:', allButtons.slice(0, 10).map(el => ({
        tag: el.tagName,
        ariaLabel: el.getAttribute('aria-label'),
        text: el.innerText?.substring(0, 50),
        id: el.id,
        className: el.className,
        type: el.getAttribute('type')
    })));
}

async function startAutomation(prompt: string): Promise<void> {
    try {
        console.log('[startAutomation] Starting automation with prompt:', prompt.substring(0, 50));
        
        // Debug DOM structure
        debugDOMStructure();
        
        console.log('[startAutomation] Waiting for input area...');
        const inputArea = await waitForElement(PROMPT_INPUT_SELECTORS);
        console.log('[startAutomation] Found input area:', inputArea.tagName, inputArea.className);

        if (inputArea.tagName === 'TEXTAREA' || inputArea.tagName === 'INPUT') {
            const input = inputArea as HTMLInputElement | HTMLTextAreaElement;
            input.value = prompt;
            inputArea.dispatchEvent(new Event('input', { bubbles: true }));
            inputArea.dispatchEvent(new Event('change', { bubbles: true }));
        } else if (inputArea instanceof HTMLElement && inputArea.contentEditable === 'true') {
            const editable = inputArea as HTMLElement;
            editable.innerText = prompt;
            inputArea.dispatchEvent(new Event('input', { bubbles: true }));
        } else {
            const element = inputArea as HTMLElement;
            element.click();
            await new Promise<void>(resolve => setTimeout(() => resolve(), 500));
            const fallbackInput = element as HTMLInputElement;
            if (fallbackInput.value !== undefined) {
                fallbackInput.value = prompt;
            }
        }

        console.log('[startAutomation] Waiting for send button...');
        const sendButton = await waitForElement(SEND_BUTTON_SELECTORS) as HTMLElement;
        console.log('[startAutomation] Found send button:', sendButton.tagName, sendButton.className, sendButton.getAttribute('aria-label'));
        sendButton.click();
        console.log('[startAutomation] Clicked send button');

        await waitForElement(GENERATION_INDICATOR_SELECTORS, 5000);

        await new Promise<void>((resolve) => {
            const primarySelector = GENERATION_INDICATOR_SELECTORS[0];
            if (!primarySelector) {
                resolve();
                return;
            }

            const observer = new MutationObserver((_mutations, obs) => {
                const isGenerating = document.querySelector(primarySelector);

                if (!isGenerating) {
                    notifyDart({ type: 'GENERATION_COMPLETE' });
                    obs.disconnect();
                    clearTimeout(timeoutId);
                    resolve();
                }
            });

            observer.observe(document.body, {
                childList: true,
                subtree: true,
            });

            const timeoutId = setTimeout(() => {
                observer.disconnect();
                notifyDart({ type: 'GENERATION_COMPLETE' });
                resolve();
            }, 45000);
        });

    } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        const diagnostics: Record<string, unknown> = {
            ...getPageDiagnostics(),
            'promptLength': prompt.length,
            'promptPreview': prompt.length > 50 ? prompt.substring(0, 50) + '...' : prompt,
        };
        
        if (error instanceof Error && error.message.includes('not found within')) {
            diagnostics['errorType'] = 'ELEMENT_NOT_FOUND';
            diagnostics['timeoutReached'] = true;
        }
        
        notifyDart({ 
            type: 'AUTOMATION_FAILED', 
            payload: errorMessage,
            errorCode: 'AUTOMATION_EXECUTION_FAILED',
            location: 'startAutomation',
            diagnostics: diagnostics
        });
        throw error;
    }
}

async function extractFinalResponse(): Promise<string> {
    try {
        let allResponses: HTMLElement[] = [];

        for (const selector of RESPONSE_CONTAINER_SELECTORS) {
            const elements = Array.from(document.querySelectorAll(selector)) as HTMLElement[];
            allResponses.push(...elements);
        }

        if (allResponses.length === 0) {
            const candidates = Array.from(document.querySelectorAll('*')) as HTMLElement[];

            allResponses = candidates.filter(el => {
                const text = el.innerText?.trim() || '';
                const hasContent = text.length > 50;
                const notInput = !el.matches('input, textarea, button, select, option');
                const visible = el.offsetParent !== null;

                return hasContent && notInput && visible;
            });
        }

        if (allResponses.length === 0) {
            const bodyText = document.body?.innerText || '';
            return bodyText.trim() || "No response available";
        }

        const lastResponse = allResponses[allResponses.length - 1];

        if (!lastResponse) {
            return "No last response element found, though the array was not empty.";
        }

        const responseText = lastResponse.innerText?.trim() || "";
        return responseText;

    } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        const diagnostics = {
            ...getPageDiagnostics(),
            'responseContainerSelectors': RESPONSE_CONTAINER_SELECTORS.length,
            'foundResponseElements': 0,
        };
        
        notifyDart({ 
            type: 'AUTOMATION_FAILED', 
            payload: errorMessage,
            errorCode: 'RESPONSE_EXTRACTION_FAILED',
            location: 'extractFinalResponse',
            diagnostics: diagnostics
        });
        throw error;
    }
}

function signalReady() {
    const windowWithFlutter = window as WindowWithFlutterInAppWebView;
    if (windowWithFlutter.flutter_inappwebview) {
        try {
            windowWithFlutter.flutter_inappwebview.callHandler('bridgeReady');
        } catch (e) {
            console.warn('Failed to signal bridge ready:', e);
        }
    }
}

function trySignalReady(retries = 100, delay = 300) {
    if (retries <= 0) {
        console.warn('Bridge ready signal: max retries reached, giving up');
        return;
    }
    
    const windowWithFlutter = window as WindowWithFlutterInAppWebView;
    if (windowWithFlutter.flutter_inappwebview) {
        try {
            signalReady();
            console.log('Bridge ready signal sent successfully');
        } catch (e) {
            console.warn('Error sending bridge ready signal:', e);
            setTimeout(() => trySignalReady(retries - 1, delay), delay);
        }
    } else {
        setTimeout(() => trySignalReady(retries - 1, delay), delay);
    }
}

// Helper to check for Shadow DOM
function findInShadowDOM(selector: string, root: Document | ShadowRoot = document): Element | null {
    try {
        const element = root.querySelector(selector);
        if (element) return element;
        
        const allElements = root.querySelectorAll('*');
        for (const el of allElements) {
            if (el.shadowRoot) {
                const found = findInShadowDOM(selector, el.shadowRoot);
                if (found) return found;
            }
        }
    } catch (e) {
        // Closed shadow DOM or other error
    }
    return null;
}

// Export debug function for external inspection
function inspectDOMForSelectors(): Record<string, unknown> {
    const result: Record<string, unknown> = {
        inputs: [],
        buttons: [],
        allSelectorsTested: {},
        shadowDOMDetected: false
    };
    
    // Check for Shadow DOM
    const allElements = document.querySelectorAll('*');
    for (const el of allElements) {
        if (el.shadowRoot) {
            result.shadowDOMDetected = true;
            break;
        }
    }
    
    // Test all PROMPT_INPUT_SELECTORS
    const inputMatches: Record<string, Element | null> = {};
    for (const selector of PROMPT_INPUT_SELECTORS) {
        try {
            inputMatches[selector] = document.querySelector(selector);
            // Also check Shadow DOM
            if (!inputMatches[selector]) {
                inputMatches[`${selector} (shadow)`] = findInShadowDOM(selector);
            }
        } catch (e) {
            inputMatches[selector] = null;
        }
    }
    (result.allSelectorsTested as Record<string, unknown>).promptInput = inputMatches;
    
    // Test all SEND_BUTTON_SELECTORS
    const buttonMatches: Record<string, Element | null> = {};
    for (const selector of SEND_BUTTON_SELECTORS) {
        try {
            buttonMatches[selector] = document.querySelector(selector);
            // Also check Shadow DOM
            if (!buttonMatches[selector]) {
                buttonMatches[`${selector} (shadow)`] = findInShadowDOM(selector);
            }
        } catch (e) {
            buttonMatches[selector] = null;
        }
    }
    (result.allSelectorsTested as Record<string, unknown>).sendButton = buttonMatches;
    
    // Find all inputs (including in Shadow DOM)
    const allInputs = Array.from(document.querySelectorAll('input, textarea, [contenteditable="true"]'));
    result.inputs = allInputs.map(el => {
        const htmlEl = el as HTMLElement;
        return {
            tag: el.tagName.toLowerCase(),
            type: htmlEl.getAttribute('type') || '',
            placeholder: htmlEl.getAttribute('placeholder') || '',
            ariaLabel: htmlEl.getAttribute('aria-label') || '',
            id: el.id || '',
            className: el.className || '',
            contentEditable: htmlEl.contentEditable,
            visible: htmlEl.offsetParent !== null,
            inShadowDOM: false
        };
    });
    
    // Find all buttons
    const allButtons = Array.from(document.querySelectorAll('button'));
    result.buttons = allButtons.map(el => {
        const htmlEl = el as HTMLElement;
        return {
            tag: el.tagName.toLowerCase(),
            ariaLabel: htmlEl.getAttribute('aria-label') || '',
            text: (htmlEl.innerText || '').substring(0, 100),
            id: el.id || '',
            className: el.className || '',
            type: el.getAttribute('type') || '',
            visible: htmlEl.offsetParent !== null,
            inShadowDOM: false
        };
    });
    
    return result;
}

const windowWithFlutter = window as WindowWithFlutterInAppWebView;
windowWithFlutter.startAutomation = startAutomation;
windowWithFlutter.extractFinalResponse = extractFinalResponse;
// Expose debug function
(windowWithFlutter as any).inspectDOMForSelectors = inspectDOMForSelectors;

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        trySignalReady();
    });
} else {
    trySignalReady();
}