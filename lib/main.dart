import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart' as chat_ui;
import 'dart:convert';

import 'models/app_models.dart';
import 'models/chat_message.dart';
import 'models/providers.dart';
import 'providers/app_providers.dart';
import 'services/database_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Isar database
  await DatabaseService.initialize();

  // Enable WebView debugging in debug mode
  if (!kIsWeb && kDebugMode && defaultTargetPlatform == TargetPlatform.android) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
  }

  runApp(
    const ProviderScope(
      child: MaterialApp(
        home: WebAIHub(),
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
}

class WebAIHub extends ConsumerStatefulWidget {
  const WebAIHub({Key? key}) : super(key: key);

  @override
  ConsumerState<WebAIHub> createState() => _WebAIHubState();
}

class _WebAIHubState extends ConsumerState<WebAIHub>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    
    // Listen to tab changes
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(currentTabIndexProvider.notifier).state = _tabController.index;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to tab index changes from providers
    ref.listen<int>(currentTabIndexProvider, (previous, next) {
      if (_tabController.index != next) {
        _tabController.animateTo(next);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('WebAI Hub'),
        backgroundColor: Colors.deepPurple,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          tabs: const [
            Tab(icon: Icon(Icons.hub), text: 'Hub'),
            Tab(icon: Icon(Icons.auto_awesome), text: 'AI Studio'),
            Tab(icon: Icon(Icons.cloud), text: 'Qwen'),
            Tab(icon: Icon(Icons.flash_on), text: 'Z-ai'),
            Tab(icon: Icon(Icons.document_scanner), text: 'Kimi'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildHubTab(),
              _buildProviderWebView(Providers.aiStudio),
              _buildProviderWebView(Providers.qwen),
              _buildProviderWebView(Providers.zai),
              _buildProviderWebView(Providers.kimi),
            ],
          ),
          // Overlay for WebView tabs only
          _buildCompanionOverlay(),
        ],
      ),
    );
  }

  /// Build the Hub tab (native chat UI)
  Widget _buildHubTab() {
    final messages = ref.watch(hubMessagesProvider);
    final selectedProvider = ref.watch(selectedProviderProvider);
    final providerStatuses = ref.watch(providerStatusProvider);

    return Column(
      children: [
        // Provider selector
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.grey[200],
          child: Row(
            children: [
              const Text('Provider: ', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: selectedProvider,
                  isExpanded: true,
                  items: Providers.all.map((provider) {
                    final status = providerStatuses[provider.id] ?? ProviderStatus.unknown;
                    final statusIcon = _getStatusIcon(status);
                    return DropdownMenuItem(
                      value: provider.id,
                      child: Row(
                        children: [
                          Text(provider.name),
                          const SizedBox(width: 8),
                          Text(statusIcon, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(selectedProviderProvider.notifier).state = value;
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        // Chat UI
        Expanded(
          child: _buildChatUI(messages, selectedProvider),
        ),
      ],
    );
  }

  String _getStatusIcon(ProviderStatus status) {
    switch (status) {
      case ProviderStatus.ready:
        return '✅ Prêt';
      case ProviderStatus.needsLogin:
        return '❌ Connexion requise';
      case ProviderStatus.error:
        return '⚠️ Erreur';
      case ProviderStatus.unknown:
        return '❓ Inconnu';
    }
  }

  Widget _buildChatUI(List<ChatMessage> messages, String selectedProvider) {
    // Convert our ChatMessage to chat_ui format
    final chatMessages = messages.map((msg) {
      return chat_ui.ChatMessage(
        id: msg.messageId,
        text: msg.text,
        user: chat_ui.ChatUser(
          id: msg.role == MessageRole.user ? 'user' : msg.provider ?? 'assistant',
          firstName: msg.role == MessageRole.user ? 'You' : msg.provider ?? 'AI',
        ),
        createdAt: msg.createdAt,
      );
    }).toList();

    return chat_ui.GenAiChatUI(
      messages: chatMessages,
      onSend: (chat_ui.ChatMessage message) {
        _onSendMessage(message.text, selectedProvider);
      },
      currentUser: const chat_ui.ChatUser(
        id: 'user',
        firstName: 'You',
      ),
    );
  }

  void _onSendMessage(String text, String providerId) {
    final workflow = ref.read(workflowProvider);
    workflow.startAssistedWorkflow(
      prompt: text,
      providerId: providerId,
    );
  }

  /// Build a WebView for an AI provider
  Widget _buildProviderWebView(ProviderConfig provider) {
    return _ProviderWebView(
      key: Key(provider.id),
      provider: provider,
    );
  }

  /// Build the companion overlay for automation feedback
  Widget _buildCompanionOverlay() {
    final currentTab = ref.watch(currentTabIndexProvider);
    final overlayState = ref.watch(overlayStateProvider);

    // Only show on WebView tabs (1-4), not on Hub (0)
    if (currentTab == 0 || overlayState.state == OverlayState.hidden) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.deepPurple.withOpacity(0.95),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              overlayState.message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (overlayState.showValidateButton)
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(workflowProvider).validateAndReturn();
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('✅ Valider et envoyer au Hub'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (overlayState.showValidateButton && overlayState.showCancelButton)
                  const SizedBox(width: 12),
                if (overlayState.showCancelButton)
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(workflowProvider).cancel();
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('❌ Annuler'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget for a provider WebView
class _ProviderWebView extends ConsumerStatefulWidget {
  final ProviderConfig provider;

  const _ProviderWebView({
    Key? key,
    required this.provider,
  }) : super(key: key);

  @override
  ConsumerState<_ProviderWebView> createState() => _ProviderWebViewState();
}

class _ProviderWebViewState extends ConsumerState<_ProviderWebView> {
  InAppWebViewController? _controller;
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.provider.url)),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            domStorageEnabled: true, // Essential for session persistence
            databaseEnabled: true, // Essential for session persistence
            useShouldOverrideUrlLoading: true,
            javaScriptCanOpenWindowsAutomatically: false,
            mediaPlaybackRequiresUserGesture: true,
            isFraudulentWebsiteWarningEnabled: true,
            safeBrowsingEnabled: true,
          ),
          onWebViewCreated: (controller) async {
            _controller = controller;
            
            // Register this controller
            final controllers = ref.read(webViewControllersProvider);
            ref.read(webViewControllersProvider.notifier).state = {
              ...controllers,
              widget.provider.id: controller,
            };

            // Add JavaScript handler for this provider
            controller.addJavaScriptHandler(
              handlerName: '${widget.provider.id}Bridge',
              callback: (args) {
                if (args.isNotEmpty) {
                  _handleJavaScriptMessage(args[0].toString());
                }
              },
            );
          },
          onLoadStop: (controller, url) async {
            await _injectBridge(controller);
            await _checkStatus(controller);
          },
          onProgressChanged: (controller, progress) {
            setState(() {
              _progress = progress / 100;
            });
          },
        ),
        if (_progress < 1.0)
          LinearProgressIndicator(value: _progress),
      ],
    );
  }

  Future<void> _injectBridge(InAppWebViewController controller) async {
    try {
      // Load bridge.js
      final bridgeScript = await rootBundle.loadString('assets/js/bridge.js');
      
      // Inject the bridge class
      await controller.evaluateJavascript(source: bridgeScript);
      
      // Initialize a bridge instance for this provider
      final initScript = '''
        if (!window.hubBridge_${widget.provider.id}) {
          window.hubBridge_${widget.provider.id} = new HubBridge(
            '${widget.provider.id}Bridge',
            '${widget.provider.id}'
          );
          window.hubBridge_${widget.provider.id}.init();
        }
      ''';
      
      await controller.evaluateJavascript(source: initScript);
      
      print('[WebAIHub] Bridge injected for ${widget.provider.id}');
    } catch (e) {
      print('[WebAIHub] Failed to inject bridge: $e');
    }
  }

  Future<void> _checkStatus(InAppWebViewController controller) async {
    try {
      final selectorsAsync = ref.read(selectorsProvider);
      if (!selectorsAsync.hasValue) return;
      
      final allSelectors = selectorsAsync.value!;
      final providerSelectors = allSelectors[widget.provider.id];
      
      final jsCode = '''
        window.hubBridge_${widget.provider.id}.checkStatus(
          ${json.encode(providerSelectors)}
        );
      ''';
      
      await controller.evaluateJavascript(source: jsCode);
    } catch (e) {
      print('[WebAIHub] Failed to check status: $e');
    }
  }

  void _handleJavaScriptMessage(String message) {
    try {
      final data = json.decode(message);
      final event = data['event'] as String;
      final payload = data['payload'] as Map<String, dynamic>?;

      print('[WebAIHub] Received event: $event from ${widget.provider.id}');

      final workflow = ref.read(workflowProvider);

      switch (event) {
        case 'onStatusResult':
          final status = payload?['status'] as String? ?? 'unknown';
          workflow.onStatusResult(widget.provider.id, status);
          break;
        case 'onGenerationComplete':
          workflow.onGenerationComplete();
          break;
        case 'onInjectionFailed':
          final error = payload?['error'] as String? ?? 'Unknown error';
          workflow.onInjectionFailed(error);
          break;
        case 'onExtractionResult':
          final content = payload?['content'] as String? ?? '';
          workflow.onExtractionResult(content);
          break;
        case 'onExtractionFailed':
          final error = payload?['error'] as String? ?? 'Failed to extract content';
          workflow.onInjectionFailed(error);
          break;
        case 'onCancelled':
          // Already handled by cancel() method
          break;
      }
    } catch (e) {
      print('[WebAIHub] Failed to handle message: $e');
    }
  }
}
