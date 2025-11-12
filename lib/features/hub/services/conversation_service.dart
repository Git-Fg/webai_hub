import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/core/database/database_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'conversation_service.g.dart';

@Riverpod(keepAlive: true)
class ConversationService extends _$ConversationService {
  @override
  void build() {} // No state needed

  AppDatabase get _db => ref.read(appDatabaseProvider);

  Future<int> createConversation(String title) async {
    final entry = ConversationsCompanion.insert(
      title: title,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return _db.createConversation(entry);
  }

  Future<void> deleteConversation(int id) async {
    return _db.deleteConversation(id);
  }

  Future<void> updateSystemPrompt(int id, String? prompt) async {
    return _db.updateConversationSystemPrompt(id, prompt);
  }

  Future<void> updateTimestamp(int id) async {
    return _db.updateConversationTimestamp(id, DateTime.now());
  }
}
