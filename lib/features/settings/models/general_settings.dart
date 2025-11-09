import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

part 'general_settings.freezed.dart';
part 'general_settings.g.dart';

// WHY: We use a manual adapter, so @HiveType/@HiveField annotations are not needed.
@freezed
sealed class GeneralSettingsData with _$GeneralSettingsData {
  const factory GeneralSettingsData({
    @Default(['ai_studio']) List<String> enabledProviders,
    // WHY: Add a flag for the new prompt engineering mode. Default to true to
    // encourage the more robust XML-based method while retaining a fallback.
    @Default(true) bool useAdvancedPrompting,
    // WHY: Allows users to customize the instruction that frames the conversation history.
    @Default(
      'Here is the previous conversation history for your context. Consider these your own past messages:',
    )
    String historyContextInstruction,
    // WHY: Controls whether the app automatically extracts the response
    // after the AI is finished generating. Defaults to true for a faster workflow.
    @Default(true) bool yoloModeEnabled,
    // WHY: User-configurable multiplier for all TypeScript automation timeouts.
    // Allows users to increase timeouts on slower devices or networks.
    @Default(1.0) double timeoutModifier,
    // WHY: Controls whether the app restores the last active conversation on app restart.
    // Defaults to false to give users control over session persistence.
    @Default(false) bool persistSessionOnRestart,
    // WHY: Limits the number of conversations kept in history to prevent database bloat.
    // Defaults to 10 conversations, which balances usability with storage efficiency.
    @Default(10) int maxConversationHistory,
    // WHY: Allows advanced users to override the WebView's default User Agent.
    // If empty, the platform-specific default UA from flutter_inappwebview is used.
    @Default('') String customUserAgent,
  }) = _GeneralSettingsData;

  factory GeneralSettingsData.fromJson(Map<String, dynamic> json) =>
      _$GeneralSettingsDataFromJson(json);
}

// WHY: Manual TypeAdapter implementation since hive_generator conflicts with
// riverpod_generator. We use the existing JSON serialization for compatibility.
class GeneralSettingsDataAdapter extends TypeAdapter<GeneralSettingsData> {
  @override
  final int typeId = 0;

  @override
  GeneralSettingsData read(BinaryReader reader) {
    final jsonString = reader.readString();
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return GeneralSettingsData.fromJson(json);
  }

  @override
  void write(BinaryWriter writer, GeneralSettingsData obj) {
    final json = obj.toJson();
    final jsonString = jsonEncode(json);
    writer.writeString(jsonString);
  }
}
