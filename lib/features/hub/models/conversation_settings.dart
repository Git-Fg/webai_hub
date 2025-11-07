import 'package:freezed_annotation/freezed_annotation.dart';

part 'conversation_settings.freezed.dart';

@freezed
abstract class ConversationSettings with _$ConversationSettings {
  const factory ConversationSettings({
    @Default('') String systemPrompt,
    @Default(0.8) double temperature,
    @Default('Gemini 2.5 Flash') String model,
    @Default(0.95) double topP,
    int? thinkingBudget,
    @Default(false) bool disableThinking,
    @Default(false) bool useWebSearch,
    @Default(false) bool urlContext,
  }) = _ConversationSettings;
}
