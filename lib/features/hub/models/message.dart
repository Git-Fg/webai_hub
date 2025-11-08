import 'package:freezed_annotation/freezed_annotation.dart';

part 'message.freezed.dart';

@freezed
sealed class Message with _$Message {
  const factory Message({
    required String id,
    required String text,
    required bool isFromUser,
    @Default(MessageStatus.success) MessageStatus status,
  }) = _Message;
}

enum MessageStatus { sending, success, error }
