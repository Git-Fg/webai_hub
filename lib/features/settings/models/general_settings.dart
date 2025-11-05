import 'package:freezed_annotation/freezed_annotation.dart';

part 'general_settings.freezed.dart';
part 'general_settings.g.dart';

@freezed
abstract class GeneralSettingsData with _$GeneralSettingsData {
  const factory GeneralSettingsData({
    @Default(['ai_studio']) List<String> enabledProviders,
    // Future settings can be added here, e.g., theme settings
  }) = _GeneralSettingsData;

  factory GeneralSettingsData.fromJson(Map<String, dynamic> json) =>
      _$GeneralSettingsDataFromJson(json);
}
