(async () => {
    console.clear();
    console.log("🚀 Démarrage du test de validation des sélecteurs pour AI Studio (v3 - Cycle Complet)...");
  
    // --- Fonctions d'aide ---
    const testSelector = (name, selector, root = document) => {
      const element = root.querySelector(selector);
      if (element) {
        console.log(`✅ [SUCCÈS] Sélecteur "${name}" trouvé :`, element);
        return element;
      } else {
        console.error(`❌ [ÉCHEC] Sélecteur "${name}" (${selector}) non trouvé.`);
        return null;
      }
    };
    
    const testSelectorAllAndTakeLast = (name, selector) => {
      const elements = document.querySelectorAll(selector);
      if (elements.length > 0) {
        const lastElement = elements[elements.length - 1];
        console.log(`✅ [SUCCÈS] Sélecteur "${name}" trouvé (${elements.length} correspondances). Sélection du dernier :`, lastElement);
        return lastElement;
      } else {
        console.error(`❌ [ÉCHEC] Sélecteur "${name}" (${selector}) n'a trouvé aucune correspondance.`);
        return null;
      }
    };
    
    const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));
  
    // --- Début des tests ---
    let hasFailed = false;
  
    try {
      // --- ÉTAPE 1: Trouver le dernier message de l'assistant via :has() ---
      console.log("\n--- Étape 1: Recherche du dernier message de l'assistant ---");
      const lastTurn = testSelectorAllAndTakeLast(
        "Dernier message de l'IA",
        'ms-chat-turn:has(button[aria-label="Edit"])'
      );
      if (!lastTurn) throw new Error("Étape 1 échouée.");
  
      // --- ÉTAPE 2: Trouver le bouton "Edit" DANS ce message et cliquer ---
      console.log("\n--- Étape 2: Passage en mode édition ---");
      const editButton = testSelector(
        "Bouton 'Edit'",
        'button[aria-label="Edit"]',
        lastTurn
      );
      if (!editButton) throw new Error("Étape 2 échouée (bouton Edit introuvable).");
      
      console.log("   -> Clic sur le bouton 'Edit'...");
      (editButton).click();
  
      // --- ÉTAPE 3: Attendre l'apparition du textarea et extraire le contenu ---
      console.log("\n--- Étape 3: Extraction du contenu ---");
      await delay(500); // Attente pour que le DOM se mette à jour
  
      const textarea = testSelector(
        "Textarea d'édition",
        'textarea',
        lastTurn
      );
      if (!textarea) throw new Error("Étape 3 échouée (textarea introuvable).");
  
      const extractedContent = textarea.value || "";
      console.log("   -> ✨ Contenu extrait (échantillon) :", extractedContent.substring(0, 100) + "...");
  
      // --- NOUVELLE ÉTAPE 4: Sortir du mode édition ---
      console.log("\n--- Étape 4: Sortie du mode édition ---");
      const stopEditingButton = testSelector(
        "Bouton 'Stop editing'",
        'button[aria-label="Stop editing"]', // Le nouveau sélecteur clé !
        lastTurn
      );
      if (!stopEditingButton) throw new Error("Étape 4 échouée (bouton Stop editing introuvable).");
  
      console.log("   -> Clic sur le bouton 'Stop editing'...");
      (stopEditingButton).click();
  
      // --- ÉTAPE 5: Vérification finale (optionnelle mais recommandée) ---
      console.log("\n--- Étape 5: Vérification de la sortie du mode édition ---");
      await delay(500); // Attente pour que le DOM se mette à jour
      
      const textareaAfter = lastTurn.querySelector('textarea');
      if (textareaAfter) {
          console.warn("⚠️ [AVERTISSEMENT] Le textarea est toujours présent après avoir quitté le mode édition.");
          // Ce n'est pas un échec bloquant, mais c'est bon à savoir.
      } else {
          console.log("   -> ✅ Le textarea a bien disparu. Sortie du mode édition confirmée.");
      }
  
  
    } catch (e) {
      hasFailed = true;
      console.error(`\n🔥 Le test a été interrompu : ${e.message}`);
    }
  
    // --- RAPPORT FINAL ---
    console.log("\n--- Rapport Final ---");
    if (hasFailed) {
      console.error("❌ Au moins un sélecteur critique a échoué. Le cycle d'extraction est cassé.");
    } else {
      console.log("✅ Tout le cycle d'extraction (Entrée -> Extraction -> Sortie) a été validé avec succès !");
    }
  })();