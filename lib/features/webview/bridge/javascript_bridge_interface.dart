abstract class JavaScriptBridgeInterface {
  Future<void> waitForBridgeReady();
  Future<void> startAutomation(String prompt);
  Future<String> extractFinalResponse();
  // SUPPRIMÉ : waitForResponseCompletion n'est plus nécessaire
}
