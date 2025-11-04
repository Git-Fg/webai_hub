abstract class JavaScriptBridgeInterface {
  Future<void> waitForBridgeReady();
  Future<void> startAutomation(String prompt);
  Future<String> extractFinalResponse();
  Future<void> startResponseObserver();
  // SUPPRIMÉ : waitForResponseCompletion n'est plus nécessaire
}
