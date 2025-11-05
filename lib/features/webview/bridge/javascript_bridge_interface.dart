import 'package:flutter_inappwebview/flutter_inappwebview.dart';

abstract class JavaScriptBridgeInterface {
  Future<void> loadUrlAndWaitForReady(URLRequest urlRequest);
  Future<void> waitForBridgeReady();
  Future<void> startAutomation(String prompt);
  Future<String> extractFinalResponse();
  Future<void> startResponseObserver();
}
