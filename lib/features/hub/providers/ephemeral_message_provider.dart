import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ephemeral_message_provider.g.dart';

// WHY: This provider holds a single, temporary message to be displayed in the
// UI without polluting the permanent conversation history. It's used for
// feedback like extraction errors.
@riverpod
class EphemeralMessage extends _$EphemeralMessage {
  @override
  Message? build() => null;

  void setMessage(String text, {MessageStatus status = MessageStatus.error}) {
    state = Message(
      id: 'ephemeral_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      isFromUser: false,
      status: status,
    );
  }

  void clearMessage() {
    state = null;
  }
}
