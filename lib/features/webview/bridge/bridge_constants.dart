// lib/features/webview/bridge/bridge_constants.dart

/// Constants for JavaScript bridge handlers and event types.
///
/// These constants centralize all magic strings used in the communication
/// between Dart and the JavaScript bridge, preventing typos and making
/// the code more maintainable.
class BridgeConstants {
  BridgeConstants._();

  /// Handler name for automation events from JavaScript to Dart
  static const String automationHandler = 'automationBridge';

  /// Handler name for bridge readiness signal from JavaScript to Dart
  static const String readyHandler = 'bridgeReady';

  /// Event type: New AI response detected in the WebView
  static const String eventTypeNewResponse = 'NEW_RESPONSE_DETECTED';

  /// Event type: User login required to access the AI service
  static const String eventTypeLoginRequired = 'LOGIN_REQUIRED';

  /// Event type: Automation failed with an error
  static const String eventTypeAutomationFailed = 'AUTOMATION_FAILED';

  /// Event type: Automation retry required due to transient error
  static const String eventTypeAutomationRetryRequired = 'AUTOMATION_RETRY_REQUIRED';
}
