abstract class JavaScriptBridgeInterface {
  Future<void> waitForBridgeReady();
  Future<void> startAutomation(
    String providerId,
    String prompt,
    String settingsJson,
    double timeoutModifier,
  );
  Future<String> extractFinalResponse();
  // WHY: Heartbeat check to detect dead contexts (only implemented in JavaScriptBridge)
  // Checks JS context responsiveness, not bridge initialization state
  Future<bool> isBridgeAlive();
  // WHY: Get captured console logs for debugging purposes
  Future<List<Map<String, dynamic>>> getCapturedLogs();
}
