import 'dart:async';
import 'dart:convert';

import 'package:ai_hybrid_hub/core/providers/talker_provider.dart';
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';
import 'package:ai_hybrid_hub/features/settings/providers/general_settings_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/bridge_constants.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/bridge_diagnostics_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/bridge_event.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:ai_hybrid_hub/features/webview/providers/webview_key_provider.dart';
import 'package:ai_hybrid_hub/features/webview/webview_constants.dart';
import 'package:ai_hybrid_hub/providers/bridge_script_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiWebviewScreen extends ConsumerStatefulWidget {
  const AiWebviewScreen({super.key});

  @override
  ConsumerState<AiWebviewScreen> createState() => _AiWebviewScreenState();
}

class _AiWebviewScreenState extends ConsumerState<AiWebviewScreen>
    with WidgetsBindingObserver {
  InAppWebViewController? webViewController;
  double _progress = 0;
  String? _currentBridgeScript;

  @override
  void initState() {
    super.initState();
    // WHY: Register lifecycle observer to detect app resume and check bridge health
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // WHY: Unregister lifecycle observer to prevent memory leaks
    WidgetsBinding.instance.removeObserver(this);
    // Remove JavaScript handlers to prevent memory leaks
    webViewController?.removeJavaScriptHandler(
      handlerName: BridgeConstants.automationHandler,
    );
    webViewController?.removeJavaScriptHandler(
      handlerName: BridgeConstants.readyHandler,
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // WHY: On app resume, check bridge health and recover if needed
    // iOS WebViews often become "zombie" contexts after backgrounding
    if (state == AppLifecycleState.resumed) {
      // WHY: Fire-and-forget: recovery happens asynchronously, no need to await
      unawaited(_checkBridgeHealthOnResume());
    }
  }

  /// Checks bridge health after app resume and triggers recovery if needed
  Future<void> _checkBridgeHealthOnResume() async {
    final controller = webViewController;
    if (controller == null) return;

    try {
      final bridge = ref.read(javaScriptBridgeProvider);
      if (bridge is JavaScriptBridge) {
        final isAlive = await bridge.isBridgeAlive();
        if (!isAlive) {
          final talker = ref.read(talkerProvider);
          talker.warning(
            '[AiWebviewScreen] Bridge dead after resume, triggering recovery...',
          );
          await _recoverFromDeadBridge(controller);
        }
      }
    } on Object catch (e) {
      final talker = ref.read(talkerProvider);
      talker.warning(
        '[AiWebviewScreen] Error checking bridge health on resume: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bridgeScriptAsync = ref.watch(bridgeScriptProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        final controller = webViewController;
        if (controller != null && await controller.canGoBack()) {
          await controller.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Google AI Studio',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.green.shade600,
          elevation: 0,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () async {
                if (webViewController == null) return;
                final talker = ref.read(talkerProvider);
                try {
                  talker.info('[DOM INSPECT] Requesting DOM analysis...');
                  final result = await webViewController!.evaluateJavascript(
                    source: 'inspectDOMForSelectors();',
                  );
                  if (result != null) {
                    const encoder = JsonEncoder.withIndent('  ');
                    final prettyJson = encoder.convert(result);
                    talker.info('[DOM INSPECT] Result:\n$prettyJson');
                  } else {
                    talker.info(
                      '[DOM INSPECT] inspectDOMForSelectors returned null.',
                    );
                  }
                } on Object catch (e) {
                  talker.error('[DOM INSPECT] Error: $e');
                }
              },
              tooltip: 'Inspect DOM for Selectors',
            ),
          ],
          bottom: _progress < 1.0
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(4),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.green.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                )
              : null,
        ),
        body: bridgeScriptAsync.when(
          data: _buildWebView,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Text('Error loading bridge script: $err'),
          ),
        ),
      ),
    );
  }

  Widget _buildWebView(String bridgeScript) {
    // WHY: Store bridge script for use in recovery methods
    _currentBridgeScript = bridgeScript;
    final webViewKey = ref.watch(webViewKeyProvider);

    return InAppWebView(
      key: ValueKey('ai_webview_$webViewKey'),
      initialUrlRequest: URLRequest(url: WebUri(WebViewConstants.aiStudioUrl)),
      initialSettings: InAppWebViewSettings(
        // WHY: Setting a standard desktop User-Agent is crucial for compatibility.
        // Many modern web apps, especially login pages, block or fail to render
        // for unknown or default WebView user agents.
        userAgent:
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
        applicationNameForUserAgent: 'AIHybridHub',
        supportZoom: false,
        mediaPlaybackRequiresUserGesture: false,
        useShouldOverrideUrlLoading: true,
        // WHY: Explicitly enable JavaScript (required for bridge) but restrict dangerous APIs
        javaScriptEnabled: true,
        // WHY: Security hardening - restrict file access to prevent XSS attacks
        // These settings prevent file:// URLs from accessing other origins
        allowUniversalAccessFromFileURLs: false,
        allowFileAccessFromFileURLs: false,
        // WHY: Disable database APIs if not needed to reduce attack surface
        databaseEnabled: false,
        // WHY: Enable DOM storage for modern web apps (required for AI Studio)
        domStorageEnabled: true,
        // WHY: Disable third-party cookies for privacy and security
        thirdPartyCookiesEnabled: false,
        // WHY: Clear cache on navigation to prevent stale data issues
        clearCache: false,
      ),
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final talker = ref.read(talkerProvider);
        final uri = navigationAction.request.url;
        talker.info('[WebView] Navigation request to: $uri');
        return NavigationActionPolicy.ALLOW;
      },
      onWebViewCreated: (controller) {
        webViewController = controller;
        ref.read(webViewControllerProvider.notifier).setController(controller);
        ref
            .read(bridgeDiagnosticsStateProvider.notifier)
            .recordWebViewCreated();

        controller.addJavaScriptHandler(
          handlerName: BridgeConstants.automationHandler,
          callback: (args) {
            if (args.isEmpty || args[0] is! Map) return;
            try {
              final json = Map<String, dynamic>.from(args[0] as Map);
              final event = BridgeEvent.fromJson(json);
              final notifier = ref.read(conversationActionsProvider.notifier);
              final automationNotifier = ref.read(
                automationStateProvider.notifier,
              );

              switch (event.type) {
                case BridgeConstants.eventTypeNewResponse:
                  // WHY: First, ALWAYS transition to the 'refining' state.
                  // This ensures the application is in a stable, consistent state
                  // that matches the manual workflow before any further action is taken.
                  final conversationAsync = ref.read(conversationProvider);
                  final messageCount = conversationAsync.maybeWhen(
                    data: (conversation) => conversation.length,
                    orElse: () => 0,
                  );
                  automationNotifier.moveToRefining(
                    messageCount: messageCount,
                  );

                  // Now, check if YOLO mode should proceed automatically.
                  final yoloModeEnabled =
                      ref
                          .read(generalSettingsProvider)
                          .value
                          ?.yoloModeEnabled ??
                      true;

                  if (yoloModeEnabled) {
                    // The state is now correctly 'refining', so we can safely
                    // trigger the automatic extraction.
                    unawaited(notifier.extractAndReturnToHub());
                  }
                  // If YOLO is off, the app simply remains in the 'refining' state, waiting for the user.
                  return;
                case BridgeConstants.eventTypeLoginRequired:
                  // Read the prompt from the automation state notifier
                  // This works even if state has transitioned from sending to observing
                  final automationState = ref.read(
                    automationStateProvider.notifier,
                  );
                  final pendingPrompt = automationState.currentPrompt;
                  if (pendingPrompt != null) {
                    // Pass the entire resumption logic as a callback.
                    automationNotifier.moveToNeedsLogin(
                      onResume: () async {
                        await ref
                            .read(conversationActionsProvider.notifier)
                            .sendPromptToAutomation(pendingPrompt);
                      },
                    );
                  } else {
                    // If no pending prompt, still transition to needsLogin but without callback
                    automationNotifier.moveToNeedsLogin();
                  }
                  return;
                case BridgeConstants.eventTypeAutomationFailed:
                  final payload = event.payload ?? 'Unknown error';
                  final errorCode = event.errorCode;
                  final location = event.location;
                  final diagnostics = event.diagnostics;

                  var errorMessage = payload;
                  if (errorCode != null && location != null) {
                    errorMessage =
                        '[$errorCode]\n$payload\nLocation: $location';
                    if (diagnostics != null && diagnostics.isNotEmpty) {
                      final stateInfo = diagnostics.entries
                          .where((entry) => entry.key != 'timestamp')
                          .map((entry) => '${entry.key}: ${entry.value}')
                          .join(', ');
                      if (stateInfo.isNotEmpty) {
                        errorMessage += '\nState: $stateInfo';
                      }
                    }
                  }

                  unawaited(notifier.onAutomationFailed(errorMessage));
                  return;
                default:
                  // Handle any unexpected event types
                  final talker = ref.read(talkerProvider);
                  talker.info(
                    '[Bridge Handler] Unknown event type: ${event.type}',
                  );
                  return;
              }
            } on Object catch (e) {
              final talker = ref.read(talkerProvider);
              talker.info('[Bridge Handler] Failed to parse event: $e');
            }
          },
        );

        controller.addJavaScriptHandler(
          handlerName: BridgeConstants.readyHandler,
          callback: (args) {
            final talker = ref.read(talkerProvider);
            talker.info('[AiWebviewScreen] bridgeReady handler called');
            ref
              ..read(bridgeReadyProvider.notifier).markReady()
              ..read(
                bridgeDiagnosticsStateProvider.notifier,
              ).recordBridgeReady();
          },
        );
      },
      onProgressChanged: (controller, progress) {
        setState(() {
          _progress = progress / 100;
        });
      },
      onLoadStart: (controller, url) async {
        setState(() {
          _progress = 0;
        });
        // WHY: This is critical to prevent race conditions. Whenever a new page starts
        // loading, we must consider the bridge not ready until the new page explicitly
        // signals its readiness via the 'bridgeReady' handler.
        ref.read(bridgeReadyProvider.notifier).reset();
      },
      onLoadStop: (controller, url) async {
        setState(() {
          _progress = 1.0;
        });

        final talker = ref.read(talkerProvider);
        final currentUrl = url?.toString() ?? 'unknown';
        talker.info('[WebView] Page finished loading: $currentUrl');

        // WHY: This check is now stricter. It verifies the exact host of the URL,
        // preventing the bridge script from being injected into cross-origin
        // redirect pages like the Google login page.
        if (url?.host == WebViewConstants.aiStudioDomain ||
            currentUrl.startsWith('file://')) {
          talker.info(
            '[WebView] URL matches AI Studio domain, injecting bridge script...',
          );
          await _injectBridgeScript(controller, bridgeScript);
        } else {
          talker.warning(
            '[WebView] URL does not match AI Studio domain, bridge script NOT injected.',
          );
        }

        final bridge = ref.read(javaScriptBridgeProvider);
        if (bridge is JavaScriptBridge) {
          await bridge.captureConsoleLogs();
        }
      },
      onUpdateVisitedHistory: (controller, url, androidIsReload) async {
        final newUrl = url?.toString() ?? '';
        ref.read(currentWebViewUrlProvider.notifier).updateUrl(newUrl);

        // WHY: Applying the same strict host check here ensures that client-side
        // routing to an external page doesn't trigger a faulty bridge injection.
        if (url?.host == WebViewConstants.aiStudioDomain ||
            newUrl.startsWith('file://')) {
          try {
            final bridge = ref.read(javaScriptBridgeProvider);
            if (bridge is JavaScriptBridge) {
              final isAlive = await bridge.isBridgeAlive();
              if (!isAlive) {
                final talker = ref.read(talkerProvider);
                talker.warning(
                  '[AiWebviewScreen] Bridge dead after SPA navigation, re-injecting...',
                );
                await _injectBridgeScript(controller, _currentBridgeScript);
              }
            }
          } on Object catch (e) {
            final talker = ref.read(talkerProvider);
            talker.warning(
              '[AiWebviewScreen] Error checking bridge after SPA navigation: $e',
            );
            // WHY: On error, attempt re-injection anyway as defensive measure
            await _injectBridgeScript(controller, _currentBridgeScript);
          }
        }
      },
      // WHY: Android renderer process crash is fatal - WebView instance becomes unusable
      // Recovery requires destroying and recreating the entire widget via key change
      onRenderProcessGone: (controller, details) {
        final talker = ref.read(talkerProvider);
        talker.warning(
          '[AiWebviewScreen] Android renderer process crashed: ${details.didCrash}',
        );
        // Reset bridge state
        ref.read(bridgeReadyProvider.notifier).reset();
        // WHY: Increment key to trigger widget recreation (only way to recover on Android)
        ref.read(webViewKeyProvider.notifier).incrementKey();
      },
      // WHY: iOS content process crashes are handled via lifecycle observer (didChangeAppLifecycleState)
      // The heartbeat check on app resume will detect and recover from zombie contexts
      // iOS crashes often manifest as "zombie" contexts that hang on evaluateJavascript calls
      onConsoleMessage: (controller, consoleMessage) {
        final talker = ref.read(talkerProvider);
        final message = '[WebView CONSOLE] ${consoleMessage.message}';
        // WHY: Pipe WebView console messages to talker with appropriate log levels
        // This centralizes all logs from both Dart and WebView JavaScript contexts.
        switch (consoleMessage.messageLevel) {
          case ConsoleMessageLevel.ERROR:
            talker.error(message);
          case ConsoleMessageLevel.WARNING:
            talker.warning(message);
          default:
            talker.info(message);
        }
      },
      onReceivedError: (controller, request, error) {
        setState(() {
          _progress = 1.0;
        });
      },
    );
  }

  /// WHY: Centralized bridge injection logic reused by onLoadStop and recovery paths
  Future<void> _injectBridgeScript(
    InAppWebViewController controller,
    String? bridgeScript,
  ) async {
    if (bridgeScript == null || bridgeScript.isEmpty) return;

    try {
      await controller.evaluateJavascript(source: bridgeScript);
      final currentUrl = await controller.getUrl();
      final talker = ref.read(talkerProvider);
      talker.info(
        '[AiWebviewScreen] Bridge script (re-)injected on ${currentUrl?.toString() ?? 'unknown'}.',
      );
    } on Object catch (e) {
      final talker = ref.read(talkerProvider);
      talker.warning('[AiWebviewScreen] Error injecting bridge script: $e');
    }
  }

  /// WHY: Recovery method for dead bridge contexts (called after heartbeat failure)
  Future<void> _recoverFromDeadBridge(InAppWebViewController controller) async {
    try {
      final currentUrl = await controller.getUrl();

      // WHY: Only attempt recovery on supported domains. Using strict host check
      // prevents recovery attempts on cross-origin redirect pages.
      if (currentUrl?.host == WebViewConstants.aiStudioDomain ||
          (currentUrl?.toString() ?? '').startsWith('file://')) {
        // Attempt to re-inject bridge script
        await _injectBridgeScript(controller, _currentBridgeScript);
      } else {
        // WHY: If on unsupported domain, reload to a known good state
        await controller.reload();
      }
    } on Object catch (e) {
      final talker = ref.read(talkerProvider);
      talker.warning('[AiWebviewScreen] Error during bridge recovery: $e');
    }
  }
}
