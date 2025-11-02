const PROMPT_INPUT_SELECTORS = [
    "input-area",
    "textarea[placeholder*='Prompt']",
    "textarea[aria-label*='prompt'], textarea[aria-label*='Prompt']",
    ".ql-editor",
    "div[contenteditable='true']",
    "textarea"
];

const SEND_BUTTON_SELECTORS = [
    'send-button[variant="primary"]',
    'button[aria-label*="Send"], button[aria-label*="send"]',
    'button mat-icon:contains("send")',
    '.send-button button',
    'button[type="submit"]',
    'button:contains("Send")'
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

function waitForElement(selectors: string[], timeout = 10000): Promise<Element> {
    return new Promise((resolve, reject) => {
        const intervalTime = 300;
        let elapsedTime = 0;

        const interval = setInterval(() => {
            for (const selector of selectors) {
                const element = document.querySelector(selector);
                if (element) {
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

async function startAutomation(prompt: string): Promise<void> {
    try {
        const inputArea = await waitForElement(PROMPT_INPUT_SELECTORS);

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

        const sendButton = await waitForElement(SEND_BUTTON_SELECTORS) as HTMLElement;
        sendButton.click();

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
        windowWithFlutter.flutter_inappwebview.callHandler('bridgeReady');
    }
}

const windowWithFlutter = window as WindowWithFlutterInAppWebView;
windowWithFlutter.startAutomation = startAutomation;
windowWithFlutter.extractFinalResponse = extractFinalResponse;

signalReady();