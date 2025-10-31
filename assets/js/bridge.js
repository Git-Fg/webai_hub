/**
 * HubBridge - Modern JavaScript Bridge for WebAI Hub
 * Implements the "Contrat d'API" from BLUEPRINT.md Section 7
 * Inspired by Code Web Chat (CWC) architecture
 */

class HubBridge {
  constructor(channelName, providerName) {
    this.channelName = channelName; // ex: 'KimiBridge'
    this.providerName = providerName; // ex: 'kimi'
    this.messageQueue = [];
    this.isBridgeReady = false;
    this.observer = null;
    this.generationCheckInterval = null;
    this.selectors = null;
    
    console.log(`[HubBridge] Initializing bridge for ${providerName} (channel: ${channelName})`);
  }

  /**
   * Initialize the bridge and flush any queued messages
   */
  init() {
    this.isBridgeReady = true;
    console.log(`[HubBridge] Bridge ready for ${this.providerName}`);
    
    // Flush message queue
    while (this.messageQueue.length > 0) {
      const queuedMessage = this.messageQueue.shift();
      console.log('[HubBridge] Sending queued message:', queuedMessage);
      this.postMessage(queuedMessage);
    }
  }

  /**
   * Send message to native layer
   */
  postMessage(message) {
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      const jsonMessage = JSON.stringify(message);
      console.log(`[HubBridge] Sending to native:`, message);
      window.flutter_inappwebview.callHandler(this.channelName, jsonMessage);
    } else {
      console.log('[HubBridge] Bridge not ready, queuing message:', message);
      this.messageQueue.push(message);
    }
  }

  /**
   * Helper to find element using defense-in-depth selector array
   */
  findElement(selectorArray, timeout = 10000) {
    return new Promise((resolve, reject) => {
      const startTime = Date.now();
      
      const checkElement = () => {
        // Try each selector in order
        for (const selector of selectorArray) {
          try {
            const element = document.querySelector(selector);
            if (element) {
              console.log(`[HubBridge] Found element with selector: ${selector}`);
              return resolve(element);
            }
          } catch (e) {
            console.warn(`[HubBridge] Invalid selector: ${selector}`, e);
          }
        }
        
        // Check timeout
        if (Date.now() - startTime > timeout) {
          return reject(new Error(`Timeout: Could not find element. Tried selectors: ${selectorArray.join(', ')}`));
        }
        
        // Retry
        setTimeout(checkElement, 100);
      };
      
      checkElement();
    });
  }

  /**
   * Check the status of the provider (ready or needs login)
   * Implements Section 3.2 of BLUEPRINT.md
   */
  async checkStatus(selectors) {
    console.log('[HubBridge] Checking status...');
    this.selectors = selectors;
    
    try {
      // Try to find the prompt textarea (indicates ready state)
      await this.findElement(selectors.checkStatus, 5000);
      this.postMessage({ 
        event: 'onStatusResult', 
        payload: { status: 'ready' } 
      });
    } catch (e) {
      // If not found, check for login page
      try {
        await this.findElement(selectors.loginCheck, 2000);
        this.postMessage({ 
          event: 'onStatusResult', 
          payload: { status: 'login' } 
        });
      } catch (e2) {
        // Can't determine status - might be loading
        this.postMessage({ 
          event: 'onStatusResult', 
          payload: { status: 'unknown' } 
        });
      }
    }
  }

  /**
   * Start the automation workflow
   * Implements Phases 1 & 2 from BLUEPRINT.md Section 4
   */
  async start(prompt, options, selectors) {
    console.log('[HubBridge] Starting automation with prompt:', prompt.substring(0, 50) + '...');
    this.selectors = selectors;
    
    try {
      // Phase 1: Wait until ready
      console.log('[HubBridge] Phase 1: Waiting for page to be ready...');
      const textarea = await this.findElement(selectors.promptTextarea, 10000);
      
      // Phase 1b: Apply options if provided (set_options / set_model logic)
      if (options && options.model) {
        console.log('[HubBridge] Applying options:', options);
        // This would simulate clicks to configure the provider
        // For MVP, we skip this complex logic
      }
      
      // Phase 1c: Inject prompt and send
      console.log('[HubBridge] Injecting prompt into textarea...');
      
      // Clear existing content
      textarea.value = '';
      
      // Set the prompt
      textarea.value = prompt;
      
      // Trigger input event (some frameworks need this)
      textarea.dispatchEvent(new Event('input', { bubbles: true }));
      textarea.dispatchEvent(new Event('change', { bubbles: true }));
      
      // Wait a bit for the UI to update
      await new Promise(resolve => setTimeout(resolve, 300));
      
      // Find and click send button
      console.log('[HubBridge] Looking for send button...');
      const sendButton = await this.findElement(selectors.sendButton, 5000);
      
      console.log('[HubBridge] Clicking send button...');
      sendButton.click();
      
      // Phase 2: Start observing for response completion
      console.log('[HubBridge] Phase 2: Starting observation for generation completion...');
      this.observeForCompletion(selectors);
      
    } catch (error) {
      console.error('[HubBridge] Injection failed:', error);
      this.postMessage({ 
        event: 'onInjectionFailed', 
        payload: { error: error.message } 
      });
    }
  }

  /**
   * Observe DOM for generation completion
   * Implements observe_for_responses from Section 6
   */
  observeForCompletion(selectors) {
    console.log('[HubBridge] Setting up MutationObserver...');
    
    // Use polling to check for generation status
    this.generationCheckInterval = setInterval(() => {
      // Check if "stop" button is still present (generation in progress)
      const isGenerating = this.checkIfGenerating(selectors.isGenerating);
      
      if (!isGenerating) {
        console.log('[HubBridge] Generation completed!');
        this.stopObserving();
        this.postMessage({ 
          event: 'onGenerationComplete' 
        });
      }
    }, 500);
    
    // Also set up MutationObserver for chat container changes
    const chatContainer = document.body;
    this.observer = new MutationObserver((mutations) => {
      // Check generation status on any DOM change
      const isGenerating = this.checkIfGenerating(selectors.isGenerating);
      
      if (!isGenerating && this.generationCheckInterval) {
        console.log('[HubBridge] Generation completed (detected via MutationObserver)!');
        this.stopObserving();
        this.postMessage({ 
          event: 'onGenerationComplete' 
        });
      }
    });
    
    this.observer.observe(chatContainer, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['disabled', 'aria-disabled', 'class']
    });
  }

  /**
   * Check if generation is in progress by looking for stop button
   */
  checkIfGenerating(isGeneratingSelectors) {
    for (const selector of isGeneratingSelectors) {
      try {
        const stopButton = document.querySelector(selector);
        if (stopButton) {
          // Check if button is actually visible and enabled
          const style = window.getComputedStyle(stopButton);
          const isVisible = style.display !== 'none' && 
                          style.visibility !== 'hidden' &&
                          style.opacity !== '0';
          const isEnabled = !stopButton.disabled && 
                          stopButton.getAttribute('aria-disabled') !== 'true';
          
          if (isVisible && isEnabled) {
            return true;
          }
        }
      } catch (e) {
        // Invalid selector, continue
      }
    }
    return false;
  }

  /**
   * Stop all observers
   */
  stopObserving() {
    if (this.observer) {
      this.observer.disconnect();
      this.observer = null;
    }
    if (this.generationCheckInterval) {
      clearInterval(this.generationCheckInterval);
      this.generationCheckInterval = null;
    }
  }

  /**
   * Extract the final assistant response
   * Implements Phase 4 from BLUEPRINT.md Section 4
   * Uses Section 8.2 extraction logic
   */
  async getFinalResponse(selectors) {
    console.log('[HubBridge] Extracting final response...');
    this.selectors = selectors;
    
    try {
      // Find all assistant response elements
      const responses = [];
      
      for (const selector of selectors.assistantResponse) {
        try {
          const elements = document.querySelectorAll(selector);
          if (elements.length > 0) {
            console.log(`[HubBridge] Found ${elements.length} responses with selector: ${selector}`);
            // Take the last element (most recent response)
            const lastElement = elements[elements.length - 1];
            
            // Extract content (innerHTML to preserve formatting)
            const content = lastElement.innerHTML;
            
            if (content && content.trim().length > 0) {
              this.postMessage({ 
                event: 'onExtractionResult', 
                payload: { content: content } 
              });
              return;
            }
          }
        } catch (e) {
          console.warn(`[HubBridge] Invalid selector: ${selector}`, e);
        }
      }
      
      // If we get here, no content was found
      throw new Error('No assistant response found');
      
    } catch (error) {
      console.error('[HubBridge] Extraction failed:', error);
      this.postMessage({ 
        event: 'onExtractionFailed', 
        payload: { error: error.message } 
      });
    }
  }

  /**
   * Cancel the current automation
   */
  cancel() {
    console.log('[HubBridge] Cancelling automation...');
    this.stopObserving();
    this.postMessage({ 
      event: 'onCancelled' 
    });
  }
}

// Don't auto-initialize - let the native side do it
// The bridge will be initialized per provider when needed
console.log('[HubBridge] Bridge class loaded and ready for initialization');
