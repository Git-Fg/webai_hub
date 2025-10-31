import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/chat_message.dart';

/// Service to manage Isar database for Hub chat history
class DatabaseService {
  static Isar? _isar;
  
  /// Initialize the Isar database
  static Future<Isar> initialize() async {
    if (_isar != null && _isar!.isOpen) {
      return _isar!;
    }
    
    final dir = await getApplicationDocumentsDirectory();
    
    _isar = await Isar.open(
      [ChatMessageSchema],
      directory: dir.path,
    );
    
    return _isar!;
  }
  
  /// Get the Isar instance
  static Isar get instance {
    if (_isar == null || !_isar!.isOpen) {
      throw Exception('Database not initialized. Call initialize() first.');
    }
    return _isar!;
  }
  
  /// Add a new message to the database
  static Future<void> addMessage(ChatMessage message) async {
    final isar = instance;
    await isar.writeTxn(() async {
      await isar.chatMessages.put(message);
    });
  }
  
  /// Update an existing message
  static Future<void> updateMessage(ChatMessage message) async {
    final isar = instance;
    await isar.writeTxn(() async {
      await isar.chatMessages.put(message);
    });
  }
  
  /// Get all messages ordered by creation time
  static Future<List<ChatMessage>> getAllMessages() async {
    final isar = instance;
    return await isar.chatMessages
        .where()
        .sortByCreatedAt()
        .findAll();
  }
  
  /// Get a message by its message ID
  static Future<ChatMessage?> getMessageByMessageId(String messageId) async {
    final isar = instance;
    return await isar.chatMessages
        .filter()
        .messageIdEqualTo(messageId)
        .findFirst();
  }
  
  /// Delete all messages
  static Future<void> clearAllMessages() async {
    final isar = instance;
    await isar.writeTxn(() async {
      await isar.chatMessages.clear();
    });
  }
  
  /// Stream of all messages
  static Stream<List<ChatMessage>> watchAllMessages() {
    final isar = instance;
    return isar.chatMessages
        .where()
        .sortByCreatedAt()
        .watch(fireImmediately: true);
  }
}
