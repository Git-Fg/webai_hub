import 'dart:async';
import 'package:ai_hybrid_hub/features/webview/bridge/automation_errors.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/automation_options.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge_interface.dart';

enum ErrorType {
  none,
  genericException,
  automationError,
}

class FakeJavaScriptBridge implements JavaScriptBridgeInterface {
  // For verifying that methods were called
  String? lastPromptSent;
  AutomationOptions? lastOptionsSent;
  bool wasExtractCalled = false;

  // To simulate errors — separated per method
  ErrorType startAutomationErrorType = ErrorType.none;
  ErrorType extractFinalResponseErrorType = ErrorType.none;
  String? extractFinalResponseValue =
      'This is a fake AI response from the test bridge.';

  // Legacy support: if shouldThrowError is true, throw a generic Exception
  bool get shouldThrowError =>
      startAutomationErrorType == ErrorType.genericException ||
      extractFinalResponseErrorType == ErrorType.genericException;

  set shouldThrowError(bool value) {
    if (value) {
      startAutomationErrorType = ErrorType.genericException;
      extractFinalResponseErrorType = ErrorType.genericException;
    } else {
      startAutomationErrorType = ErrorType.none;
      extractFinalResponseErrorType = ErrorType.none;
    }
  }

  // --- NEW: Async control for the bridge readiness state ---
  bool _isReady = true;

  // Allow tests to simulate a page reload: the bridge becomes not-ready again
  void simulateReload() {
    _isReady = false;
  }

  // Allow tests to mark the bridge as ready again
  void markAsReady() {
    _isReady = true;
  }

  @override
  Future<void> waitForBridgeReady() async {
    // Use a polling approach similar to the main implementation
    const checkInterval = Duration(milliseconds: 50);
    const maxWaitTime = Duration(seconds: 30);
    final startTime = DateTime.now();
    
    while (!_isReady) {
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed >= maxWaitTime) {
        throw TimeoutException(
          'Fake bridge did not become ready within the timeout period.',
          maxWaitTime,
        );
      }
      
      await Future<void>.delayed(checkInterval);
    }
  }

  @override
  Future<void> startAutomation(AutomationOptions options) async {
    // Simulate a network delay
    await Future<void>.delayed(const Duration(milliseconds: 50));

    switch (startAutomationErrorType) {
      case ErrorType.genericException:
        throw Exception('Fake automation error');
      case ErrorType.automationError:
        throw AutomationError(
          errorCode: AutomationErrorCode.automationExecutionFailed,
          location: 'startAutomation',
          message: 'Fake automation execution failed for testing',
          diagnostics: {'options': options.toJson()},
        );
      case ErrorType.none:
        // Record the options for verification
        lastOptionsSent = options;
        lastPromptSent = options.prompt;
    }
  }

  @override
  Future<String> extractFinalResponse() async {
    // Simulate a network delay
    await Future<void>.delayed(const Duration(milliseconds: 50));

    switch (extractFinalResponseErrorType) {
      case ErrorType.genericException:
        throw Exception('Fake extraction error');
      case ErrorType.automationError:
        throw AutomationError(
          errorCode: AutomationErrorCode.responseExtractionFailed,
          location: 'extractFinalResponse',
          message: 'Fake response extraction failed for testing',
          diagnostics: {'wasExtractCalled': wasExtractCalled},
        );
      case ErrorType.none:
        wasExtractCalled = true;
        if (extractFinalResponseValue == null) {
          throw AutomationError(
            errorCode: AutomationErrorCode.responseExtractionFailed,
            location: 'extractFinalResponse',
            message: 'Extraction returned null or an invalid type.',
          );
        }
        return extractFinalResponseValue!;
    }
  }

  // REMOVED: waitForResponseCompletion is no longer needed

  // Method to simulate getCapturedLogs (used by conversation_provider)
  @override
  Future<List<Map<String, dynamic>>> getCapturedLogs() async {
    return [];
  }

  // Utility method to reset state between tests
  void reset() {
    lastPromptSent = null;
    lastOptionsSent = null;
    wasExtractCalled = false;
    startAutomationErrorType = ErrorType.none;
    extractFinalResponseErrorType = ErrorType.none;
    extractFinalResponseValue =
        'This is a fake AI response from the test bridge.';
    // Reset readiness to true by default to avoid hanging tests
    _isReady = true;
  }

  @override
  Future<bool> isBridgeAlive() async {
    // WHY: Fake bridge always reports as alive for testing
    return true;
  }
}
