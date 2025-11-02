abstract class JavaScriptBridgeInterface {
  Future<void> startAutomation(String prompt);
  Future<String> extractFinalResponse();
}
