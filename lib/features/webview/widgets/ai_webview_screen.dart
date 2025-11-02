import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';

class AiWebviewScreen extends ConsumerStatefulWidget {
  const AiWebviewScreen({super.key});

  @override
  ConsumerState<AiWebviewScreen> createState() => _AiWebviewScreenState();
}

class _AiWebviewScreenState extends ConsumerState<AiWebviewScreen> {
  InAppWebViewController? webViewController;
  bool isLoading = true;
  String? _bridgeScript;

  @override
  void initState() {
    super.initState();
    // Load the script once when the widget starts
    rootBundle.loadString('assets/js/bridge.js').then((script) {
      setState(() {
        _bridgeScript = script;
      });
    });
  }

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Wait for script to be loaded before building WebView
          if (_bridgeScript != null)
            InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri("https://aistudio.google.com/prompts/new_chat"),
              ),
              // CRITICAL: Use initialUserScripts for injection
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
                userAgent: 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Mobile Safari/537.36',
              ),
              onWebViewCreated: (controller) {
                webViewController = controller;
                ref.read(webViewControllerProvider.notifier).state = controller;

                controller.addJavaScriptHandler(
                  handlerName: 'automationBridge',
                  callback: (args) {
                    if (args.isNotEmpty) {
                      final event = args[0] as Map<String, dynamic>;
                      final eventType = event['type'] as String?;

                      // Route events to the ConversationProvider
                      final notifier = ref.read(conversationProvider.notifier);

                      switch (eventType) {
                        case 'GENERATION_COMPLETE':
                          notifier.onGenerationComplete();
                          break;
                        case 'AUTOMATION_FAILED':
                          final payload = event['payload'] as String? ?? 'Unknown error';
                          notifier.onAutomationFailed(payload);
                          break;
                      }
                    }
                  },
                );
              },
              onLoadStart: (controller, url) {
                setState(() {
                  isLoading = true;
                });
              },
              onLoadStop: (controller, url) async {
                setState(() {
                  isLoading = false;
                });
              },
              onReceivedError: (controller, request, error) {
                setState(() {
                  isLoading = false;
                });
              },
            ),

          if (isLoading)
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading Google AI Studio...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}