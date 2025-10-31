import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/ai_provider.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/models/automation_state.dart';
import '../providers/conversation_provider.dart';
import '../providers/provider_status_provider.dart';
import 'chat_bubble.dart';
import 'prompt_input.dart';
import 'provider_selector.dart';
import 'options_dialog.dart';

class HubScreen extends ConsumerStatefulWidget {
  const HubScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends ConsumerState<HubScreen>
    with TickerProviderStateMixin {
  late TabController _conversationTabController;
  final ScrollController _scrollController = ScrollController();
  bool _showWelcome = true;

  @override
  void initState() {
    super.initState();
    _conversationTabController = TabController(length: 2, vsync: this);

    // Initialize conversations if empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(conversationProvider.notifier).initializeIfNeeded();
    });
  }

  @override
  void dispose() {
    _conversationTabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationProvider);
    final currentConversation = ref.watch(currentConversationProvider);

    // Show welcome screen if no conversations
    if (conversations.isEmpty || currentConversation == null) {
      return _buildWelcomeScreen();
    }

    _showWelcome = false;
    return _buildChatInterface(currentConversation);
  }

  Widget _buildWelcomeScreen() {
    final providerStatuses = ref.watch(providerStatusProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.hub,
                    size: 48,
                    color: Colors.deepPurpleAccent,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Hybrid Hub',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Assistant intelligent multi-providers',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 48),

              // Welcome Message
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bienvenue dans votre Hub IA',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Commencez par vous connecter aux services IA ci-dessous, puis revenez ici pour commencer à discuter.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade300,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Provider Status Cards
              Text(
                'Statut des Providers',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: AIProvider.values.length,
                  itemBuilder: (context, index) {
                    final provider = AIProvider.fromIndex(index);
                    final status = providerStatuses[provider] ?? ProviderStatus.unknown;

                    return _buildProviderStatusCard(provider, status);
                  },
                ),
              ),

              // Quick Start Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _hasReadyProvider(providerStatuses) ? _startNewConversation : null,
                  icon: const Icon(Icons.chat),
                  label: const Text('Commencer une conversation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProviderStatusCard(AIProvider provider, ProviderStatus status) {
    IconData icon;
    Color color;
    String statusText;

    switch (status) {
      case ProviderStatus.ready:
        icon = Icons.check_circle;
        color = Colors.green;
        statusText = 'Prêt';
        break;
      case ProviderStatus.login:
        icon = Icons.login;
        color = Colors.orange;
        statusText = 'Connexion requise';
        break;
      case ProviderStatus.loading:
        icon = Icons.hourglass_empty;
        color = Colors.blue;
        statusText = 'Vérification...';
        break;
      case ProviderStatus.error:
        icon = Icons.error;
        color = Colors.red;
        statusText = 'Erreur';
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
        statusText = 'Inconnu';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status == ProviderStatus.ready
              ? Colors.green.withOpacity(0.3)
              : Colors.grey.shade600,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getProviderIcon(provider),
                color: Colors.deepPurpleAccent,
                size: 24,
              ),
              const Spacer(),
              Icon(
                icon,
                color: color,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            provider.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            statusText,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatInterface(Conversation conversation) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        elevation: 0,
        title: Row(
          children: [
            Icon(
              _getProviderIcon(conversation.provider),
              color: Colors.deepPurpleAccent,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              conversation.provider.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _showProviderOptions(conversation.provider),
            icon: const Icon(Icons.settings, color: Colors.white),
          ),
          IconButton(
            onPressed: _clearConversation,
            icon: const Icon(Icons.clear_all, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: conversation.messages.length,
              itemBuilder: (context, index) {
                final message = conversation.messages[index];
                return ChatBubble(
                  message: message,
                  isUser: message.type == MessageType.user,
                );
              },
            ),
          ),

          // Prompt Input
          PromptInput(
            onSend: _sendMessage,
            enabled: true,
          ),
        ],
      ),
    );
  }

  IconData _getProviderIcon(AIProvider provider) {
    switch (provider) {
      case AIProvider.aistudio:
        return Icons.auto_awesome;
      case AIProvider.qwen:
        return Icons.cloud;
      case AIProvider.zai:
        return Icons.flash_on;
      case AIProvider.kimi:
        return Icons.document_scanner;
    }
  }

  bool _hasReadyProvider(Map<AIProvider, ProviderStatus> statuses) {
    return statuses.values.any((status) => status == ProviderStatus.ready);
  }

  void _startNewConversation() {
    ref.read(conversationProvider.notifier).startNewConversation();
  }

  void _sendMessage(String message) {
    ref.read(conversationProvider.notifier).sendMessage(message);

    // Auto scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearConversation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Effacer la conversation?'),
        content: const Text('Cette action ne peut pas être annulée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(conversationProvider.notifier).clearCurrentConversation();
            },
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
  }

  void _showProviderOptions(AIProvider provider) {
    showDialog(
      context: context,
      builder: (context) => ProviderOptionsDialog(provider: provider),
    );
  }
}