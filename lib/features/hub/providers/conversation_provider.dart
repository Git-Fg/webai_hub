import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/models/ai_provider.dart';
import '../../automation/providers/automation_provider.dart';
import '../../webview/providers/webview_provider.dart';
import '../../../core/utils/prompt_formatter.dart';
import '../../../core/utils/javascript_bridge.dart';

class ConversationNotifier extends StateNotifier<List<Conversation>> {
  ConversationNotifier(this.ref) : super([]);

  final Ref ref;

  void initializeIfNeeded() {
    if (state.isEmpty) {
      // Start with a default conversation
      _startNewConversation(AIProvider.aistudio);
    }
  }

  void _startNewConversation(AIProvider provider) {
    final conversation = Conversation(
      provider: provider,
      messages: [],
    );
    state = [...state, conversation];
  }

  void startNewConversation([AIProvider? provider]) {
    provider ??= AIProvider.aistudio; // Default provider
    _startNewConversation(provider);
  }

  void sendMessage(String content, {AIProvider? provider}) {
    if (state.isEmpty) {
      startNewConversation(provider ?? AIProvider.aistudio);
    }

    final currentConversation = state.last;
    final userMessage = ChatMessage(
      content: content,
      type: MessageType.user,
      status: MessageStatus.sent,
    );

    // Create processing message for assistant response
    final processingMessage = ChatMessage(
      content: 'Envoi en cours...',
      type: MessageType.assistant,
      status: MessageStatus.processing,
    );

    final updatedConversation = currentConversation.copyWith(
      messages: [
        ...currentConversation.messages,
        userMessage,
        processingMessage,
      ],
    );

    // Update state
    final updatedList = List<Conversation>.from(state);
    updatedList[updatedList.length - 1] = updatedConversation;
    state = updatedList;

    // Trigger automation workflow
    _triggerAutomation(currentConversation.id, content, provider ?? currentConversation.provider);
  }

  void updateMessage(String conversationId, String messageId, String content, MessageStatus status) {
    final conversationIndex = state.indexWhere((conv) => conv.id == conversationId);
    if (conversationIndex == -1) return;

    final conversation = state[conversationIndex];
    final messageIndex = conversation.messages.indexWhere((msg) => msg.id == messageId);
    if (messageIndex == -1) return;

    final updatedMessage = conversation.messages[messageIndex].copyWith(
      content: content,
      status: status,
    );

    final updatedMessages = List<ChatMessage>.from(conversation.messages);
    updatedMessages[messageIndex] = updatedMessage;

    final updatedConversation = conversation.copyWith(messages: updatedMessages);

    final updatedList = List<Conversation>.from(state);
    updatedList[conversationIndex] = updatedConversation;
    state = updatedList;
  }

  void addResponse(String conversationId, String content) {
    final conversationIndex = state.indexWhere((conv) => conv.id == conversationId);
    if (conversationIndex == -1) return;

    final conversation = state[conversationIndex];

    // Remove processing message if exists
    final messagesWithoutProcessing = conversation.messages
        .where((msg) => msg.status != MessageStatus.processing)
        .toList();

    // Add assistant response
    final assistantMessage = ChatMessage(
      content: content,
      type: MessageType.assistant,
      status: MessageStatus.completed,
    );

    final updatedConversation = conversation.copyWith(
      messages: [...messagesWithoutProcessing, assistantMessage],
    );

    final updatedList = List<Conversation>.from(state);
    updatedList[conversationIndex] = updatedConversation;
    state = updatedList;
  }

  void clearCurrentConversation() {
    if (state.isNotEmpty) {
      state = state.take(state.length - 1).toList();
      if (state.isEmpty) {
        initializeIfNeeded();
      }
    }
  }

  void deleteConversation(String conversationId) {
    state = state.where((conv) => conv.id != conversationId).toList();
    if (state.isEmpty) {
      initializeIfNeeded();
    }
  }

  // Trigger automation workflow
  void _triggerAutomation(String conversationId, String content, AIProvider provider) {
    // Update automation state
    ref.read(automationProvider.notifier).startAutomation(
      provider: provider,
      prompt: content,
    );

    // Get the JavaScript bridge for the selected provider
    final bridge = ref.read(javascriptBridgeProvider(provider));
    if (bridge == null) {
      _updateMessageWithError(conversationId, 'Provider non initialisé. Veuillez vous connecter au provider.');
      ref.read(automationProvider.notifier).completeAutomation();
      return;
    }

    // Check if WebView is ready
    final isReady = ref.read(webviewReadyProvider(provider));
    if (!isReady) {
      _updateMessageWithError(conversationId, 'WebView non prêt. Veuillez actualiser la page du provider.');
      ref.read(automationProvider.notifier).completeAutomation();
      return;
    }

    // Start real automation with the JavaScript bridge
    _startRealAutomation(conversationId, content, provider, bridge);
  }

  // Start real automation with JavaScript bridge
  void _startRealAutomation(String conversationId, String content, AIProvider provider, JavaScriptBridge bridge) {
    // Format the prompt for the specific provider
    final formattedPrompt = PromptFormatter.formatForProvider(
      prompt: content,
      provider: provider,
      options: {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'conversationId': conversationId,
      },
    );

    // Update message to show sending phase
    _updateProcessingMessage(conversationId, 'Envoi au provider...');

    // Start automation via JavaScript bridge
    bridge.startAutomation(
      formattedPrompt,
      {
        'provider': provider.name,
        'conversationId': conversationId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    ).then((_) {
      // Automation started successfully
      _updateProcessingMessage(conversationId, 'Automatisation démarrée...');
      ref.read(automationProvider.notifier).onGenerationStarted();
    }).catchError((error) {
      _updateMessageWithError(conversationId, 'Erreur lors de l\'automatisation: $error');
      ref.read(automationProvider.notifier).completeAutomation();
    });
  }

  // Update processing message content
  void _updateProcessingMessage(String conversationId, String content) {
    final conversation = state.firstWhere((conv) => conv.id == conversationId);
    final processingMessage = conversation.messages.firstWhere(
      (msg) => msg.status == MessageStatus.processing,
      orElse: () => conversation.messages.last, // Fallback to last message
    );

    updateMessage(conversationId, processingMessage.id, content, MessageStatus.processing);
  }

  // Update message with error status
  void _updateMessageWithError(String conversationId, String error) {
    final conversation = state.firstWhere((conv) => conv.id == conversationId);
    final processingMessage = conversation.messages.firstWhere(
      (msg) => msg.status == MessageStatus.processing,
      orElse: () => conversation.messages.last, // Fallback to last message
    );

    updateMessage(conversationId, processingMessage.id, error, MessageStatus.error);
  }

  // Handle automation completion from bridge callback
  void handleAutomationComplete(String conversationId, String response) {
    if (response.isNotEmpty) {
      addResponse(conversationId, response);
    } else {
      _updateMessageWithError(conversationId, 'Réponse vide reçue du provider');
    }
    ref.read(automationProvider.notifier).completeAutomation();
  }

  // Handle automation error from bridge callback
  void handleAutomationError(String conversationId, String error) {
    _updateMessageWithError(conversationId, 'Erreur d\'automatisation: $error');
    ref.read(automationProvider.notifier).completeAutomation();
  }
}

// Providers
final conversationProvider = StateNotifierProvider<ConversationNotifier, List<Conversation>>(
  (ref) => ConversationNotifier(ref),
);

final currentConversationProvider = Provider<Conversation?>(
  (ref) {
    final conversations = ref.watch(conversationProvider);
    return conversations.isNotEmpty ? conversations.last : null;
  },
);