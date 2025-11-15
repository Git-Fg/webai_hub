import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/core/database/database_provider.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'message_service_provider.g.dart';

@Riverpod(keepAlive: true)
class MessageService extends _$MessageService {
  @override
  void build() {} // No state needed

  AppDatabase get _db => ref.read(appDatabaseProvider);

  Future<void> addMessage(Message message, int conversationId) async {
    await _db.insertMessage(message, conversationId);
    await _db.updateConversationTimestamp(conversationId, DateTime.now());
  }

  Future<void> updateMessage(Message message) async {
    await _db.updateMessage(message);
    // Note: We might not need to update the timestamp on every message edit.
  }

  /// Gets a message by its ID within a specific conversation.
  /// WHY: This encapsulates message querying logic that was previously in ConversationActions.
  Future<Message?> getMessageById(String messageId, int conversationId) async {
    final messages = await (_db.select(
      _db.messages,
    )..where((t) => t.conversationId.equals(conversationId))).get();
    final messageData = messages.firstWhere(
      (m) => m.id == messageId,
      orElse: () => throw StateError('Message not found: $messageId'),
    );
    return Message(
      id: messageData.id,
      text: messageData.content,
      isFromUser: messageData.isFromUser,
      status: messageData.status,
    );
  }

  /// Gets the last assistant message in a conversation.
  /// WHY: This encapsulates the query logic for finding the most recent assistant message.
  Future<Message?> getLastAssistantMessage(int conversationId) async {
    final query = _db.select(_db.messages)
      ..where((t) => t.conversationId.equals(conversationId))
      ..where((t) => t.isFromUser.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(1);

    final messageToUpdate = await query.getSingleOrNull();
    if (messageToUpdate == null) return null;

    return Message(
      id: messageToUpdate.id,
      text: messageToUpdate.content,
      isFromUser: false,
      status: messageToUpdate.status,
    );
  }

  /// Truncates a conversation by deleting all messages after a specific message.
  /// WHY: This encapsulates the business logic for conversation truncation during edit & resend.
  /// The message itself is NOT deleted - only messages that come after it.
  Future<void> truncateConversationFromMessage(
    String messageId,
    int conversationId,
  ) async {
    final messages = await (_db.select(
      _db.messages,
    )..where((t) => t.conversationId.equals(conversationId))).get();
    final messageIndex = messages.indexWhere((msg) => msg.id == messageId);
    if (messageIndex == -1) return;

    // Delete all messages after the edited one (not including the edited message)
    final messagesToDelete = messages.sublist(messageIndex + 1);
    for (final msg in messagesToDelete) {
      await (_db.delete(_db.messages)..where((f) => f.id.equals(msg.id))).go();
    }
  }

  /// Generates a unique message ID based on current timestamp.
  /// WHY: This centralizes message ID generation logic that was scattered across providers.
  String generateMessageId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }
}
