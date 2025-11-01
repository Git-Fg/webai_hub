import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multi_webview_tab_manager/shared/models/ai_provider.dart';
import 'package:multi_webview_tab_manager/shared/models/conversation.dart';
import 'package:multi_webview_tab_manager/features/hub/providers/conversation_provider.dart';

void main() {
  group('ConversationProvider Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initializeIfNeeded creates default conversation when empty', () {
      final notifier = container.read(conversationProvider.notifier);
      final initialState = container.read(conversationProvider);

      expect(initialState, isEmpty);

      notifier.initializeIfNeeded();
      final state = container.read(conversationProvider);

      expect(state, isNotEmpty);
      expect(state.length, 1);
      expect(state.first.provider, AIProvider.aistudio);
      expect(state.first.messages, isEmpty);
    });

    test('initializeIfNeeded does nothing when conversations exist', () {
      final notifier = container.read(conversationProvider.notifier);
      
      // Create initial conversation
      notifier.startNewConversation(AIProvider.qwen);
      final beforeCount = container.read(conversationProvider).length;

      // Try to initialize again
      notifier.initializeIfNeeded();
      final afterCount = container.read(conversationProvider).length;

      expect(afterCount, equals(beforeCount));
    });

    test('startNewConversation creates new conversation with default provider', () {
      final notifier = container.read(conversationProvider.notifier);
      
      notifier.startNewConversation();
      final state = container.read(conversationProvider);

      expect(state.length, 1);
      expect(state.first.provider, AIProvider.aistudio);
    });

    test('startNewConversation creates new conversation with specified provider', () {
      final notifier = container.read(conversationProvider.notifier);
      
      notifier.startNewConversation(AIProvider.kimi);
      final state = container.read(conversationProvider);

      expect(state.length, 1);
      expect(state.first.provider, AIProvider.kimi);
    });

    test('sendMessage creates conversation if empty', () {
      final notifier = container.read(conversationProvider.notifier);
      
      notifier.sendMessage('Test message');
      final state = container.read(conversationProvider);

      expect(state, isNotEmpty);
      expect(state.first.messages.length, 2); // User message + processing message
      expect(state.first.messages[0].content, 'Test message');
      expect(state.first.messages[0].type, MessageType.user);
      expect(state.first.messages[0].status, MessageStatus.sent);
      expect(state.first.messages[1].status, MessageStatus.processing);
    });

    test('sendMessage adds to existing conversation', () {
      final notifier = container.read(conversationProvider.notifier);
      
      notifier.startNewConversation();
      notifier.sendMessage('First message');
      
      final state1 = container.read(conversationProvider);
      expect(state1.first.messages.length, 2);

      notifier.sendMessage('Second message');
      final state2 = container.read(conversationProvider);

      expect(state2.length, 1); // Still one conversation
      expect(state2.first.messages.length, 4); // 2 messages * 2 (user + processing)
    });

    test('sendMessage uses specified provider when provided', () {
      final notifier = container.read(conversationProvider.notifier);
      
      notifier.sendMessage('Test', provider: AIProvider.qwen);
      final state = container.read(conversationProvider);

      expect(state.first.provider, AIProvider.qwen);
    });

    test('updateMessage updates existing message', () {
      final notifier = container.read(conversationProvider.notifier);
      
      notifier.sendMessage('Test message');
      final conversation = container.read(conversationProvider).first;
      final messageId = conversation.messages.firstWhere(
        (m) => m.status == MessageStatus.processing,
      ).id;

      notifier.updateMessage(
        conversation.id,
        messageId,
        'Updated content',
        MessageStatus.completed,
      );

      final updatedState = container.read(conversationProvider);
      final updatedMessage = updatedState.first.messages.firstWhere(
        (m) => m.id == messageId,
      );

      expect(updatedMessage.content, 'Updated content');
      expect(updatedMessage.status, MessageStatus.completed);
    });

    test('updateMessage does nothing if conversation not found', () {
      final notifier = container.read(conversationProvider.notifier);
      
      notifier.sendMessage('Test');
      final beforeState = container.read(conversationProvider);

      notifier.updateMessage(
        'non-existent-id',
        'message-id',
        'Content',
        MessageStatus.completed,
      );

      final afterState = container.read(conversationProvider);
      expect(afterState, equals(beforeState));
    });

    test('updateMessage does nothing if message not found', () {
      final notifier = container.read(conversationProvider.notifier);
      
      notifier.sendMessage('Test');
      final conversation = container.read(conversationProvider).first;
      final beforeMessages = conversation.messages.length;

      notifier.updateMessage(
        conversation.id,
        'non-existent-message-id',
        'Content',
        MessageStatus.completed,
      );

      final afterState = container.read(conversationProvider);
      expect(afterState.first.messages.length, equals(beforeMessages));
    });

    test('addResponse removes processing message and adds response', () {
      final notifier = container.read(conversationProvider.notifier);
      
      notifier.sendMessage('Test');
      final conversation = container.read(conversationProvider).first;
      final processingMessagesBefore = conversation.messages.where(
        (m) => m.status == MessageStatus.processing,
      ).length;

      expect(processingMessagesBefore, 1);

      notifier.addResponse(conversation.id, 'AI Response');

      final updatedState = container.read(conversationProvider);
      final processingMessagesAfter = updatedState.first.messages.where(
        (m) => m.status == MessageStatus.processing,
      ).length;
      final completedMessages = updatedState.first.messages.where(
        (m) => m.status == MessageStatus.completed && m.type == MessageType.assistant,
      );

      expect(processingMessagesAfter, 0);
      expect(completedMessages.length, 1);
      expect(completedMessages.first.content, 'AI Response');
    });

    test('addResponse does nothing if conversation not found', () {
      final notifier = container.read(conversationProvider.notifier);
      
      notifier.sendMessage('Test');
      final beforeState = container.read(conversationProvider);

      notifier.addResponse('non-existent-id', 'Response');

      final afterState = container.read(conversationProvider);
      expect(afterState, equals(beforeState));
    });

    test('clearCurrentConversation removes last conversation', () {
      final notifier = container.read(conversationProvider.notifier);
      
      notifier.startNewConversation(AIProvider.aistudio);
      notifier.startNewConversation(AIProvider.qwen);
      
      expect(container.read(conversationProvider).length, 2);

      notifier.clearCurrentConversation();
      final state = container.read(conversationProvider);

      expect(state.length, 1);
      expect(state.first.provider, AIProvider.aistudio);
    });

    test('clearCurrentConversation reinitializes if all cleared', () {
      final notifier = container.read(conversationProvider.notifier);
      
      notifier.startNewConversation();
      notifier.clearCurrentConversation();

      final state = container.read(conversationProvider);
      expect(state, isNotEmpty); // Should reinitialize
    });

    test('deleteConversation removes specific conversation', () {
      final notifier = container.read(conversationProvider.notifier);
      
      notifier.startNewConversation(AIProvider.aistudio);
      notifier.startNewConversation(AIProvider.qwen);
      
      final conversations = container.read(conversationProvider);
      final firstId = conversations.first.id;

      notifier.deleteConversation(firstId);

      final afterState = container.read(conversationProvider);
      expect(afterState.length, 1);
      expect(afterState.first.provider, AIProvider.qwen);
    });

    test('deleteConversation reinitializes if all deleted', () {
      final notifier = container.read(conversationProvider.notifier);
      
      notifier.startNewConversation();
      final conversation = container.read(conversationProvider).first;
      
      notifier.deleteConversation(conversation.id);

      final state = container.read(conversationProvider);
      expect(state, isNotEmpty); // Should reinitialize
    });

    test('currentConversationProvider returns last conversation', () {
      final notifier = container.read(conversationProvider.notifier);
      
      notifier.startNewConversation(AIProvider.aistudio);
      notifier.startNewConversation(AIProvider.qwen);

      final current = container.read(currentConversationProvider);

      expect(current, isNotNull);
      expect(current!.provider, AIProvider.qwen);
    });

    test('currentConversationProvider returns null when empty', () {
      final current = container.read(currentConversationProvider);
      expect(current, isNull);
    });
  });
}

