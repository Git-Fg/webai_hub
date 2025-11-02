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
    print("Generation completed, extracting response...");

    try {
      final bridge = ref.read(javaScriptBridgeProvider);
      final response = await bridge.extractFinalResponse();

      // Mettre à jour le message dans la conversation
      final conversationNotifier = ref.read(conversationProvider.notifier);
      final currentMessages = ref.read(conversationProvider);

      // Trouver le dernier message "Envoi en cours..." et le remplacer
      if (currentMessages.isNotEmpty) {
        final lastMessage = currentMessages.last;
        if (!lastMessage.isFromUser && lastMessage.status == MessageStatus.sending) {
          // Mettre à jour le message avec la réponse extraite
          final notifier = ref.read(conversationProvider.notifier);
          final newMessages = List<Message>.from(currentMessages);
          newMessages[newMessages.length - 1] = lastMessage.copyWith(
            text: response.trim(),
            status: MessageStatus.success,
          );
          notifier.state = newMessages;
        } else {
          // Ajouter la réponse comme nouveau message si pas de message en cours
          conversationNotifier.addMessage(response.trim(), false);
        }
      } else {
        conversationNotifier.addMessage(response.trim(), false);
      }

      print("Response extracted and displayed: ${response.length} characters");
    } catch (e) {
      print("Failed to extract response: $e");
      _handleAutomationFailed("Failed to extract response: $e");
    }
  }

  void _handleAutomationFailed(String? error) {
    print("Automation failed: $error");

    final conversationNotifier = ref.read(conversationProvider.notifier);
    final currentMessages = ref.read(conversationProvider);

    // Mettre à jour le dernier message "Envoi en cours..." avec une erreur
    if (currentMessages.isNotEmpty) {
      final lastMessage = currentMessages.last;
      if (!lastMessage.isFromUser && lastMessage.status == MessageStatus.sending) {
        final notifier = ref.read(conversationProvider.notifier);
        final newMessages = List<Message>.from(currentMessages);
        newMessages[newMessages.length - 1] = lastMessage.copyWith(
          text: "Erreur d'automatisation: ${error ?? 'Unknown error'}",
          status: MessageStatus.error,
        );
        notifier.state = newMessages;
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
              clearCache: false, // Garder le cache pour maintenir la session
              clearSessionCache: false, // Garder les cookies de session
              mediaPlaybackRequiresUserGesture: false,
              userAgent: 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Mobile Safari/537.36',
            ),
            onWebViewCreated: (controller) {
              webViewController = controller;

              // Stocker le contrôleur dans Riverpod
              ref.read(webViewControllerProvider.notifier).state = controller;

              // CRITIQUE : Enregistrer le handler pour écouter les messages du TS
              controller.addJavaScriptHandler(
                handlerName: 'automationBridge',
                callback: (args) {
                  if (args.isNotEmpty) {
                    final event = args[0] as Map<String, dynamic>;
                    final eventType = event['type'] as String?;

                    print("Received from JS: $eventType");

                    switch (eventType) {
                      case 'GENERATION_COMPLETE':
                        _handleGenerationComplete(controller);
                        break;
                      case 'AUTOMATION_FAILED':
                        _handleAutomationFailed(event['payload'] as String?);
                        break;
                      default:
                        print("Unknown event type: $eventType");
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
              // Ne charger que pour la page principale, pas pour les iframes ou ressources
              if (url != null && url.toString().contains('aistudio.google.com') && !scriptInjected) {
                setState(() {
                  isLoading = false;
                });

                // CRITIQUE : Injecter notre script d'automatisation UNE SEULE FOIS
                try {
                  // Attendre un peu que la page soit complètement chargée
                  await Future.delayed(const Duration(seconds: 2));

                  final bridgeFile = await rootBundle.loadString('assets/js/bridge.js');
                  await controller.evaluateJavascript(source: bridgeFile);

                  setState(() {
                    scriptInjected = true;
                  });

                  print("Bridge script injected successfully!");
                } catch (e) {
                  print("Error injecting bridge script: $e");
                }
              } else {
                setState(() {
                  isLoading = false;
                });
              }
            },
            onReceivedError: (controller, request, error) {
              print("WebView error: ${error.description}");
              setState(() {
                isLoading = false;
              });
            },
          ),

          // Overlay de chargement
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
                      'Chargement de Google AI Studio...',
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