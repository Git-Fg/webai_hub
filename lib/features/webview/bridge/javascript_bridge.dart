import 'dart:async';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'automation_errors.dart';
import 'bridge_diagnostics_provider.dart';
import 'javascript_bridge_interface.dart';

part 'javascript_bridge.g.dart';

@riverpod
class WebViewController extends _$WebViewController {
  @override
  InAppWebViewController? build() => null;

  void setController(InAppWebViewController? controller) {
    state = controller;
  }
}

@riverpod
class BridgeReady extends _$BridgeReady {
  @override
  Completer<void> build() {
    return Completer<void>();
  }

  void complete() {
    if (!state.isCompleted) {
      state.complete();
    }
  }

  void reset() {
    state = Completer<void>();
  }
}

class JavaScriptBridge implements JavaScriptBridgeInterface {
  final Ref ref;
  JavaScriptBridge(this.ref);

  InAppWebViewController? get _controller =>
      ref.read(webViewControllerProvider);

  Map<String, dynamic> _getBridgeDiagnostics() {
    final completer = ref.read(bridgeReadyProvider);
    final controller = ref.read(webViewControllerProvider);
    return {
      'completerInitialized': true,
      'completerCompleted': completer.isCompleted,
      'webViewControllerExists': controller != null,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _waitForWebViewToBeCreated() async {
    int attempts = 0;
    const maxAttempts = 60;
    const delayMs = 100;

    while (attempts < maxAttempts) {
      if (!ref.mounted) {
        throw AutomationError(
          errorCode: AutomationErrorCode.webViewNotReady,
          location: '_waitForWebViewToBeCreated',
          message: 'Provider disposed while waiting for WebView',
          diagnostics: _getBridgeDiagnostics(),
        );
      }

      final controller = _controller;
      if (controller != null) {
        return;
      }

      await Future.delayed(const Duration(milliseconds: delayMs));
      attempts++;
    }

    throw AutomationError(
      errorCode: AutomationErrorCode.webViewNotReady,
      location: '_waitForWebViewToBeCreated',
      message:
          'WebView controller not created within timeout. This usually means the WebView widget is not visible in the widget tree yet.',
      diagnostics: _getBridgeDiagnostics(),
    );
  }

  Future<void> _waitForBridgeToBeReady() async {
    try {
      await ref.read(bridgeReadyProvider).future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException(
              "Bridge readiness signal not received within 20s.");
        },
      );
    } catch (e) {
      if (!ref.mounted) {
        throw AutomationError(
          errorCode: AutomationErrorCode.bridgeNotInitialized,
          location: '_waitForBridgeToBeReady',
          message: 'Provider disposed while waiting for bridge',
          diagnostics: _getBridgeDiagnostics(),
        );
      }
      ref.read(bridgeDiagnosticsStateProvider.notifier).recordError(
            AutomationErrorCode.bridgeTimeout.name,
            '_waitForBridgeToBeReady',
          );
      throw AutomationError(
        errorCode: AutomationErrorCode.bridgeTimeout,
        location: '_waitForBridgeToBeReady',
        message: 'Bridge readiness timeout.',
        diagnostics: _getBridgeDiagnostics(),
        originalError: e,
      );
    }
  }

