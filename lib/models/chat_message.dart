import 'package:isar/isar.dart';

part 'chat_message.g.dart';

/// Represents a chat message in the Hub's native chat history
@collection
class ChatMessage {
  Id id = Isar.autoIncrement;

  /// Unique message ID for the UI
  @Index()
  late String messageId;

  /// Message text content
  late String text;

  /// Role: 'user' or 'assistant'
  @enumerated
  late MessageRole role;

  /// Provider that handled this message (e.g., 'kimi', 'qwen')
  String? provider;

  /// Timestamp when the message was created
  late DateTime createdAt;

  /// Status of the message
  @enumerated
  late MessageStatus status;

  /// Error message if status is failed
  String? errorMessage;
}

/// Message role enum
enum MessageRole {
  user,
  assistant,
}

/// Message status enum
enum MessageStatus {
  sending,
  sent,
  completed,
  failed,
  cancelled,
}
