import 'package:freezed_annotation/freezed_annotation.dart';

part 'preset_settings.freezed.dart';
part 'preset_settings.g.dart';

@freezed
sealed class PresetSettings with _$PresetSettings {
  const factory PresetSettings({
    String? model,
    double? temperature,
    double? topP,
    // WHY: Prompt affixes allow users to frame their input with prefix/suffix text,
    // enabling powerful prompt engineering techniques like role-playing or formatting instructions.
    String? promptPrefix,
    String? promptSuffix,
    bool? useWebSearch,
    bool? disableThinking,
  }) = _PresetSettings;

  factory PresetSettings.fromJson(Map<String, dynamic> json) =>
      _$PresetSettingsFromJson(json);
}
