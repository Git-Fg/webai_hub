import 'dart:async';
import 'dart:convert';

import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/bridge_constants.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/bridge_diagnostics_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:ai_hybrid_hub/features/webview/models/webview_content.dart';
import 'package:ai_hybrid_hub/features/webview/providers/webview_content_provider.dart';
import 'package:ai_hybrid_hub/providers/bridge_script_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String? _htmlContent;
  // Flag pour contrôler l'injection unique du script bridge
  bool _isBridgeInjected = false;

  @override
  void initState() {
    super.initState();
    // Charger le HTML depuis les assets de manière asynchrone
    unawaited(_loadHtmlContent());
  }

  Future<void> _loadHtmlContent() async {
    try {
      final content =
          await rootBundle.loadString('assets/sandboxes/aistudio_sandbox.html');
      if (mounted) {
        setState(() {
          _htmlContent = content;
        });
      }
    } on Object catch (e) {
      debugPrint('[AiWebviewScreen] Error loading HTML: $e');
      if (mounted) {
        setState(() {
          _htmlContent = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Debug: Log build calls (remove in production)
    // print('[AiWebviewScreen] build() called. webViewController is ${webViewController != null ? "set" : "null"}');
    final bridgeScriptAsync = ref.watch(bridgeScriptProvider);
    final webViewContent = ref.watch(initialWebViewContentProvider);
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
                    // Affiche le JSON joliment formaté
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
          data: (bridgeScript) {
            if (webViewContent is WebViewContentHtmlFile &&
                _htmlContent == null) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return _buildWebView(bridgeScript, webViewContent);
          },
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

  Widget _buildWebView(String bridgeScript, WebViewContent content) {
    return InAppWebView(
      key: const ValueKey('ai_webview'), // Key to force rebuild if needed
      initialUrlRequest: content is WebViewContentUrl
          ? URLRequest(url: WebUri(content.url))
          : null,
      initialData: content is WebViewContentHtmlFile
          ? InAppWebViewInitialData(
              data: _htmlContent ?? '', // HTML pur, sans script pré-injecté
              baseUrl: WebUri('file:///android_asset/flutter_assets/'),
            )
          : null,
      // --- MODIFICATION : Supprimer initialUserScripts pour contrôle manuel ---
      // Le script sera injecté manuellement dans onLoadStop pour éviter les ré-injections
      // lors des navigations internes (changement d'URL après envoi du prompt)
      initialSettings: InAppWebViewSettings(
        supportZoom: false,
        mediaPlaybackRequiresUserGesture: false,
      ),
      onWebViewCreated: (controller) {
        // Debug: Log WebView creation (remove in production)
        // print('[AiWebviewScreen] onWebViewCreated called!');
        webViewController = controller;
        // Set controller immediately so waitForBridgeReady can find it
        ref.read(webViewControllerProvider.notifier).setController(controller);
        // print('[AiWebviewScreen] Controller set in provider');
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
                  final diags = event['diagnostics'] as Map<String, dynamic>?;
                  final messageCount = diags?['messageCount'] as int? ?? 0;
                  if (messageCount > 0) {
                    automationNotifier.setStatus(
                      AutomationStateData.refining(
                        messageCount: messageCount,
                      ),
                    );
                  }
                case BridgeConstants.eventTypeLoginRequired:
                  // Mettre le statut à needsLogin pour afficher l'overlay de login
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
              }
            }
          },
        );

        controller.addJavaScriptHandler(
          handlerName: BridgeConstants.readyHandler,
          callback: (args) {
            debugPrint('[AiWebviewScreen] bridgeReady handler called');
            // Le ref du ConsumerStatefulWidget pointe vers le même container
            // que celui utilisé dans UncontrolledProviderScope
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
        // --- MODIFICATION : Ne réinitialiser le bridge que si on quitte le domaine AI Studio ---
        // On ne reset que si on quitte complètement le domaine pour y revenir
        // Cela évite de réinitialiser lors des navigations internes (changement d'URL après envoi)
        final currentUrl = await controller.getUrl();
        if (currentUrl != null &&
            currentUrl.host != 'aistudio.google.com' &&
            url?.host == 'aistudio.google.com') {
          // On revient sur AI studio après être parti ailleurs
          _isBridgeInjected = false;
          ref.read(bridgeReadyProvider.notifier).reset();
        }
      },
      onLoadStop: (controller, url) async {
        setState(() {
          _progress = 1.0;
        });

        // --- NOUVELLE LOGIQUE D'INJECTION ---
        // Injecter le script manuellement seulement s'il ne l'a pas déjà été
        // Cela évite les ré-injections lors des navigations internes (changement d'URL après envoi)
        if (!_isBridgeInjected &&
            (url?.toString().contains('aistudio.google.com') ?? true)) {
          // 'true' pour le sandbox HTML
          await controller.evaluateJavascript(source: bridgeScript);
          _isBridgeInjected = true;
          debugPrint('[AiWebviewScreen] Bridge script manually injected.');
        }

        // Capture console logs
        final bridge = ref.read(javaScriptBridgeProvider);
        await (bridge as JavaScriptBridge).captureConsoleLogs();
      },
      onConsoleMessage: (controller, consoleMessage) {
        // Capture console messages for debugging
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
