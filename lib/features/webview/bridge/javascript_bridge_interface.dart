abstract class JavaScriptBridgeInterface {
  Future<void> waitForBridgeReady();
  Future<void> startAutomation(String prompt);
  Future<String> extractFinalResponse();
  Future<bool> waitForResponseCompletion({Duration timeout});
}
