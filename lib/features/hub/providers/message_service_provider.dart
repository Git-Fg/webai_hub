import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/core/database/database_provider.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
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
}