  @override
  Future<void> startAutomation(String prompt) async {
    try {
      await _waitForWebViewToBeCreated();

      final controller = _controller;
      if (controller == null) {
        throw AutomationError(
          errorCode: AutomationErrorCode.webViewNotReady,
          location: 'startAutomation',
          message: 'WebView controller is null',
          diagnostics: _getBridgeDiagnostics(),
        );
      }

      dynamic isPageLoaded;
      try {
        isPageLoaded = await controller.evaluateJavascript(
            source: "document.readyState === 'complete'");
      } catch (e, stackTrace) {
        throw AutomationError(
          errorCode: AutomationErrorCode.webViewNotReady,
          location: 'startAutomation',
          message: 'Failed to check page load state',
          diagnostics: {
            ..._getBridgeDiagnostics(),
            'javascriptEvaluationError': e.toString(),
          },
          originalError: e,
          stackTrace: stackTrace,
        );
      }

      if (isPageLoaded != true) {
        throw AutomationError(
          errorCode: AutomationErrorCode.pageNotLoaded,
          location: 'startAutomation',
          message: 'WebView page not fully loaded',
          diagnostics: {
            ..._getBridgeDiagnostics(),
            'documentReadyState': isPageLoaded.toString(),
          },
        );
      }

      dynamic checkResult;
      try {
        checkResult = await controller.evaluateJavascript(
            source:
                "typeof startAutomation !== 'undefined' && typeof extractFinalResponse !== 'undefined'");
      } catch (e, stackTrace) {
        throw AutomationError(
          errorCode: AutomationErrorCode.scriptNotInjected,
          location: 'startAutomation',
          message: 'Failed to check script availability',
          diagnostics: {
            ..._getBridgeDiagnostics(),
            'javascriptEvaluationError': e.toString(),
          },
          originalError: e,
          stackTrace: stackTrace,
        );
      }

      if (checkResult != true) {
        throw AutomationError(
          errorCode: AutomationErrorCode.scriptNotInjected,
          location: 'startAutomation',
          message: 'Automation functions not available in WebView',
          diagnostics: {
            ..._getBridgeDiagnostics(),
            'functionCheckResult': checkResult.toString(),
          },
        );
      }

      final encodedPrompt = jsonEncode(prompt);
      try {
        await controller.evaluateJavascript(
            source: "startAutomation($encodedPrompt);");
      } catch (e, stackTrace) {
        throw AutomationError(
          errorCode: AutomationErrorCode.automationExecutionFailed,
          location: 'startAutomation',
          message: 'Failed to execute automation script',
          diagnostics: {
            ..._getBridgeDiagnostics(),
            'promptLength': prompt.length,
            'promptPreview':
                prompt.length > 50 ? '${prompt.substring(0, 50)}...' : prompt,
          },
          originalError: e,
          stackTrace: stackTrace,
        );
      }
    } on AutomationError {
      rethrow;
    } catch (e, stackTrace) {
      throw AutomationError(
        errorCode: AutomationErrorCode.automationExecutionFailed,
        location: 'startAutomation',
        message: 'Unexpected error during automation',
        diagnostics: _getBridgeDiagnostics(),
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<String> extractFinalResponse() async {
    try {
      await _waitForBridgeToBeReady();

      final controller = _controller;
      if (controller == null) {
        throw AutomationError(
          errorCode: AutomationErrorCode.webViewNotReady,
          location: 'extractFinalResponse',
          message: 'WebView controller is null',
          diagnostics: _getBridgeDiagnostics(),
        );
      }

      dynamic result;
      try {
        result = await controller.evaluateJavascript(
            source:
                "typeof extractFinalResponse !== 'undefined' ? extractFinalResponse() : null");
      } catch (e, stackTrace) {
        throw AutomationError(
          errorCode: AutomationErrorCode.responseExtractionFailed,
          location: 'extractFinalResponse',
          message: 'Failed to execute extraction script',
          diagnostics: _getBridgeDiagnostics(),
          originalError: e,
          stackTrace: stackTrace,
        );
      }

      if (result == null || result is! String) {
        throw AutomationError(
          errorCode: AutomationErrorCode.responseExtractionFailed,
          location: 'extractFinalResponse',
          message: 'No response available or extraction failed',
          diagnostics: {
            ..._getBridgeDiagnostics(),
            'resultType': result.runtimeType.toString(),
            'resultIsNull': result == null,
          },
        );
      }

      return result;
    } on AutomationError {
      rethrow;
    } catch (e, stackTrace) {
      throw AutomationError(
        errorCode: AutomationErrorCode.responseExtractionFailed,
        location: 'extractFinalResponse',
        message: 'Unexpected error during response extraction',
        diagnostics: _getBridgeDiagnostics(),
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }
}

@Riverpod(keepAlive: true)
JavaScriptBridgeInterface javaScriptBridge(Ref ref) {
  return JavaScriptBridge(ref);
}
