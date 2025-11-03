// ts_src/types/chatbot.ts

// Interface décrivant les capacités d'un module de chatbot.
// Pour le MVP, on se concentre sur l'essentiel.
export interface Chatbot {
  /**
   * Une fonction qui attend que la page du chatbot soit complètement chargée et prête pour l'automatisation.
   */
  waitForReady: () => Promise<void>;

  /**
   * Trouve la zone de saisie, y insère le prompt, et clique sur le bouton d'envoi.
   * Doit retourner une promesse qui se résout une fois la génération de la réponse terminée.
   * @param prompt Le message à envoyer.
   */
  sendPrompt: (prompt: string) => Promise<void>;

  /**
   * Extrait le texte de la dernière réponse du modèle, de manière nettoyée.
   */
  extractResponse: () => Promise<string>;
}

