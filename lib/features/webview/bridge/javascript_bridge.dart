import 'dart:async';
import 'dart:convert';

import 'package:ai_hybrid_hub/core/providers/talker_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/automation_errors.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/bridge_diagnostics_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge_interface.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'javascript_bridge.g.dart';

const int _webViewCreationMaxAttempts = 400;
const Duration _webViewCreationCheckDelay = Duration(milliseconds: 100);
const int _bridgeReadyMaxAttempts = 200;
const Duration _bridgeReadyCheckDelay = Duration(milliseconds: 100);
const int _bridgeReadyTimeoutSeconds = 20;
const Duration _callAsyncJavaScriptTimeout = Duration(seconds: 30);
const Duration _heartbeatTimeout = Duration(seconds: 2);

@Riverpod(keepAlive: true)
class WebViewController extends _$WebViewController {
  @override
  InAppWebViewController? build() {
    // WORKAROUND: Clean up global functions to prevent JS memory leaks
    ref.onDispose(() {
      final controller = state;
      if (controller != null) {
        final talker = ref.read(talkerProvider);
        talker.debug('[WebViewController] Disposing controller.');
        // WHY: Global functions must be deleted to prevent memory leaks when WebView is disposed
        unawaited(
          controller
              .evaluateJavascript(
                source: '''
            delete window.startAutomation;
            delete window.extractFinalResponse;
            delete window.inspectDOMForSelectors;
            delete window.__AI_HYBRID_HUB_INITIALIZED__;
          ''',
              )
              .catchError((Object error) {
                // WHY: Controller may already be destroyed, errors are non-critical here
                final talker = ref.read(talkerProvider);
                talker.warning(
                  '[WebViewController] Error during disposal: $error',
                );
              }),
        );
      }
    });
    return null;
  }

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

  /// WHY: Heartbeat check with timeout is the only reliable way to detect dead contexts.
  /// A simple evaluateJavascript call will hang indefinitely on a crashed ("zombie") context.
  /// A TimeoutException is the canonical signal of a dead context, not an error condition.
  /// This method returns true if the JS context is responsive, false if dead (timeout).
  /// It does NOT check for bridge initialization - use _isBridgeInjected() for that.
  @override
  Future<bool> isBridgeAlive() async {
    try {
      final controller = _controller;
      // WHY: Simple probe that only checks JS context responsiveness
      // Wrap in timeout to detect hung contexts
      await controller
          .evaluateJavascript(source: 'true')
          .timeout(_heartbeatTimeout);
      return true;
    } on TimeoutException {
      // WHY: TimeoutException is the canonical signal of a dead context
      final talker = ref.read(talkerProvider);
      talker.debug(
        '[JavaScriptBridge] Heartbeat timeout - bridge context is dead',
      );
      return false;
    } on Object catch (e) {
      // WHY: Other errors (e.g., controller disposed) also indicate dead context
      final talker = ref.read(talkerProvider);
      talker.warning('[JavaScriptBridge] Heartbeat check failed: $e');
      return false;
    }
  }

