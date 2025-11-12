import 'package:ai_hybrid_hub/features/webview/bridge/automation_options.dart';

abstract class JavaScriptBridgeInterface {
  Future<void> waitForBridgeReady();
  Future<void> startAutomation(AutomationOptions options);
  Future<String> extractFinalResponse();
  // WHY: Heartbeat check to detect dead contexts (only implemented in JavaScriptBridge)
  // Checks JS context responsiveness, not bridge initialization state
  Future<bool> isBridgeAlive();
  // WHY: Get captured console logs for debugging purposes
  Future<List<Map<String, dynamic>>> getCapturedLogs();
}
