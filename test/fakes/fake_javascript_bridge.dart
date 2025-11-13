import 'dart:async';
import 'package:ai_hybrid_hub/features/webview/bridge/automation_errors.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge_interface.dart';

enum ErrorType {
  none,
  genericException,
  automationError,
}

// Enhanced error configuration for more granular control
class ErrorConfig {
  // Simulate delay before error

  const ErrorConfig({
    required this.type,
    this.errorCode,
    this.message,
    this.diagnostics,
    this.delayMs,
  });
  final ErrorType type;
  final AutomationErrorCode? errorCode;
  final String? message;
  final Map<String, dynamic>? diagnostics;
  final int? delayMs;

  static const ErrorConfig none = ErrorConfig(type: ErrorType.none);
}

class FakeJavaScriptBridge implements JavaScriptBridgeInterface {
  // For verifying that methods were called
  String? lastPromptSent;
  String? lastProviderId;
  String? lastSettingsJson;
  double? lastTimeoutModifier;
  bool wasExtractCalled = false;
  int startAutomationCallCount = 0;
  int extractFinalResponseCallCount = 0;

  // Enhanced error configuration
  ErrorConfig startAutomationErrorConfig = ErrorConfig.none;
  ErrorConfig extractFinalResponseErrorConfig = ErrorConfig.none;
  String? extractFinalResponseValue =
      'This is a fake AI response from the test bridge.';

  // Bridge readiness simulation
  bool _isReady = true;
  int? readinessDelayMs;

  // Legacy support: if shouldThrowError is true, throw a generic Exception
  bool get shouldThrowError =>
      startAutomationErrorConfig.type == ErrorType.genericException ||
      extractFinalResponseErrorConfig.type == ErrorType.genericException;

  set shouldThrowError(bool value) {
    if (value) {
      startAutomationErrorConfig = const ErrorConfig(
        type: ErrorType.genericException,
      );
      extractFinalResponseErrorConfig = const ErrorConfig(
        type: ErrorType.genericException,
      );
    } else {
      startAutomationErrorConfig = ErrorConfig.none;
      extractFinalResponseErrorConfig = ErrorConfig.none;
    }
  }

  // --- NEW: Async control for the bridge readiness state ---
  // Allow tests to simulate a page reload: the bridge becomes not-ready again
  void simulateReload({int? delayMs}) {
    _isReady = false;
    readinessDelayMs = delayMs;
  }

  // Allow tests to mark the bridge as ready again
  void markAsReady() {
    _isReady = true;
    readinessDelayMs = null;
  }

  // Set custom error for startAutomation
  void setStartAutomationError({
    required ErrorType type,
    AutomationErrorCode? errorCode,
    String? message,
    Map<String, dynamic>? diagnostics,
    int? delayMs,
  }) {
    startAutomationErrorConfig = ErrorConfig(
      type: type,
      errorCode: errorCode,
      message: message,
      diagnostics: diagnostics,
      delayMs: delayMs,
    );
  }

  // Set custom error for extractFinalResponse
  void setExtractFinalResponseError({
    required ErrorType type,
    AutomationErrorCode? errorCode,
    String? message,
    Map<String, dynamic>? diagnostics,
    int? delayMs,
  }) {
    extractFinalResponseErrorConfig = ErrorConfig(
      type: type,
      errorCode: errorCode,
      message: message,
      diagnostics: diagnostics,
      delayMs: delayMs,
    );
  }

  // Set custom response value
  void setExtractFinalResponseValue(String value) {
    extractFinalResponseValue = value;
  }

  @override
  Future<void> waitForBridgeReady() async {
    // Use a polling approach similar to the main implementation
    const checkInterval = Duration(milliseconds: 50);
    const maxWaitTime = Duration(seconds: 30);
    final startTime = DateTime.now();

    // Apply readiness delay if configured
    if (readinessDelayMs != null) {
      await Future<void>.delayed(Duration(milliseconds: readinessDelayMs!));
      _isReady = true;
      readinessDelayMs = null;
    }

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
  Future<void> startAutomation(
    String providerId,
    String prompt,
    String settingsJson,
    double timeoutModifier,
  ) async {
    startAutomationCallCount++;

    // Apply delay before error if configured
    if (startAutomationErrorConfig.delayMs != null) {
      await Future<void>.delayed(
        Duration(milliseconds: startAutomationErrorConfig.delayMs!),
      );
    }

    // Simulate a network delay
    await Future<void>.delayed(const Duration(milliseconds: 50));

    switch (startAutomationErrorConfig.type) {
      case ErrorType.genericException:
        throw Exception(
          startAutomationErrorConfig.message ?? 'Fake automation error',
        );
      case ErrorType.automationError:
        throw AutomationError(
          errorCode:
              startAutomationErrorConfig.errorCode ??
              AutomationErrorCode.automationExecutionFailed,
          location: 'startAutomation',
          message:
              startAutomationErrorConfig.message ??
              'Fake automation execution failed for testing',
          diagnostics:
              startAutomationErrorConfig.diagnostics ??
              {'providerId': providerId, 'prompt': prompt},
        );
      case ErrorType.none:
        // Record options for verification
        lastPromptSent = prompt;
        lastProviderId = providerId;
        lastSettingsJson = settingsJson;
        lastTimeoutModifier = timeoutModifier;
    }
  }

  @override
  Future<String> extractFinalResponse() async {
    extractFinalResponseCallCount++;

    // Apply delay before error if configured
    if (extractFinalResponseErrorConfig.delayMs != null) {
      await Future<void>.delayed(
        Duration(milliseconds: extractFinalResponseErrorConfig.delayMs!),
      );
    }

    // Simulate a network delay
    await Future<void>.delayed(const Duration(milliseconds: 50));

    switch (extractFinalResponseErrorConfig.type) {
      case ErrorType.genericException:
        throw Exception(
          extractFinalResponseErrorConfig.message ?? 'Fake extraction error',
        );
      case ErrorType.automationError:
        throw AutomationError(
          errorCode:
              extractFinalResponseErrorConfig.errorCode ??
              AutomationErrorCode.responseExtractionFailed,
          location: 'extractFinalResponse',
          message:
              extractFinalResponseErrorConfig.message ??
              'Fake response extraction failed for testing',
          diagnostics:
              extractFinalResponseErrorConfig.diagnostics ??
              {'wasExtractCalled': wasExtractCalled},
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

  // Method to simulate getCapturedLogs (used by conversation_provider)
  @override
  Future<List<Map<String, dynamic>>> getCapturedLogs() async {
    return [];
  }

  // Utility method to reset state between tests
  void reset() {
    lastPromptSent = null;
    lastProviderId = null;
    lastSettingsJson = null;
    lastTimeoutModifier = null;
    wasExtractCalled = false;
    startAutomationCallCount = 0;
    extractFinalResponseCallCount = 0;
    startAutomationErrorConfig = ErrorConfig.none;
    extractFinalResponseErrorConfig = ErrorConfig.none;
    extractFinalResponseValue =
        'This is a fake AI response from the test bridge.';
    // Reset readiness to true by default to avoid hanging tests
    _isReady = true;
    readinessDelayMs = null;
  }

  @override
  Future<bool> isBridgeAlive() async {
    // WHY: Fake bridge always reports as alive for testing
    return true;
  }
}
