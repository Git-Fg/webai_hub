// Selectors based on actual DOM inspection via mobile-mcp
// High-fidelity selectors matching real Google AI Studio structure
const PROMPT_INPUT_SELECTORS = [
    "textarea[placeholder*='Start typing a prompt']",  // High-fidelity: real site structure
    "textarea[aria-label*='Start typing a prompt']",  // Alternative aria-label
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

// Button detected: aria-label "Run" in high-fidelity structure
const SEND_BUTTON_SELECTORS = [
    'button[aria-label="Run"]',  // High-fidelity: exact match for real site
    'button[aria-label*="Run"]',
    'button[aria-label*="Append to prompt and run"]',
    'button[aria-label*="Append to Prompt and run"]',
    'button[aria-label*="run"]',
    'send-button[variant="primary"]',  // Original blueprint selector
    'button[aria-label*="Send"]',
    'button:contains("Run")',
    '.send-button button',
    'button[type="submit"]',
    'button'  // Fallback to any button
];

// Response containers: targeting ms-chat-turn with Model role and cmark-node
const RESPONSE_CONTAINER_SELECTORS = [
    'ms-chat-turn[data-turn-role="Model"] ms-cmark-node',  // High-fidelity: real structure
    'ms-chat-turn[data-turn-role="Model"] .response-content',  // Alternative: response content wrapper
    'ms-chat-turn[data-turn-role="Model"]',  // Fallback to entire turn
    '.response-content',  // High-fidelity sandbox fallback
    "response-container",
    ".response-message",
    ".message-response",
    ".markdown",
    "[data-testid*='response']",
    ".message-content"
];

// Generation indicators: targeting ms-thought-chunk and mat-icon[data-mat-icon-name="stop"]
const GENERATION_INDICATOR_SELECTORS = [
    'ms-thought-chunk',  // High-fidelity: thought chunk appears during generation
    'ms-thought-chunk .thinking-progress-icon.in-progress',  // Specific indicator with class
    'mat-icon[data-mat-icon-name="stop"]',  // Real site: stop icon during generation
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
    type: 'GENERATION_COMPLETE' | 'AUTOMATION_FAILED' | 'LOGIN_REQUIRED', 
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

// Détecte si la page actuelle est une page de login Google
function isLoginPage(): boolean {
    // Sélecteurs typiques de la page de login Google
    const loginSelectors = [
        'input[placeholder*="Email or phone"]',
        'input[type="email"]',
        'text:contains("Sign in")',
        'text:contains("Use your Google Account")',
        'button:contains("Next")',
    ];
    
    // Vérifier l'URL
    const url = window.location.href.toLowerCase();
    if (url.includes('accounts.google.com') || url.includes('/signin')) {
        return true;
    }
    
    // Vérifier les éléments du DOM
    const emailInput = document.querySelector('input[placeholder*="Email or phone"], input[type="email"]');
    const signInText = document.body?.innerText?.includes('Sign in') || 
                      document.body?.innerText?.includes('Use your Google Account');
    
    if (emailInput && signInText) {
        console.log('[isLoginPage] Login page detected via DOM elements');
        return true;
    }
    
    return false;
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

// Déclarer startAutomation DIRECTEMENT sur window
(window as any).startAutomation = async function(prompt: string): Promise<void> {
    try {
        console.log('[startAutomation] Starting automation with prompt:', prompt.substring(0, 50));
        
        // Vérifier si on est sur une page de login
        if (isLoginPage()) {
            console.log('[startAutomation] Login page detected. Pausing automation.');
            notifyDart({ 
                type: 'LOGIN_REQUIRED',
                location: 'startAutomation',
                payload: 'User needs to sign in to Google Account'
            });
            return; // Arrêter ici, attendre que l'utilisateur se connecte
        }
        
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

        // Coussin de sécurité: pause après remplissage du champ
        await new Promise(resolve => setTimeout(resolve, 200));

        console.log('[startAutomation] Waiting for send button...');
        const sendButton = await waitForElement(SEND_BUTTON_SELECTORS) as HTMLElement;
        console.log('[startAutomation] Found send button:', sendButton.tagName, sendButton.className, sendButton.getAttribute('aria-label'));
        sendButton.click();
        console.log('[startAutomation] Clicked send button');

        // Coussin de sécurité: pause après le clic
        await new Promise(resolve => setTimeout(resolve, 300));

        // Wait for generation indicator and observe when it disappears
        try {
            const indicator = await waitForElement(GENERATION_INDICATOR_SELECTORS, 5000);
            console.log('[startAutomation] Generation indicator found. Observing for changes...');

            // ✅ NOUVELLE LOGIQUE ROBUSTE AVEC MUTATION OBSERVER
            await new Promise<void>((resolve) => {
                const primarySelector = GENERATION_INDICATOR_SELECTORS[0];
                if (!primarySelector) {
                    console.warn('[Observer] No selector available, forcing completion.');
                    notifyDart({ type: 'GENERATION_COMPLETE' });
                    resolve();
                    return;
                }

                const observer = new MutationObserver((mutations, obs) => {
                    // On vérifie si l'indicateur est toujours visible
                    const indicatorElement = document.querySelector(primarySelector) as HTMLElement;
                    const isVisible = indicatorElement && 
                        (indicatorElement.style.display !== 'none' && 
                         window.getComputedStyle(indicatorElement).display !== 'none');

                    if (!isVisible) {
                        console.log('[Observer] Generation indicator has disappeared.');
                        notifyDart({ type: 'GENERATION_COMPLETE' });
                        obs.disconnect(); // Arrêter l'observation
                        clearTimeout(fallbackTimeout); // Annuler le timeout de secours
                        resolve(); // Résoudre la promesse, ce qui débloque le Future Dart
                    }
                });

                // Observer les changements d'attributs (comme `style`) sur l'indicateur lui-même
                // et les changements dans le body (s'il est supprimé du DOM)
                observer.observe(document.body, {
                    childList: true,
                    subtree: true,
                    attributes: true,
                    attributeFilter: ['style']
                });

                // Timeout de secours TRES important, au cas où quelque chose se passe mal
                const fallbackTimeout = setTimeout(() => {
                    console.warn('[Observer] Fallback timeout reached. Forcing completion.');
                    notifyDart({ type: 'GENERATION_COMPLETE' });
                    observer.disconnect();
                    resolve();
                }, 45000); // Timeout long de 45 secondes
            });

        } catch (e) {
            console.log('[startAutomation] Generation indicator not found, assuming generation is fast and complete.');
            notifyDart({ type: 'GENERATION_COMPLETE' });
        }

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
};

// Déclarer extractFinalResponse DIRECTEMENT sur window
(window as any).extractFinalResponse = async function(): Promise<string> {
        console.log('[extractFinalResponse] Starting extraction...');
    try {
        let allResponseElements: HTMLElement[] = [];

        // Itérer sur les sélecteurs pour trouver TOUS les éléments correspondants
        for (const selector of RESPONSE_CONTAINER_SELECTORS) {
            const elements = Array.from(document.querySelectorAll(selector)) as HTMLElement[];
            if (elements.length > 0) {
                console.log(`[extractFinalResponse] Found ${elements.length} element(s) with selector: ${selector}`);
                allResponseElements.push(...elements);
            }
        }
        
        // S'il n'y a absolument aucun élément correspondant aux sélecteurs
        if (allResponseElements.length === 0) {
            console.warn('[extractFinalResponse] No elements found with any of the primary selectors. Using fallback.');
            // Le fallback est une source d'erreur, on le simplifie: juste le body.
            const bodyText = (document.body?.innerText || "").trim();
            if (!bodyText) {
                throw new Error("No response elements found and body is empty.");
            }
            console.log('[extractFinalResponse] Returning fallback body text.');
            return bodyText;
            }

        // Filtrer pour ne garder que les éléments visibles
        const visibleElements = allResponseElements.filter(el => el.offsetParent !== null);

        if (visibleElements.length === 0) {
            throw new Error("Response elements were found but none are visible.");
        }

        // Prendre le dernier élément visible de la liste
        const lastElement = visibleElements[visibleElements.length - 1];
        if (!lastElement) {
            throw new Error("No visible response element found after filtering.");
        }
        const responseText = (lastElement.innerText || "").trim();

        console.log('[extractFinalResponse] Returning value:', `"${responseText.substring(0, 50)}..."`, 'with type:', typeof responseText);
        
        // S'assurer qu'on retourne bien une chaîne de caractères
        return responseText;

    } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        console.error('[extractFinalResponse] CRITICAL ERROR during extraction:', errorMessage);
        
        // Notifier Dart de l'échec
        notifyDart({ 
            type: 'AUTOMATION_FAILED', 
            payload: errorMessage,
            errorCode: 'RESPONSE_EXTRACTION_FAILED',
            location: 'extractFinalResponse'
        });

        // Rejeter la promesse pour que le `await` en Dart échoue proprement
        throw error;
    }
};

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

// Déclarer inspectDOMForSelectors DIRECTEMENT sur window
(window as any).inspectDOMForSelectors = function(): Record<string, unknown> {
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
};

// Puisque nous injectons à AT_DOCUMENT_END, le DOM est déjà prêt ou presque
// L'appel direct est suffisant
console.log('[Bridge] Script injected and functions attached to window.');
console.log('[Bridge] startAutomation available:', typeof (window as any).startAutomation);
console.log('[Bridge] extractFinalResponse available:', typeof (window as any).extractFinalResponse);
console.log('[Bridge] window.flutter_inappwebview available:', typeof (window as WindowWithFlutterInAppWebView).flutter_inappwebview);
console.log('[Bridge] Document ready state:', document.readyState);
console.log('[Bridge] Document body exists:', !!document.body);
console.log('[Bridge] Prompt input element:', document.querySelector('#prompt-input') ? 'FOUND' : 'NOT FOUND');
console.log('[Bridge] Send button element:', document.querySelector('#send-button') ? 'FOUND' : 'NOT FOUND');

// Signal that bridge is ready
trySignalReady();