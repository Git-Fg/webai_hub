import 'package:freezed_annotation/freezed_annotation.dart';

part 'general_settings.freezed.dart';
part 'general_settings.g.dart';

@freezed
abstract class GeneralSettingsData with _$GeneralSettingsData {
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
  }) = _GeneralSettingsData;

  factory GeneralSettingsData.fromJson(Map<String, dynamic> json) =>
      _$GeneralSettingsDataFromJson(json);
}
