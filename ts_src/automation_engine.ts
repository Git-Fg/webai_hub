// Fichier: ts_src/automation_engine.ts

// --- SÉLECTEURS CODÉS EN DUR POUR GOOGLE AI STUDIO ---
// Sélecteurs multiples avec fallbacks pour différentes versions de l'interface
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

/**
 * Utilititaire pour attendre la disponibilité d'un élément dans le DOM avec plusieurs sélecteurs.
 */
function waitForElement(selectors: string[], timeout = 10000): Promise<Element> {
    return new Promise((resolve, reject) => {
        const intervalTime = 300;
        let elapsedTime = 0;

        const interval = setInterval(() => {
            for (const selector of selectors) {
                const element = document.querySelector(selector);
                if (element) {
                    clearInterval(interval);
                    console.log(`Found element with selector: ${selector}`);
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

/**
 * Debug: Affiche les éléments disponibles sur la page
 */
function debugPageElements() {
    console.log("=== DEBUG: Page Elements ===");

    // Chercher toutes les zones de saisie de texte
    const textInputs = document.querySelectorAll('textarea, input[type="text"], [contenteditable="true"]');
    console.log(`Found ${textInputs.length} text inputs:`, textInputs);

    // Chercher tous les boutons
    const buttons = document.querySelectorAll('button');
    console.log(`Found ${buttons.length} buttons:`, buttons);

    // Chercher les conteneurs de réponse
    const containers = document.querySelectorAll('[class*="response"], [class*="message"], [class*="content"]');
    console.log(`Found ${containers.length} response containers:`, containers);
}

/**
 * Notifie la couche Dart d'un événement via le JavaScriptHandler.
 */
function notifyDart(event: { type: 'GENERATION_COMPLETE' | 'AUTOMATION_FAILED', payload?: any }) {
    // @ts-ignore
    if (window.flutter_inappwebview) {
        // @ts-ignore
        window.flutter_inappwebview.callHandler('automationBridge', event);
    } else {
        console.log("Mock Dart Notification:", event);
    }
}

/**
 * Démarre le workflow d'automatisation. Exposée globalement.
 */
async function startAutomation(prompt: string): Promise<void> {
    try {
        console.log("Starting automation with prompt:", prompt);

        // Debug la page pour comprendre la structure
        debugPageElements();

        // Attendre et trouver la zone de saisie
        console.log("Looking for input element...");
        const inputArea = await waitForElement(PROMPT_INPUT_SELECTORS) as any;

        // Différentes méthodes pour insérer le texte selon le type d'élément
        if (inputArea.tagName === 'TEXTAREA' || inputArea.tagName === 'INPUT') {
            inputArea.value = prompt;
            // Déclencher les événements pour que l'interface réagisse
            inputArea.dispatchEvent(new Event('input', { bubbles: true }));
            inputArea.dispatchEvent(new Event('change', { bubbles: true }));
        } else if (inputArea.contentEditable === 'true') {
            inputArea.innerText = prompt;
            inputArea.dispatchEvent(new Event('input', { bubbles: true }));
        } else {
            // Fallback: essayer de cliquer puis de taper
            inputArea.click();
            await new Promise(resolve => setTimeout(resolve, 500));
            (inputArea as any).value = prompt;
        }

        console.log("Prompt inserted successfully");

        // Attendre et trouver le bouton d'envoi
        console.log("Looking for send button...");
        const sendButton = await waitForElement(SEND_BUTTON_SELECTORS) as HTMLElement;
        sendButton.click();

        console.log("Send button clicked, waiting for response...");

        // Attendre un peu que la génération commence
        await new Promise(resolve => setTimeout(resolve, 2000));

        // Simplifié: Attendre un temps fixe puis chercher la réponse
        await new Promise<void>((resolve, reject) => {
            const timeout = 45000; // 45s max
            let checkCount = 0;

            const checkResponse = async () => {
                checkCount++;
                console.log(`Checking for response... (${checkCount})`);

                // Chercher des indicateurs de génération en cours
                const isGenerating = GENERATION_INDICATOR_SELECTORS.some(selector =>
                    document.querySelector(selector)
                );

                if (isGenerating) {
                    console.log("Generation in progress...");
                    setTimeout(checkResponse, 2000);
                    return;
                }

                // Chercher une réponse
                const responseElements = RESPONSE_CONTAINER_SELECTORS.map(selector =>
                    document.querySelectorAll(selector)
                ).flat();

                if (responseElements.length > 0) {
                    console.log("Response found!");
                    notifyDart({ type: 'GENERATION_COMPLETE' });
                    resolve();
                } else if (checkCount * 2000 >= timeout) {
                    console.log("Generation timeout - no response found");
                    notifyDart({ type: 'GENERATION_COMPLETE' }); // Considérer comme complet même sans réponse
                    resolve();
                } else {
                    setTimeout(checkResponse, 2000);
                }
            };

            checkResponse();
        });

    } catch (error) {
        console.error("Automation failed:", error);
        notifyDart({ type: 'AUTOMATION_FAILED', payload: error instanceof Error ? error.message : String(error) });
        throw error;
    }
}

/**
 * Extrait le contenu de la dernière réponse. Exposée globalement.
 */
async function extractFinalResponse(): Promise<string> {
    try {
        console.log("Extracting final response...");

        // Rechercher avec tous les sélecteurs possibles
        let allResponses: HTMLElement[] = [];

        for (const selector of RESPONSE_CONTAINER_SELECTORS) {
            const elements = Array.from(document.querySelectorAll(selector)) as HTMLElement[];
            allResponses.push(...elements);
        }

        // Si toujours rien, essayer une recherche plus large
        if (allResponses.length === 0) {
            console.log("Trying broader search for response content...");

            // Chercher tous les éléments contenant du texte potentiel de réponse
            const candidates = Array.from(document.querySelectorAll('*')) as HTMLElement[];

            allResponses = candidates.filter(el => {
                const text = el.innerText?.trim() || '';
                const hasContent = text.length > 50; // Au moins 50 caractères
                const notInput = !el.matches('input, textarea, button, select, option');
                const visible = el.offsetParent !== null;

                return hasContent && notInput && visible;
            });
        }

        if (allResponses.length === 0) {
            console.log("No response found, returning page content as fallback");
            // Fallback: retourner le contenu textuel de la page
            const bodyText = document.body?.innerText || '';
            return bodyText.trim() || "No response available";
        }

        // Prendre le dernier élément (le plus récent)
        const lastResponse = allResponses[allResponses.length - 1];
        const responseText = lastResponse.innerText?.trim() || "";

        console.log(`Extracted response (${responseText.length} characters)`);
        return responseText;

    } catch (error) {
        console.error("Extraction failed:", error);
        notifyDart({ type: 'AUTOMATION_FAILED', payload: error instanceof Error ? error.message : String(error) });
        throw error;
    }
}

// Exposer les fonctions sur l'objet window pour qu'elles soient appelables depuis Dart
// @ts-ignore
window.startAutomation = startAutomation;
// @ts-ignore
window.extractFinalResponse = extractFinalResponse;