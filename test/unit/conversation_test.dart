import 'package:flutter_test/flutter_test.dart';
import 'package:multi_webview_tab_manager/shared/models/conversation.dart';
import 'package:multi_webview_tab_manager/shared/models/ai_provider.dart';

void main() {
  group('Conversation Tests', () {
    test('Conversation creates with default values', () {
      final conversation = Conversation(
        provider: AIProvider.aistudio,
        messages: [],
      );

      expect(conversation.provider, AIProvider.aistudio);
      expect(conversation.messages, isEmpty);
      expect(conversation.id, isNotNull);
      expect(conversation.createdAt, isNotNull);
      expect(conversation.updatedAt, isNotNull);
    });

    test('Conversation copyWith works correctly', () {
      final original = Conversation(
        provider: AIProvider.qwen,
        messages: [],
      );

      final newMessage = ChatMessage(
        content: 'Hello',
        type: MessageType.user,
      );

      final updated = original.copyWith(
        messages: [newMessage],
        provider: AIProvider.kimi,
      );

      expect(updated.provider, AIProvider.kimi);
      expect(updated.messages.length, 1);
      expect(updated.messages.first.content, 'Hello');
      expect(updated.id, original.id); // ID should remain the same
    });

    test('ChatMessage creates correctly', () {
      final message = ChatMessage(
        content: 'Test message',
        type: MessageType.assistant,
        status: MessageStatus.completed,
      );

      expect(message.content, 'Test message');
      expect(message.type, MessageType.assistant);
      expect(message.status, MessageStatus.completed);
      expect(message.id, isNotNull);
      expect(message.timestamp, isNotNull);
    });

    test('ChatMessage copyWith works correctly', () {
      final original = ChatMessage(
        content: 'Original',
        type: MessageType.user,
        status: MessageStatus.sending,
      );

      final updated = original.copyWith(
        content: 'Updated',
        status: MessageStatus.sent,
      );

      expect(updated.content, 'Updated');
      expect(updated.status, MessageStatus.sent);
      expect(updated.type, MessageType.user); // Should remain unchanged
      expect(updated.id, original.id); // ID should remain the same
    });

    test('Conversation toMap and fromMap works', () {
      final message1 = ChatMessage(
        content: 'User message',
        type: MessageType.user,
      );

      final message2 = ChatMessage(
        content: 'Assistant response',
        type: MessageType.assistant,
        status: MessageStatus.completed,
      );

      final original = Conversation(
        provider: AIProvider.zai,
        messages: [message1, message2],
      );

      final map = original.toMap();
      final restored = Conversation.fromMap(map);

      expect(restored.provider, original.provider);
      expect(restored.messages.length, original.messages.length);
      expect(restored.messages[0].content, original.messages[0].content);
      expect(restored.messages[1].content, original.messages[1].content);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('ChatMessage toMap and fromMap works', () {
      final original = ChatMessage(
        content: 'Test content',
        type: MessageType.assistant,
        status: MessageStatus.processing,
      );

      final map = original.toMap();
      final restored = ChatMessage.fromMap(map);

      expect(restored.content, original.content);
      expect(restored.type, original.type);
      expect(restored.status, original.status);
      expect(restored.timestamp, original.timestamp);
    });
  });
}