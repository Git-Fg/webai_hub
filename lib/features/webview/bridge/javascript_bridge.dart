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
const Duration _callAsyncJavaScriptTimeout = Duration(seconds: 30);
const Duration _heartbeatTimeout = Duration(seconds: 2);

@Riverpod(keepAlive: true)
class WebViewController extends _$WebViewController {
  @override
  InAppWebViewController? build(int presetId) {
    // WORKAROUND: Clean up global functions to prevent JS memory leaks
    ref.onDispose(() {
      final controller = state;
      if (controller != null) {
        final talker = ref.read(talkerProvider);
        talker.debug(
          '[WebViewController] Disposing controller for preset: $presetId',
        );
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
                  '[WebViewController] Error during disposal for preset $presetId: $error',
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
  JavaScriptBridge(this.ref, this.presetId);
  final Ref ref;
  final int presetId;

  /// WHY: Get the controller for the preset. The preset ID is used to get the correct WebView instance.
  InAppWebViewController get _controller {
    final controller = ref.read(webViewControllerProvider(presetId));
    if (controller == null) {
      throw StateError(
        'WebView controller not initialized for preset: $presetId',
      );
    }
    return controller;
  }

  Map<String, dynamic> _getBridgeDiagnostics() {
    final isReady = ref.read(bridgeReadyProvider);
    final controller = ref.read(webViewControllerProvider(presetId));
    return {
      'bridgeReady': isReady,
      'webViewControllerExists': controller != null,
      'presetId': presetId,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// WHY: Heartbeat check with timeout is the only reliable way to detect dead contexts.
  /// A simple evaluateJavascript call will hang indefinitely on a crashed ("zombie") context.
  /// A TimeoutException is the canonical signal of a dead context, not an error condition.
  /// This method returns true if the JS context is responsive, false if dead (timeout).
  /// It does NOT check for bridge initialization.
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

      final controller = ref.read(webViewControllerProvider(presetId));
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
          'WebView controller not created within timeout for preset: $presetId. This usually means the WebView widget is not visible in the widget tree yet.',
      diagnostics: _getBridgeDiagnostics(),
    );
  }

  @override
  Future<void> waitForBridgeReady() async {
    final talker = ref.read(talkerProvider);
    talker.debug('[Bridge] Waiting for WebView controller...');

    // Stage 1: Wait for the native controller to exist.
    await _waitForWebViewToBeCreated();

    talker.debug(
      '[Bridge] WebView controller found. Waiting for ready signal...',
    );

    try {
      // If already ready, return immediately.
      if (ref.read(bridgeReadyProvider)) {
        talker.debug('[Bridge] Bridge was already ready.');
        return;
      }

      // Otherwise, wait for the provider to become true using polling.
      const checkInterval = Duration(milliseconds: 50);
      final startTime = DateTime.now();

      while (true) {
        if (!ref.mounted) {
          throw AutomationError(
            errorCode: AutomationErrorCode.webViewNotReady,
            location: 'waitForBridgeReady',
            message: 'Provider disposed while waiting for bridge ready',
            diagnostics: _getBridgeDiagnostics(),
          );
        }

        if (ref.read(bridgeReadyProvider)) {
          talker.debug('[Bridge] Ready signal received.');
          return;
        }

        final elapsed = DateTime.now().difference(startTime);
        if (elapsed >= _callAsyncJavaScriptTimeout) {
          throw TimeoutException(
            'Bridge did not signal ready within the timeout period.',
            _callAsyncJavaScriptTimeout,
          );
        }

        await Future<void>.delayed(checkInterval);
      }
    } on TimeoutException {
      ref
          .read(bridgeDiagnosticsStateProvider.notifier)
          .recordError(
            AutomationErrorCode.bridgeTimeout.name,
            'waitForBridgeReady',
          );
      throw AutomationError(
        errorCode: AutomationErrorCode.bridgeTimeout,
        location: 'waitForBridgeReady',
        message: 'Bridge did not signal ready within the timeout period.',
        diagnostics: _getBridgeDiagnostics(),
      );
    }
  }

  @override
  Future<void> startAutomation(
    String providerId,
    String prompt,
    String settingsJson,
    double timeoutModifier,
  ) async {
    try {
      await _waitForWebViewToBeCreated();

      // WHY: Check heartbeat before critical operations to detect dead contexts early
      final isAlive = await isBridgeAlive();
      if (!isAlive) {
        throw AutomationError(
          errorCode: AutomationErrorCode.bridgeTimeout,
          location: 'startAutomation',
          message: 'Bridge context is not responsive',
          diagnostics: _getBridgeDiagnostics(),
        );
      }

      // WHY: Ensure bridge is ready before starting automation
      if (!ref.read(bridgeReadyProvider)) {
        throw AutomationError(
          errorCode: AutomationErrorCode.bridgeNotInitialized,
          location: 'startAutomation',
          message: 'Bridge is not ready for automation',
          diagnostics: _getBridgeDiagnostics(),
        );
      }

      final talker = ref.read(talkerProvider);
      talker.info('[Bridge] Starting automation for preset: $presetId');

      // WHY: Encode arguments as JSON strings to safely pass as function arguments
      // settingsJson is already a JSON string, but we need to encode it again so it becomes
      // a JavaScript string literal (with quotes) in the function body
      final encodedProviderId = jsonEncode(providerId);
      final encodedPrompt = jsonEncode(prompt);
      // WHY: Double-encode settingsJson so it becomes a JavaScript string literal
      // Example: '{"model":"gpt-4"}' becomes '"{\\"model\\":\\"gpt-4\\"}"' in JavaScript
      final encodedSettingsJson = jsonEncode(settingsJson);

      final controller = _controller;

      // WHY: callAsyncJavaScript natively handles Promises, eliminating race conditions
      // WHY: Wrap with timeout to prevent silent hangs/deadlocks documented in flutter_inappwebview
      // Research shows callAsyncJavaScript can hang indefinitely on Android, causing app crashes
      talker.debug(
        '[JavaScriptBridge] Calling startAutomation in WebView...',
      );
      await controller
          .callAsyncJavaScript(
            functionBody:
                '''
          // The function passed here is awaited by the WebView.
          // We return the result of our async function directly.
          return await window.startAutomation($encodedProviderId, $encodedPrompt, $encodedSettingsJson, $timeoutModifier);
        ''',
          )
          .timeout(
            _callAsyncJavaScriptTimeout,
            onTimeout: () {
              throw AutomationError(
                errorCode: AutomationErrorCode.bridgeTimeout,
                location: 'startAutomation',
                message:
                    'Bridge call timed out after ${_callAsyncJavaScriptTimeout.inSeconds} seconds',
                diagnostics: _getBridgeDiagnostics(),
              );
            },
          );
      talker.info('[Bridge] Automation started successfully');
    } on Object catch (e, stackTrace) {
      // WHY: Wrap all errors in try/catch to convert them to AutomationError if needed
      if (e is AutomationError) rethrow;

      final talker = ref.read(talkerProvider);
      talker.error('[Bridge] Error starting automation', e, stackTrace);
      throw AutomationError(
        errorCode: AutomationErrorCode.automationExecutionFailed,
        location: 'startAutomation',
        message: 'Failed to execute automation script',
        diagnostics: {
          ..._getBridgeDiagnostics(),
          'providerId': providerId,
        },
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

  @override
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
}

@Riverpod(keepAlive: true)
JavaScriptBridgeInterface javaScriptBridge(Ref ref, int presetId) {
  return JavaScriptBridge(ref, presetId);
}
