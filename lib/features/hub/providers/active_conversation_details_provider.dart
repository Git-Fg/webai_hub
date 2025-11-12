// lib/features/hub/providers/active_conversation_details_provider.dart

import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/core/database/database_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/active_conversation_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'active_conversation_details_provider.g.dart';

// WHY: This provider streams the full conversation details including system prompt,
// enabling the UI to display and edit conversation-level settings.
@riverpod
Stream<ConversationData?> activeConversationDetails(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final activeId = ref.watch(activeConversationIdProvider);

  if (activeId == null) {
    return Stream.value(null);
  }

  return (db.select(db.conversations)..where((c) => c.id.equals(activeId)))
      .watchSingleOrNull();
}


