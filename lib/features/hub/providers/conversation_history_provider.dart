// lib/features/hub/providers/conversation_history_provider.dart

import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/core/database/database_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'conversation_history_provider.g.dart';

// WHY: This provider streams all conversations for display in the history drawer.
// It provides a reactive list that updates automatically when conversations are created or deleted.
// NOTE: Using explicit return type annotation causes issues with riverpod code generation
// because ConversationData is in a generated part file. The type is inferred from watchAllConversations().
@riverpod
Stream conversationHistory(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchAllConversations();
}
