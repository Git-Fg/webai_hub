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

function debugPageElements() {
    const textInputs = document.querySelectorAll('textarea, input[type="text"], [contenteditable="true"]');
    const buttons = document.querySelectorAll('button');
    const containers = document.querySelectorAll('[class*="response"], [class*="message"], [class*="content"]');
}

function notifyDart(event: { type: 'GENERATION_COMPLETE' | 'AUTOMATION_FAILED', payload?: any }) {
    // @ts-ignore
    if (window.flutter_inappwebview) {
        // @ts-ignore
        window.flutter_inappwebview.callHandler('automationBridge', event);
    }
}

async function startAutomation(prompt: string): Promise<void> {
    try {
        debugPageElements();

        const inputArea = await waitForElement(PROMPT_INPUT_SELECTORS) as any;

        if (inputArea.tagName === 'TEXTAREA' || inputArea.tagName === 'INPUT') {
            inputArea.value = prompt;
            inputArea.dispatchEvent(new Event('input', { bubbles: true }));
            inputArea.dispatchEvent(new Event('change', { bubbles: true }));
        } else if (inputArea.contentEditable === 'true') {
            inputArea.innerText = prompt;
            inputArea.dispatchEvent(new Event('input', { bubbles: true }));
        } else {
            inputArea.click();
            await new Promise(resolve => setTimeout(resolve, 500));
            (inputArea as any).value = prompt;
        }

        const sendButton = await waitForElement(SEND_BUTTON_SELECTORS) as HTMLElement;
        sendButton.click();

        console.log("Automation sent. Now observing for response completion...");

        // Wait for generation indicator to appear first
        await waitForElement(GENERATION_INDICATOR_SELECTORS, 5000);
        console.log("Generation indicator appeared. Observing for its disappearance.");

        // Now observe its disappearance with MutationObserver
        await new Promise<void>((resolve) => {
            const observer = new MutationObserver((mutations, obs) => {
                const isGenerating = document.querySelector(GENERATION_INDICATOR_SELECTORS[0]); // Check primary selector for MVP simplicity

                if (!isGenerating) {
                    console.log("Generation indicator disappeared. Generation complete.");
                    notifyDart({ type: 'GENERATION_COMPLETE' });
                    obs.disconnect(); // Clean up the observer
                    clearTimeout(timeoutId);
                    resolve();
                }
            });

            // Observe changes in the document body
            observer.observe(document.body, {
                childList: true,
                subtree: true,
            });

            // Add safety timeout
            const timeoutId = setTimeout(() => {
                console.warn("Observation timed out after 45s. Assuming completion.");
                observer.disconnect();
                notifyDart({ type: 'GENERATION_COMPLETE' });
                resolve();
            }, 45000);
        });

    } catch (error) {
        notifyDart({ type: 'AUTOMATION_FAILED', payload: error instanceof Error ? error.message : String(error) });
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
        const responseText = lastResponse.innerText?.trim() || "";

        return responseText;

    } catch (error) {
        notifyDart({ type: 'AUTOMATION_FAILED', payload: error instanceof Error ? error.message : String(error) });
        throw error;
    }
}

// @ts-ignore
window.startAutomation = startAutomation;
// @ts-ignore
window.extractFinalResponse = extractFinalResponse;