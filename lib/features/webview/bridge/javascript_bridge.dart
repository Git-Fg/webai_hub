import 'dart:async';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'automation_errors.dart';
import 'bridge_diagnostics_provider.dart';
import 'javascript_bridge_interface.dart';

part 'javascript_bridge.g.dart';

@Riverpod(keepAlive: true)
class WebViewController extends _$WebViewController {
  @override
  InAppWebViewController? build() => null;

  void setController(InAppWebViewController? controller) {
    state = controller;
  }
}

@Riverpod(keepAlive: true)
class BridgeReady extends _$BridgeReady {
  @override
  bool build() => false;

  void markReady() {
    state = true;
  }

  void reset() {
    state = false;
  }
}

class JavaScriptBridge implements JavaScriptBridgeInterface {
  final Ref ref;
  JavaScriptBridge(this.ref);

  InAppWebViewController get _controller {
    final controller = ref.read(webViewControllerProvider);
    if (controller == null) {
      throw StateError('WebView controller not initialized');
    }
    return controller;
  }

  Map<String, dynamic> _getBridgeDiagnostics() {
    final isReady = ref.read(bridgeReadyProvider);
    final controller = ref.read(webViewControllerProvider);
    return {
      'bridgeReady': isReady,
      'webViewControllerExists': controller != null,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _waitForWebViewToBeCreated() async {
    int attempts = 0;
    const maxAttempts = 400; // Increased for IndexedStack tab switching
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

      final controller = ref.read(webViewControllerProvider);
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

  @override
  Future<void> waitForBridgeReady() async {
    // First ensure the WebView controller exists (with extended timeout for IndexedStack)
    await _waitForWebViewToBeCreated();

    // Additional wait to ensure WebView is fully initialized
    await Future.delayed(const Duration(milliseconds: 300));

    const maxAttempts = 200;
    const delayMs = 100;
    const timeoutSeconds = 20;

    int attempts = 0;
    final startTime = DateTime.now();

    while (attempts < maxAttempts) {
      if (!ref.mounted) {
        throw AutomationError(
          errorCode: AutomationErrorCode.bridgeNotInitialized,
          location: 'waitForBridgeReady',
          message: 'Provider disposed while waiting for bridge',
          diagnostics: _getBridgeDiagnostics(),
        );
      }

      final elapsed = DateTime.now().difference(startTime);
      if (elapsed.inSeconds >= timeoutSeconds) {
        ref.read(bridgeDiagnosticsStateProvider.notifier).recordError(
              AutomationErrorCode.bridgeTimeout.name,
              'waitForBridgeReady',
            );
        throw AutomationError(
          errorCode: AutomationErrorCode.bridgeTimeout,
          location: 'waitForBridgeReady',
          message: 'Bridge readiness timeout.',
          diagnostics: _getBridgeDiagnostics(),
        );
      }

      final isReady = ref.read(bridgeReadyProvider);
      if (isReady) {
        return;
      }

      await Future.delayed(const Duration(milliseconds: delayMs));
      attempts++;
    }

    ref.read(bridgeDiagnosticsStateProvider.notifier).recordError(
          AutomationErrorCode.bridgeTimeout.name,
          'waitForBridgeReady',
        );
    throw AutomationError(
      errorCode: AutomationErrorCode.bridgeTimeout,
      location: 'waitForBridgeReady',
      message: 'Bridge readiness timeout.',
      diagnostics: _getBridgeDiagnostics(),
    );
  }

  @override
  Future<void> startAutomation(String prompt) async {
    try {
      await _waitForWebViewToBeCreated();

      final controller = _controller;

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
        // Simple check: verify window.startAutomation is available
        checkResult = await controller.evaluateJavascript(
            source:
                "typeof window.startAutomation !== 'undefined' && typeof window.extractFinalResponse !== 'undefined'");
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
        // Simple, direct call - functions are guaranteed to be on window
        await controller.evaluateJavascript(
            source: "window.startAutomation($encodedPrompt);");
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

  Future<Map<String, dynamic>> inspectDOMForSelectors() async {
    await _waitForWebViewToBeCreated();
    final controller = _controller;

    try {
      final result = await controller.evaluateJavascript(
          source:
              "typeof inspectDOMForSelectors !== 'undefined' ? inspectDOMForSelectors() : null");
      return result as Map<String, dynamic>;
    } catch (e, stackTrace) {
      throw AutomationError(
        errorCode: AutomationErrorCode.automationExecutionFailed,
        location: 'inspectDOMForSelectors',
        message: 'Failed to inspect DOM',
        diagnostics: _getBridgeDiagnostics(),
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> captureConsoleLogs() async {
    await _waitForWebViewToBeCreated();
    final controller = _controller;

    try {
      await controller.evaluateJavascript(source: '''
        (function() {
          const originalLog = console.log;
          const originalWarn = console.warn;
          const originalError = console.error;
          
          window.__capturedLogs__ = window.__capturedLogs__ || [];
          
          console.log = function(...args) {
            window.__capturedLogs__.push({type: 'log', args: args.map(a => String(a))});
            originalLog.apply(console, args);
          };
          
          console.warn = function(...args) {
            window.__capturedLogs__.push({type: 'warn', args: args.map(a => String(a))});
            originalWarn.apply(console, args);
          };
          
          console.error = function(...args) {
            window.__capturedLogs__.push({type: 'error', args: args.map(a => String(a))});
            originalError.apply(console, args);
          };
        })();
      ''');
    } catch (e) {
      // Ignore errors
    }
  }

  Future<List<Map<String, dynamic>>> getCapturedLogs() async {
    await _waitForWebViewToBeCreated();
    final controller = _controller;

    try {
      final logs = await controller.evaluateJavascript(
          source: "window.__capturedLogs__ || []");
      await controller.evaluateJavascript(
          source: "window.__capturedLogs__ = []");
      return List<Map<String, dynamic>>.from(logs as List);
    } catch (e) {
      return [];
    }
  }

  @override
  Future<String> extractFinalResponse() async {
    try {
      await waitForBridgeReady();

      final controller = _controller;

      dynamic result;
      try {
        // extractFinalResponse est async, utiliser une variable globale pour contourner
        // le problème de sérialisation des Promises par evaluateJavascript
        // Étape 1: Exécuter l'extraction et stocker le résultat
        await controller.evaluateJavascript(source: '''
              (async () => {
                if (typeof extractFinalResponse !== 'undefined') {
                  window.__lastExtractedResponse__ = await extractFinalResponse();
                } else {
                  window.__lastExtractedResponse__ = null;
                }
              })()
            ''');

        // Étape 2: Attendre un peu pour que la Promise soit résolue
        await Future.delayed(const Duration(milliseconds: 100));

        // Étape 3: Récupérer le résultat stocké
        result = await controller.evaluateJavascript(
            source: "window.__lastExtractedResponse__ || null");
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
