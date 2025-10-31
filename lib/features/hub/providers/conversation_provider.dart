import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/models/ai_provider.dart';
import '../../automation/providers/automation_provider.dart';
import '../../webview/providers/webview_provider.dart';

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

    // In a real implementation, this would trigger the actual automation
    // For now, we simulate the workflow
    _simulateAutomationWorkflow(conversationId);
  }

  // Simulate automation workflow (placeholder)
  void _simulateAutomationWorkflow(String conversationId) {
    // Simulate Phase 1: Sending
    Future.delayed(const Duration(seconds: 1), () {
      updateMessage(
        conversationId,
        state.firstWhere((conv) => conv.id == conversationId)
            .messages
            .firstWhere((msg) => msg.status == MessageStatus.processing)
            .id,
        'Envoi au provider...',
        MessageStatus.processing,
      );

      ref.read(automationProvider.notifier).onGenerationStarted();
    });

    // Simulate Phase 2: Generation
    Future.delayed(const Duration(seconds: 3), () {
      updateMessage(
        conversationId,
        state.firstWhere((conv) => conv.id == conversationId)
            .messages
            .firstWhere((msg) => msg.status == MessageStatus.processing)
            .id,
        'Génération en cours...',
        MessageStatus.processing,
      );

      ref.read(automationProvider.notifier).onGenerationCompleted();
    });

    // Simulate Phase 4: Extraction
    Future.delayed(const Duration(seconds: 5), () {
      updateMessage(
        conversationId,
        state.firstWhere((conv) => conv.id == conversationId)
            .messages
            .firstWhere((msg) => msg.status == MessageStatus.processing)
            .id,
        'Ceci est une réponse simulée du workflow d\'automatisation. Dans l\'implémentation réelle, ceci serait la réponse extraite du provider IA.',
        MessageStatus.completed,
      );

      ref.read(automationProvider.notifier).completeAutomation();
    });
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