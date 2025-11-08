import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

part 'general_settings.freezed.dart';
part 'general_settings.g.dart';

// WHY: We use a manual adapter, so @HiveType/@HiveField annotations are not needed.
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
    // WHY: Controls whether the app automatically extracts the response
    // after the AI is finished generating. Defaults to true for a faster workflow.
    @Default(true) bool yoloModeEnabled,
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
