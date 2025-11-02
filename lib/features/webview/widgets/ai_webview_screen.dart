import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';

class AiWebviewScreen extends ConsumerStatefulWidget {
  const AiWebviewScreen({super.key});

  @override
  ConsumerState<AiWebviewScreen> createState() => _AiWebviewScreenState();
}

class _AiWebviewScreenState extends ConsumerState<AiWebviewScreen> {
  InAppWebViewController? webViewController;
  bool isLoading = true;
  bool scriptInjected = false;

  void _handleGenerationComplete(InAppWebViewController controller) async {
    try {
      final bridge = ref.read(javaScriptBridgeProvider);
      final response = await bridge.extractFinalResponse();

      final currentMessages = ref.read(conversationProvider);

      if (currentMessages.isNotEmpty) {
        final lastMessage = currentMessages.last;
        if (!lastMessage.isFromUser && lastMessage.status == MessageStatus.sending) {
          final newMessages = List<Message>.from(currentMessages);
          newMessages[newMessages.length - 1] = lastMessage.copyWith(
            text: response.trim(),
            status: MessageStatus.success,
          );
          ref.read(conversationProvider.notifier).state = newMessages;
        } else {
          ref.read(conversationProvider.notifier).addMessage(response.trim(), false);
        }
      } else {
        ref.read(conversationProvider.notifier).addMessage(response.trim(), false);
      }
    } catch (e) {
      _handleAutomationFailed("Failed to extract response: $e");
    }
  }

  void _handleAutomationFailed(String? error) {
    final currentMessages = ref.read(conversationProvider);

    if (currentMessages.isNotEmpty) {
      final lastMessage = currentMessages.last;
      if (!lastMessage.isFromUser && lastMessage.status == MessageStatus.sending) {
        final newMessages = List<Message>.from(currentMessages);
        newMessages[newMessages.length - 1] = lastMessage.copyWith(
          text: "Automation error: ${error ?? 'Unknown error'}",
          status: MessageStatus.error,
        );
        ref.read(conversationProvider.notifier).state = newMessages;
      }
    }
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
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri("https://aistudio.google.com/prompts/new_chat"),
            ),
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

                    switch (eventType) {
                      case 'GENERATION_COMPLETE':
                        _handleGenerationComplete(controller);
                        break;
                      case 'AUTOMATION_FAILED':
                        _handleAutomationFailed(event['payload'] as String?);
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
              if (url != null && url.toString().contains('aistudio.google.com') && !scriptInjected) {
                setState(() {
                  isLoading = false;
                });

                try {
                  await Future.delayed(const Duration(seconds: 2));

                  final bridgeFile = await rootBundle.loadString('assets/js/bridge.js');
                  await controller.evaluateJavascript(source: bridgeFile);

                  setState(() {
                    scriptInjected = true;
                  });
                } catch (e) {
                }
              } else {
                setState(() {
                  isLoading = false;
                });
              }
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