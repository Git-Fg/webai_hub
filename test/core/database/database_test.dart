// test/core/database/database_test.dart

import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    // WHY: NativeDatabase.memory() creates a temporary, in-memory database
    // that is perfect for fast and isolated unit tests.
    database = AppDatabase.test();
  });

  tearDown(() async {
    // WHY: Always close the database connection after each test to prevent leaks.
    // AppDatabase extends GeneratedDatabase which has close() method
    await (database as dynamic).close();
  });

  test('Database can insert and read a message', () async {
    // ARRANGE
    const message = Message(
      id: '1',
      text: 'Hello, Drift!',
      isFromUser: true,
    );

    // Create a conversation first
    final conversationId = await database.createConversation(
      ConversationsCompanion.insert(
        title: 'Test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    // ACT
    await database.insertMessage(message, conversationId);
    final messagesStream = database.watchMessagesForConversation(
      conversationId,
    );

    // ASSERT
    // We expect the stream to emit MessageData, which we then map to Message for comparison
    await expectLater(
      messagesStream,
      emits(
        predicate<List<MessageData>>(
          (list) {
            if (list.length != 1) return false;
            final data = list[0];
            return data.id == message.id &&
                data.content == message.text &&
                data.isFromUser == message.isFromUser &&
                data.status == message.status;
          },
        ),
      ),
    );
  });

  test('Database can update a message', () async {
    // ARRANGE
    const originalMessage = Message(
      id: '1',
      text: 'Original',
      isFromUser: true,
    );
    final conversationId = await database.createConversation(
      ConversationsCompanion.insert(
        title: 'Test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await database.insertMessage(originalMessage, conversationId);

    // ACT
    final updatedMessage = originalMessage.copyWith(text: 'Updated');
    await database.updateMessage(updatedMessage);
    final messagesStream = database.watchMessagesForConversation(
      conversationId,
    );

    // ASSERT
    // We expect the stream to emit MessageData, which we then verify matches the updated message
    await expectLater(
      messagesStream,
      emits(
        predicate<List<MessageData>>(
          (list) {
            if (list.length != 1) return false;
            final data = list[0];
            return data.id == updatedMessage.id &&
                data.content == updatedMessage.text &&
                data.isFromUser == updatedMessage.isFromUser &&
                data.status == updatedMessage.status;
          },
        ),
      ),
    );
  });

  test('Database can clear all messages', () async {
    // ARRANGE
    final conversationId = await database.createConversation(
      ConversationsCompanion.insert(
        title: 'Test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await database.insertMessage(
      const Message(id: '1', text: 'Test', isFromUser: true),
      conversationId,
    );

    // ACT
    await database.clearAllMessages();
    final messagesStream = database.watchMessagesForConversation(
      conversationId,
    );

    // ASSERT
    // We expect the stream to emit an empty list after clearing.
    await expectLater(messagesStream, emits([]));
  });
}
