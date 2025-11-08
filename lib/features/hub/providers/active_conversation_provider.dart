// lib/features/hub/providers/active_conversation_provider.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'active_conversation_provider.g.dart';

// WHY: This simple provider holds the ID of the currently displayed conversation.
// The main ConversationProvider will react to changes in this state.
// It is kept alive to remember the active session across app navigations.
@Riverpod(keepAlive: true)
class ActiveConversationId extends _$ActiveConversationId {
  @override
  int? build() => null; // No conversation is active on startup by default.

  void set(int? id) {
    state = id;
  }
}
