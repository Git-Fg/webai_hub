import 'package:flutter_inappwebview/flutter_inappwebview.dart';

abstract class JavaScriptBridgeInterface {
  Future<void> loadUrlAndWaitForReady(URLRequest urlRequest);
  Future<void> waitForBridgeReady();
  Future<void> startAutomation(Map<String, dynamic> options);
  Future<String> extractFinalResponse();
  Future<void> startResponseObserver();
  // WHY: Heartbeat check to detect dead contexts (only implemented in JavaScriptBridge)
  // Checks JS context responsiveness, not bridge initialization state
  Future<bool> isBridgeAlive();
}
