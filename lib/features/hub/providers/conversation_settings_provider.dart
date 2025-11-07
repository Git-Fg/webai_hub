import 'package:ai_hybrid_hub/features/hub/models/conversation_settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'conversation_settings_provider.g.dart';

@riverpod
class ConversationSettingsNotifier extends _$ConversationSettingsNotifier {
  @override
  ConversationSettings build() {
    // WHY: Returns a default state. This provider is autoDisposed, so it will
    // be created fresh for each new conversation session.
    return const ConversationSettings();
  }

  void updateSystemPrompt(String prompt) {
    state = state.copyWith(systemPrompt: prompt);
  }

  void updateTemperature(double temp) {
    state = state.copyWith(temperature: temp);
  }

  void updateModel(String? model) {
    // Use default if null is passed
    state = state.copyWith(model: model ?? 'Gemini 2.5 Pro');
  }

  void updateTopP(double topP) {
    state = state.copyWith(topP: topP);
  }

  void updateThinkingBudget(int? budget) {
    state = state.copyWith(thinkingBudget: budget);
  }

  void toggleDisableThinking({required bool value}) {
    state = state.copyWith(disableThinking: value);
  }

  void toggleUseWebSearch({required bool value}) {
    state = state.copyWith(useWebSearch: value);
  }

  void toggleUrlContext({required bool value}) {
    state = state.copyWith(urlContext: value);
  }
}
