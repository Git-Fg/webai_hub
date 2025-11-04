import 'dart:async';
import 'dart:convert';

import 'package:ai_hybrid_hub/features/webview/bridge/automation_errors.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/bridge_diagnostics_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'javascript_bridge.g.dart';

@Riverpod(keepAlive: true)
class WebViewController extends _$WebViewController {
  @override
  InAppWebViewController? build() {
    // Nettoyage automatique lors du disposal du provider
    ref.onDispose(() {
      final controller = state;
      if (controller != null) {
        debugPrint('[WebViewController] Disposing controller.');
        // Nettoyer les fonctions globales pour éviter les fuites de mémoire JS
        controller.evaluateJavascript(
          source: '''
          delete window.startAutomation;
          delete window.extractFinalResponse;
          delete window.inspectDOMForSelectors;
          delete window.__AI_HYBRID_HUB_INITIALIZED__;
        ''',
        ).catchError((Object error) {
          // Ignorer les erreurs si le contrôleur est déjà détruit
          debugPrint('[WebViewController] Error during disposal: $error');
        });
      }
    });
    return null;
  }

  // ignore: use_setters_to_change_properties, reason: Clear intent; method aligns with Riverpod notifier APIs
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

@riverpod
class CurrentWebViewUrl extends _$CurrentWebViewUrl {
  @override
  String build() => '';

  void updateUrl(String url) {
    state = url;
  }
}

class JavaScriptBridge implements JavaScriptBridgeInterface {
  JavaScriptBridge(this.ref);
  final Ref ref;

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
    var attempts = 0;
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

      await Future<void>.delayed(const Duration(milliseconds: delayMs));
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
    await Future<void>.delayed(const Duration(milliseconds: 300));

    const maxAttempts = 200;
    const delayMs = 100;
    const timeoutSeconds = 20;

    var attempts = 0;
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

      await Future<void>.delayed(const Duration(milliseconds: delayMs));
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
          source: "document.readyState === 'complete'",
        );
      } on Object catch (e, stackTrace) {
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
              "typeof window.startAutomation !== 'undefined' && typeof window.extractFinalResponse !== 'undefined'",
        );
      } on Object catch (e, stackTrace) {
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
          source: 'window.startAutomation($encodedPrompt);',
        );
      } on Object catch (e, stackTrace) {
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
      // ignore: avoid_catching_errors, reason: Preserve original AutomationError semantics without wrapping
    } on AutomationError {
      rethrow;
    } on Object catch (e, stackTrace) {
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
            "typeof inspectDOMForSelectors !== 'undefined' ? inspectDOMForSelectors() : null",
      );
      return result as Map<String, dynamic>;
    } on Object catch (e, stackTrace) {
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
      await controller.evaluateJavascript(
        source: '''
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
      ''',
      );
    } on Object catch (_) {
      // Ignore errors
    }
  }

  Future<List<Map<String, dynamic>>> getCapturedLogs() async {
    await _waitForWebViewToBeCreated();
    final controller = _controller;

    try {
      final logs = await controller.evaluateJavascript(
        source: 'window.__capturedLogs__ || []',
      );
      await controller.evaluateJavascript(
        source: 'window.__capturedLogs__ = []',
      );
      return List<Map<String, dynamic>>.from(logs as List);
    } on Object catch (_) {
      return [];
    }
  }

  @override
  Future<String> extractFinalResponse() async {
    try {
      // S'assurer que le bridge est prêt avant de continuer.
      await waitForBridgeReady();

      final controller = _controller;

      // Utiliser callAsyncJavaScript qui gère nativement les Promises.
      // C'est plus simple et élimine la race condition.
      final result = await controller.callAsyncJavaScript(
        functionBody: '''
          // La fonction passée ici est "await" par le WebView.
          // On retourne directement le résultat de notre fonction asynchrone.
          return await window.extractFinalResponse();
        ''',
      );

      // callAsyncJavaScript peut retourner un objet InAppWebViewJavaScriptResult.
      // On vérifie que la valeur n'est pas nulle.
      final value = result?.value;

      if (value == null || value is! String) {
        throw AutomationError(
          errorCode: AutomationErrorCode.responseExtractionFailed,
          location: 'extractFinalResponse',
          message: 'Extraction returned null or an invalid type.',
          diagnostics: {
            ..._getBridgeDiagnostics(),
            'resultType': value.runtimeType.toString(),
            'resultValue': value?.toString(),
          },
        );
      }
      return value;
    } on Object catch (e, stackTrace) {
      // On englobe tout dans un try/catch pour convertir les erreurs
      // en AutomationError si nécessaire.
      if (e is AutomationError) rethrow;

      throw AutomationError(
        errorCode: AutomationErrorCode.responseExtractionFailed,
        location: 'extractFinalResponse',
        message: 'Unexpected error during response extraction.',
        diagnostics: _getBridgeDiagnostics(),
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> startResponseObserver() async {
    try {
      await _waitForWebViewToBeCreated();
      final controller = _controller;
      await controller.evaluateJavascript(
        source: 'window.startResponseObserver();',
      );
    } on Object catch (e, stackTrace) {
      throw AutomationError(
        errorCode: AutomationErrorCode.automationExecutionFailed,
        location: 'startResponseObserver',
        message: 'Failed to start response observer script',
        diagnostics: _getBridgeDiagnostics(),
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  // SUPPRIMÉ : waitForResponseCompletion n'est plus nécessaire
}

@Riverpod(keepAlive: true)
JavaScriptBridgeInterface javaScriptBridge(Ref ref) {
  return JavaScriptBridge(ref);
}
