(async () => {
    console.clear();
    console.log("🚀 Starting AI Studio selector validation test (v3 - Full Cycle)...");
  
    // --- Fonctions d'aide ---
    const testSelector = (name, selector, root = document) => {
      const element = root.querySelector(selector);
      if (element) {
        console.log(`✅ [SUCCESS] Selector "${name}" found:`, element);
        return element;
      } else {
        console.error(`❌ [FAIL] Selector "${name}" (${selector}) not found.`);
        return null;
      }
    };
    
    const testSelectorAllAndTakeLast = (name, selector) => {
      const elements = document.querySelectorAll(selector);
      if (elements.length > 0) {
        const lastElement = elements[elements.length - 1];
        console.log(`✅ [SUCCESS] Selector "${name}" found (${elements.length} matches). Selecting the last:`, lastElement);
        return lastElement;
      } else {
        console.error(`❌ [FAIL] Selector "${name}" (${selector}) returned no matches.`);
        return null;
      }
    };
    
    const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));
  
    // --- Début des tests ---
    let hasFailed = false;
  
    try {
      // --- ÉTAPE 1: Trouver le dernier message de l'assistant via :has() ---
      console.log("\n--- Step 1: Find the last assistant message ---");
      const lastTurn = testSelectorAllAndTakeLast(
        "Last AI message",
        'ms-chat-turn:has(button[aria-label="Edit"])'
      );
      if (!lastTurn) throw new Error("Step 1 failed.");
  
      // --- ÉTAPE 2: Trouver le bouton "Edit" DANS ce message et cliquer ---
      console.log("\n--- Step 2: Enter edit mode ---");
      const editButton = testSelector(
        "'Edit' button",
        'button[aria-label="Edit"]',
        lastTurn
      );
      if (!editButton) throw new Error("Step 2 failed (Edit button not found).");
      
      console.log("   -> Clicking the 'Edit' button...");
      (editButton).click();
  
      // --- ÉTAPE 3: Attendre l'apparition du textarea et extraire le contenu ---
      console.log("\n--- Step 3: Extract content ---");
      await delay(500); // Wait for the DOM to update
  
      const textarea = testSelector(
        "Editing textarea",
        'textarea',
        lastTurn
      );
      if (!textarea) throw new Error("Step 3 failed (textarea not found).");
  
      const extractedContent = textarea.value || "";
      console.log("   -> ✨ Extracted content (sample):", extractedContent.substring(0, 100) + "...");
  
      // --- NOUVELLE ÉTAPE 4: Sortir du mode édition ---
      console.log("\n--- Step 4: Exit edit mode ---");
      const stopEditingButton = testSelector(
        "'Stop editing' button",
        'button[aria-label="Stop editing"]', // The new key selector!
        lastTurn
      );
      if (!stopEditingButton) throw new Error("Step 4 failed (Stop editing button not found).");
  
      console.log("   -> Clicking the 'Stop editing' button...");
      (stopEditingButton).click();
  
      // --- ÉTAPE 5: Vérification finale (optionnelle mais recommandée) ---
      console.log("\n--- Step 5: Verify exit from edit mode ---");
      await delay(500); // Wait for the DOM to update
      
      const textareaAfter = lastTurn.querySelector('textarea');
      if (textareaAfter) {
          console.warn("⚠️ [WARNING] The textarea is still present after exiting edit mode.");
          // Not a blocking failure, but worth noting.
      } else {
          console.log("   -> ✅ The textarea disappeared. Exit from edit mode confirmed.");
      }
  
  
    } catch (e) {
      hasFailed = true;
      console.error(`\n🔥 Test aborted: ${e.message}`);
    }
  
    // --- RAPPORT FINAL ---
    console.log("\n--- Final Report ---");
    if (hasFailed) {
      console.error("❌ At least one critical selector failed. The extraction cycle is broken.");
    } else {
      console.log("✅ The full extraction cycle (Input -> Extraction -> Exit) has been validated successfully!");
    }
  })();