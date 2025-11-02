import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/bridge_diagnostics_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';
import 'package:ai_hybrid_hub/providers/bridge_script_provider.dart';

class AiWebviewScreen extends ConsumerStatefulWidget {
  const AiWebviewScreen({super.key});

  @override
  ConsumerState<AiWebviewScreen> createState() => _AiWebviewScreenState();
}

class _AiWebviewScreenState extends ConsumerState<AiWebviewScreen> {
  InAppWebViewController? webViewController;
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    // Debug: Log build calls (remove in production)
    // ignore: avoid_print
    // print('[AiWebviewScreen] build() called. webViewController is ${webViewController != null ? "set" : "null"}');
    final bridgeScriptAsync = ref.watch(bridgeScriptProvider);
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
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () async {
                if (webViewController == null) return;
                try {
                  // ignore: avoid_print
                  print('[DOM INSPECT] Requesting DOM analysis...');
                  final result = await webViewController!.evaluateJavascript(
                    source: "inspectDOMForSelectors();",
                  );
                  if (result != null) {
                    // Affiche le JSON joliment formaté
                    final encoder = JsonEncoder.withIndent('  ');
                    final prettyJson = encoder.convert(result);
                    // ignore: avoid_print
                    print('[DOM INSPECT] Result:\n$prettyJson');
                  } else {
                    // ignore: avoid_print
                    print(
                        '[DOM INSPECT] inspectDOMForSelectors returned null.');
                  }
                } catch (e) {
                  // ignore: avoid_print
                  print('[DOM INSPECT] Error: $e');
                }
              },
              tooltip: 'Inspect DOM for Selectors',
            ),
          ],
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
        body: bridgeScriptAsync.when(
          data: (bridgeScript) => _buildWebView(bridgeScript),
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (err, stack) => Scaffold(
            body: Center(
              child: Text('Error loading bridge script: $err'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebView(String bridgeScript) {
    // Définir une variable pour switcher facilement
    const bool useLocalSandbox = true;

    return InAppWebView(
      key: const ValueKey('ai_webview'), // Key to force rebuild if needed
      // MODIFICATION CLÉ : Charger localement ou à distance
      initialUrlRequest: useLocalSandbox
          ? URLRequest(
              url: WebUri(
                  "file:///android_asset/flutter_assets/assets/test_page.html"))
          : URLRequest(
              url: WebUri("https://aistudio.google.com/prompts/new_chat")),
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: bridgeScript,
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
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36',
      ),
      onWebViewCreated: (controller) {
        // Debug: Log WebView creation (remove in production)
        // ignore: avoid_print
        // print('[AiWebviewScreen] onWebViewCreated called!');
        webViewController = controller;
        // Set controller immediately so waitForBridgeReady can find it
        ref.read(webViewControllerProvider.notifier).setController(controller);
        // ignore: avoid_print
        // print('[AiWebviewScreen] Controller set in provider');
        ref
            .read(bridgeDiagnosticsStateProvider.notifier)
            .recordWebViewCreated();

        controller.addJavaScriptHandler(
          handlerName: 'automationBridge',
          callback: (args) {
            if (args.isNotEmpty) {
              final event = args[0] as Map<String, dynamic>;
              final eventType = event['type'] as String?;

              final notifier = ref.read(conversationProvider.notifier);

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
                    if (diagnostics != null && diagnostics.isNotEmpty) {
                      final stateInfo = diagnostics.entries
                          .where((entry) => entry.key != 'timestamp')
                          .map((entry) => '${entry.key}: ${entry.value}')
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
            ref.read(bridgeReadyProvider.notifier).markReady();
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
        // Reset bridge ready when page is fully loaded so JS can signal ready
        ref.read(bridgeReadyProvider.notifier).reset();

        // Capture console logs
        final bridge = ref.read(javaScriptBridgeProvider);
        await (bridge as JavaScriptBridge).captureConsoleLogs();
      },
      onReceivedError: (controller, request, error) {
        setState(() {
          _progress = 1.0;
        });
      },
    );
  }
}
