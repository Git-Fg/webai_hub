import 'package:freezed_annotation/freezed_annotation.dart';

part 'conversation_settings.freezed.dart';

@freezed
abstract class ConversationSettings with _$ConversationSettings {
  const factory ConversationSettings({
    @Default('') String systemPrompt,
    @Default(0.7) double temperature,
  }) = _ConversationSettings;
}
