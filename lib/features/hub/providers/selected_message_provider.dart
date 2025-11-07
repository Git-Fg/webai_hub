import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'selected_message_provider.g.dart';

// WHY: This provider holds the ID of the currently tapped message.
// This allows all chat bubbles to know which one is "active" and should
// display the action hub (edit/copy buttons). It is pure UI state.
@riverpod
class SelectedMessageId extends _$SelectedMessageId {
  @override
  String? build() => null;

  void select(String? messageId) {
    // If the same message is tapped again, deselect it.
    if (state == messageId) {
      state = null;
    } else {
      state = messageId;
    }
  }

  void clear() {
    state = null;
  }
}
