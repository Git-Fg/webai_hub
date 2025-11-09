import 'dart:async';
import 'package:ai_hybrid_hub/features/webview/bridge/automation_errors.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge_interface.dart';

enum ErrorType {
  none,
  genericException,
  automationError,
}

class FakeJavaScriptBridge implements JavaScriptBridgeInterface {
  // For verifying that methods were called
  String? lastPromptSent;
  Map<String, dynamic>? lastOptionsSent;
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
  late Completer<void> _readyCompleter = Completer<void>()..complete();

  // Allow tests to simulate a page reload: the bridge becomes not-ready again
  void simulateReload() {
    _readyCompleter = Completer<void>();
  }

  // Allow tests to mark the bridge as ready again
  void markAsReady() {
    if (!_readyCompleter.isCompleted) {
      _readyCompleter.complete();
    }
  }

  @override
  Future<void> waitForBridgeReady() async {
    // Explicitly wait until tests mark the bridge as ready
    await _readyCompleter.future;
  }

  @override
  Future<void> startAutomation(Map<String, dynamic> options) async {
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
          diagnostics: {'options': options},
        );
      case ErrorType.none:
        // Record the options for verification
        lastOptionsSent = options;
        lastPromptSent = options['prompt'] as String?;
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
    // Reset readiness to completed by default to avoid hanging tests
    _readyCompleter = Completer<void>()..complete();
  }

  @override
  Future<bool> isBridgeAlive() async {
    // WHY: Fake bridge always reports as alive for testing
    return true;
  }
}
