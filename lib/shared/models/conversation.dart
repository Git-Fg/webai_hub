import 'package:uuid/uuid.dart';
import 'ai_provider.dart';

enum MessageType {
  user,
  assistant,
  system,
}

enum MessageStatus {
  sending,
  sent,
  processing,
  completed,
  error,
}

class Conversation {
  final String id;
  final AIProvider provider;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    required this.provider,
    required this.messages,
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Conversation copyWith({
    AIProvider? provider,
    List<ChatMessage>? messages,
    DateTime? updatedAt,
  }) {
    return Conversation(
      id: id,
      provider: provider ?? this.provider,
      messages: messages ?? this.messages,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'provider': provider.name,
      'messages': messages.map((m) => m.toMap()).toList(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'],
      provider: AIProvider.values.firstWhere((p) => p.name == map['provider']),
      messages: List<ChatMessage>.from(
        map['messages'].map((m) => ChatMessage.fromMap(m)),
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt']),
    );
  }
}

class ChatMessage {
  final String id;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final MessageStatus status;

  ChatMessage({
    required this.content,
    required this.type,
    this.status = MessageStatus.sent,
    String? id,
    DateTime? timestamp,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    String? content,
    MessageType? type,
    MessageStatus? status,
    DateTime? timestamp,
  }) {
    return ChatMessage(
      id: id,
      content: content ?? this.content,
      type: type ?? this.type,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'type': type.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'status': status.name,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      content: map['content'],
      type: MessageType.values.firstWhere((t) => t.name == map['type']),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      status: MessageStatus.values.firstWhere((s) => s.name == map['status']),
    );
  }
}