  Future<void> _waitForWebViewToBeCreated() async {
    var attempts = 0;

    while (attempts < _webViewCreationMaxAttempts) {
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

      await Future<void>.delayed(_webViewCreationCheckDelay);
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

  /// WHY: Specifically checks if the bridge script has been injected and initialized.
  /// This is separate from isBridgeAlive() which only checks JS context responsiveness.
  Future<bool> _isBridgeInjected() async {
    try {
      final result = await _controller
          .evaluateJavascript(
            source: 'window.__AI_HYBRID_HUB_INITIALIZED__ === true',
          )
          .timeout(_heartbeatTimeout);
      return result == true;
    } on Object catch (_) {
      return false;
    }
  }

  @override
  Future<void> loadUrlAndWaitForReady(URLRequest urlRequest) async {
    // First, ensure the controller itself exists.
    await _waitForWebViewToBeCreated();

    final controller = _controller;

    // WHY: Before starting a new page load, we must reset the readiness state.
    // The bridge will be "not ready" until the new page finishes loading
    // and the script is re-injected.
    ref.read(bridgeReadyProvider.notifier).reset();

    // Start the page load. This returns quickly and does not wait for the page to finish.
    await controller.loadUrl(urlRequest: urlRequest);

    // WHY: Now, we can use our existing, robust polling mechanism to wait for the
    // entire cycle to complete: page load -> onLoadStop -> script injection -> JS ready signal.
    // This is the most reliable way to ensure the bridge is truly ready.
    await waitForBridgeReady();
  }

  @override
  Future<void> waitForBridgeReady() async {
    final startTime = DateTime.now();

    // Stage 1: Wait for the native controller to exist.
    await _waitForWebViewToBeCreated();

    // Stage 2: Wait for the web page to finish loading.
    // WHY: This is the CRITICAL missing step that fixes the race condition.
    // We cannot expect JavaScript to be ready before the page itself has finished loading.
    var attempts = 0;
    while (attempts < _bridgeReadyMaxAttempts) {
      if (!ref.mounted) {
        throw AutomationError(
          errorCode: AutomationErrorCode.bridgeNotInitialized,
          location: 'waitForBridgeReady',
          message: 'Provider disposed while waiting for bridge',
          diagnostics: _getBridgeDiagnostics(),
        );
      }

      final elapsed = DateTime.now().difference(startTime);
      if (elapsed.inSeconds >= _bridgeReadyTimeoutSeconds) {
        ref
            .read(bridgeDiagnosticsStateProvider.notifier)
            .recordError(
              AutomationErrorCode.pageNotLoaded.name,
              'waitForBridgeReady',
            );
        throw AutomationError(
          errorCode: AutomationErrorCode.pageNotLoaded,
          location: 'waitForBridgeReady',
          message: 'Page did not load within timeout.',
          diagnostics: _getBridgeDiagnostics(),
        );
      }

      try {
        final readyState = await _controller.evaluateJavascript(
          source: 'document.readyState',
        );
        if (readyState == 'complete') break;
      } on Object catch (_) {
        // Ignore errors during page load check, continue polling
      }

      await Future<void>.delayed(_bridgeReadyCheckDelay);
      attempts++;
    }

    // Stage 3: Wait for our script to be injected and initialized.
    attempts = 0;
    while (attempts < _bridgeReadyMaxAttempts) {
      if (!ref.mounted) {
        throw AutomationError(
          errorCode: AutomationErrorCode.bridgeNotInitialized,
          location: 'waitForBridgeReady',
          message: 'Provider disposed while waiting for bridge',
          diagnostics: _getBridgeDiagnostics(),
        );
      }

      final elapsed = DateTime.now().difference(startTime);
      if (elapsed.inSeconds >= _bridgeReadyTimeoutSeconds) {
        ref
            .read(bridgeDiagnosticsStateProvider.notifier)
            .recordError(
              AutomationErrorCode.scriptNotInjected.name,
              'waitForBridgeReady',
            );
        throw AutomationError(
          errorCode: AutomationErrorCode.scriptNotInjected,
          location: 'waitForBridgeReady',
          message: 'Bridge script not injected within timeout.',
          diagnostics: _getBridgeDiagnostics(),
        );
      }

      if (await _isBridgeInjected()) break;

      await Future<void>.delayed(_bridgeReadyCheckDelay);
      attempts++;
    }

    // Stage 4: Wait for the final 'ready' signal from the JS side.
    attempts = 0;
    while (attempts < _bridgeReadyMaxAttempts) {
      if (!ref.mounted) {
        throw AutomationError(
          errorCode: AutomationErrorCode.bridgeNotInitialized,
          location: 'waitForBridgeReady',
          message: 'Provider disposed while waiting for bridge',
          diagnostics: _getBridgeDiagnostics(),
        );
      }

      final elapsed = DateTime.now().difference(startTime);
      if (elapsed.inSeconds >= _bridgeReadyTimeoutSeconds) {
        ref
            .read(bridgeDiagnosticsStateProvider.notifier)
            .recordError(
              AutomationErrorCode.bridgeTimeout.name,
              'waitForBridgeReady',
            );
        throw AutomationError(
          errorCode: AutomationErrorCode.bridgeTimeout,
          location: 'waitForBridgeReady',
          message: 'Bridge did not signal ready within timeout.',
          diagnostics: _getBridgeDiagnostics(),
        );
      }

      final isReady = ref.read(bridgeReadyProvider);
      if (isReady) return; // Success

      await Future<void>.delayed(_bridgeReadyCheckDelay);
      attempts++;
    }

    ref
        .read(bridgeDiagnosticsStateProvider.notifier)
        .recordError(
          AutomationErrorCode.bridgeTimeout.name,
          'waitForBridgeReady',
        );
    throw AutomationError(
      errorCode: AutomationErrorCode.bridgeTimeout,
      location: 'waitForBridgeReady',
      message: 'Bridge did not signal ready within timeout.',
      diagnostics: _getBridgeDiagnostics(),
    );
  }

  @override
  Future<void> startAutomation(Map<String, dynamic> options) async {
    try {
      await _waitForWebViewToBeCreated();

      // WHY: Check heartbeat before critical operations to detect dead contexts early
      final isAlive = await isBridgeAlive();
      if (!isAlive) {
        throw AutomationError(
          errorCode: AutomationErrorCode.bridgeTimeout,
          location: 'startAutomation',
          message:
              'Bridge context is dead (heartbeat failed). Cannot start automation.',
          diagnostics: _getBridgeDiagnostics(),
        );
      }

      final controller = _controller;

      dynamic isPageLoaded;
      try {
        isPageLoaded = await controller.evaluateJavascript(
          source:
              "document.readyState === 'interactive' || document.readyState === 'complete'",
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
          message:
              'WebView page not ready for DOM interaction (must be interactive or complete)',
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

      // Pass the options map directly. It will be automatically JSON encoded.
      final encodedOptions = jsonEncode(options);
      try {
        await controller.evaluateJavascript(
          source: 'window.startAutomation($encodedOptions);',
        );
      } on Object catch (e, stackTrace) {
        throw AutomationError(
          errorCode: AutomationErrorCode.automationExecutionFailed,
          location: 'startAutomation',
          message: 'Failed to execute automation script',
          diagnostics: {
            ..._getBridgeDiagnostics(),
            'options': options,
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
    final talker = ref.read(talkerProvider);
    talker.debug('[JavaScriptBridge] extractFinalResponse called');
    try {
      // WHY: Ensure bridge is ready before extraction to avoid race conditions
      talker.debug('[JavaScriptBridge] Waiting for bridge ready...');
      await waitForBridgeReady();
      talker.debug(
        '[JavaScriptBridge] Bridge ready, proceeding with extraction',
      );

      // WHY: Final heartbeat check before extraction to ensure context is still alive
      final isAlive = await isBridgeAlive();
      if (!isAlive) {
        throw AutomationError(
          errorCode: AutomationErrorCode.bridgeTimeout,
          location: 'extractFinalResponse',
          message: 'Bridge context died during extraction (heartbeat failed).',
          diagnostics: _getBridgeDiagnostics(),
        );
      }

      final controller = _controller;

      // WHY: callAsyncJavaScript natively handles Promises, eliminating race conditions
      // WHY: Wrap with timeout to prevent silent hangs/deadlocks documented in flutter_inappwebview
      // Research shows callAsyncJavaScript can hang indefinitely on Android, causing app crashes
      talker.debug(
        '[JavaScriptBridge] Calling extractFinalResponse in WebView...',
      );
      final result = await controller
          .callAsyncJavaScript(
            functionBody: '''
          // The function passed here is awaited by the WebView.
          // We return the result of our async function directly.
          return await window.extractFinalResponse();
        ''',
          )
          .timeout(
            _callAsyncJavaScriptTimeout,
            onTimeout: () {
              throw AutomationError(
                errorCode: AutomationErrorCode.bridgeTimeout,
                location: 'extractFinalResponse',
                message:
                    'Bridge call timed out after ${_callAsyncJavaScriptTimeout.inSeconds} seconds',
                diagnostics: _getBridgeDiagnostics(),
              );
            },
          );
      talker.debug(
        '[JavaScriptBridge] Extraction call completed, result: ${result?.value != null ? "success (${(result?.value as String?)?.length ?? 0} chars)" : "null"}',
      );

      // callAsyncJavaScript can return an InAppWebViewJavaScriptResult object.
      // We verify the value is not null.
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
      // WHY: Wrap all errors in try/catch to convert them to AutomationError if needed
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
}

@Riverpod(keepAlive: true)
JavaScriptBridgeInterface javaScriptBridge(Ref ref) {
  return JavaScriptBridge(ref);
}
