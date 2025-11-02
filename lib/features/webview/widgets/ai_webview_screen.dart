import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/bridge_diagnostics_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';

class AiWebviewScreen extends ConsumerStatefulWidget {
  const AiWebviewScreen({super.key});

  @override
  ConsumerState<AiWebviewScreen> createState() => _AiWebviewScreenState();
}

class _AiWebviewScreenState extends ConsumerState<AiWebviewScreen> {
  InAppWebViewController? webViewController;
  double _progress = 0;
  String? _bridgeScript;

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/js/bridge.js').then((script) {
      setState(() {
        _bridgeScript = script;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        final controller = webViewController;
        if (controller != null && await controller.canGoBack()) {
          controller.goBack();
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
          bottom: _progress < 1.0
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(4.0),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.green.shade200,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : null,
        ),
        body: Stack(
          children: [
            if (_bridgeScript != null)
              InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri("https://aistudio.google.com/prompts/new_chat"),
                ),
                initialUserScripts: UnmodifiableListView<UserScript>([
                  UserScript(
                    source: _bridgeScript!,
                    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                  ),
                ]),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  supportZoom: false,
                  clearCache: false,
                  clearSessionCache: false,
                  mediaPlaybackRequiresUserGesture: false,
                  userAgent:
                      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Mobile Safari/537.36',
                ),
                onWebViewCreated: (controller) {
                  webViewController = controller;
                  ref
                      .read(webViewControllerProvider.notifier)
                      .setController(controller);
                  ref
                      .read(bridgeDiagnosticsStateProvider.notifier)
                      .recordWebViewCreated();

                  ref.read(bridgeReadyProvider.notifier).reset();

                  controller.addJavaScriptHandler(
                    handlerName: 'automationBridge',
                    callback: (args) {
                      if (args.isNotEmpty) {
                        final event = args[0] as Map<String, dynamic>;
                        final eventType = event['type'] as String?;

                        final notifier =
                            ref.read(conversationProvider.notifier);

                        switch (eventType) {
                          case 'GENERATION_COMPLETE':
                            notifier.onGenerationComplete();
                            break;
                          case 'AUTOMATION_FAILED':
                            final payload =
                                event['payload'] as String? ?? 'Unknown error';
                            final errorCode = event['errorCode'] as String?;
                            final location = event['location'] as String?;
                            final diagnostics =
                                event['diagnostics'] as Map<String, dynamic>?;

                            String errorMessage;
                            if (errorCode != null && location != null) {
                              errorMessage =
                                  '[$errorCode]\n$payload\nLocation: $location';
                              if (diagnostics != null &&
                                  diagnostics.isNotEmpty) {
                                final stateInfo = diagnostics.entries
                                    .where((entry) => entry.key != 'timestamp')
                                    .map((entry) =>
                                        '${entry.key}: ${entry.value}')
                                    .join(', ');
                                if (stateInfo.isNotEmpty) {
                                  errorMessage += '\nState: $stateInfo';
                                }
                              }
                            } else {
                              errorMessage = payload;
                            }

                            notifier.onAutomationFailed(errorMessage);
                            break;
                        }
                      }
                    },
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'bridgeReady',
                    callback: (args) {
                      ref.read(bridgeReadyProvider.notifier).complete();
                      ref
                          .read(bridgeDiagnosticsStateProvider.notifier)
                          .recordBridgeReady();
                    },
                  );
                },
                onProgressChanged: (controller, progress) {
                  setState(() {
                    _progress = progress / 100;
                  });
                },
                onLoadStart: (controller, url) {
                  setState(() {
                    _progress = 0;
                  });
                },
                onLoadStop: (controller, url) async {
                  setState(() {
                    _progress = 1.0;
                  });
                },
                onReceivedError: (controller, request, error) {
                  setState(() {
                    _progress = 1.0;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }
}
