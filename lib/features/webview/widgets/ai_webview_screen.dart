import 'dart:convert';

import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/bridge_constants.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/bridge_diagnostics_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:ai_hybrid_hub/providers/bridge_script_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiWebviewScreen extends ConsumerStatefulWidget {
  const AiWebviewScreen({super.key});

  @override
  ConsumerState<AiWebviewScreen> createState() => _AiWebviewScreenState();
}

class _AiWebviewScreenState extends ConsumerState<AiWebviewScreen> {
  InAppWebViewController? webViewController;
  double _progress = 0;

  static const String _aiStudioUrl =
      'https://aistudio.google.com/prompts/new_chat';

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
                try {
                  debugPrint('[DOM INSPECT] Requesting DOM analysis...');
                  final result = await webViewController!.evaluateJavascript(
                    source: 'inspectDOMForSelectors();',
                  );
                  if (result != null) {
                    const encoder = JsonEncoder.withIndent('  ');
                    final prettyJson = encoder.convert(result);
                    debugPrint('[DOM INSPECT] Result:\n$prettyJson');
                  } else {
                    debugPrint(
                      '[DOM INSPECT] inspectDOMForSelectors returned null.',
                    );
                  }
                } on Object catch (e) {
                  debugPrint('[DOM INSPECT] Error: $e');
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
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
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
    return InAppWebView(
      key: const ValueKey('ai_webview'),
      initialUrlRequest: URLRequest(url: WebUri(_aiStudioUrl)),
      initialSettings: InAppWebViewSettings(
        supportZoom: false,
        mediaPlaybackRequiresUserGesture: false,
        useShouldOverrideUrlLoading: true,
      ),
      onWebViewCreated: (controller) {
        webViewController = controller;
        ref.read(webViewControllerProvider.notifier).setController(controller);
        ref
            .read(bridgeDiagnosticsStateProvider.notifier)
            .recordWebViewCreated();

        controller.addJavaScriptHandler(
          handlerName: BridgeConstants.automationHandler,
          callback: (args) {
            if (args.isNotEmpty) {
              final event = args[0] as Map<String, dynamic>;
              final eventType = event['type'] as String?;
              final notifier = ref.read(conversationProvider.notifier);
              final automationNotifier =
                  ref.read(automationStateProvider.notifier);

              switch (eventType) {
                case BridgeConstants.eventTypeNewResponse:
                  automationNotifier.setStatus(
                    AutomationStateData.refining(
                      messageCount: ref.read(conversationProvider).length,
                    ),
                  );
                case BridgeConstants.eventTypeLoginRequired:
                  automationNotifier.setStatus(
                    const AutomationStateData.needsLogin(),
                  );
                case BridgeConstants.eventTypeAutomationFailed:
                  final payload =
                      event['payload'] as String? ?? 'Unknown error';
                  final errorCode = event['errorCode'] as String?;
                  final location = event['location'] as String?;
                  final diagnostics =
                      event['diagnostics'] as Map<String, dynamic>?;

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

                  notifier.onAutomationFailed(errorMessage);
              }
            }
          },
        );

        controller.addJavaScriptHandler(
          handlerName: BridgeConstants.readyHandler,
          callback: (args) {
            debugPrint('[AiWebviewScreen] bridgeReady handler called');
            ref
              ..read(bridgeReadyProvider.notifier).markReady()
              ..read(bridgeDiagnosticsStateProvider.notifier)
                  .recordBridgeReady();
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
        ref.read(bridgeReadyProvider.notifier).reset();
      },
      onLoadStop: (controller, url) async {
        setState(() {
          _progress = 1.0;
        });

        await controller.evaluateJavascript(source: bridgeScript);
        debugPrint(
          '[AiWebviewScreen] Bridge script universally (re-)injected on $url.',
        );

        final bridge = ref.read(javaScriptBridgeProvider);
        if (bridge is JavaScriptBridge) {
          await bridge.captureConsoleLogs();
        }
      },
      onUpdateVisitedHistory: (controller, url, androidIsReload) {
        final newUrl = url?.toString() ?? '';
        ref.read(currentWebViewUrlProvider.notifier).updateUrl(newUrl);
      },
      onConsoleMessage: (controller, consoleMessage) {
        debugPrint('[WebView CONSOLE] ${consoleMessage.message}');
      },
      onReceivedError: (controller, request, error) {
        setState(() {
          _progress = 1.0;
        });
      },
    );
  }
}
