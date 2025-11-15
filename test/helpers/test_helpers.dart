import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:ai_hybrid_hub/features/hub/models/staged_response.dart';
import 'package:ai_hybrid_hub/features/presets/models/preset_settings.dart';
import 'package:ai_hybrid_hub/features/settings/models/general_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Helper to allow providers to settle
extension PumpExtension on ProviderContainer {
  Future<void> pump() => Future<void>.delayed(Duration.zero);
}

// Helper to create test messages
Message createTestMessage({
  required String id,
  required String text,
  required bool isFromUser,
  MessageStatus status = MessageStatus.success,
}) {
  return Message(
    id: id,
    text: text,
    isFromUser: isFromUser,
    status: status,
  );
}

// Helper to create test preset data
PresetData createTestPreset({
  required int id,
  required String name,
  String? providerId,
  PresetSettings? settings,
  int displayOrder = 1,
}) {
  return PresetData(
    id: id,
    name: name,
    providerId: providerId,
    settings: settings ?? const PresetSettings(model: 'test-model'),
    displayOrder: displayOrder,
    isPinned: false,
    isCollapsed: false,
  );
}

// Helper to create test preset settings
PresetSettings createTestPresetSettings({
  String? promptPrefix,
  String? promptSuffix,
  String? model,
  double? temperature,
  bool? useWebSearch,
}) {
  return PresetSettings(
    promptPrefix: promptPrefix,
    promptSuffix: promptSuffix,
    model: model ?? 'test-model',
    temperature: temperature ?? 0.7,
    useWebSearch: useWebSearch ?? false,
  );
}

// Helper to create test staged response
StagedResponse createTestStagedResponse({
  required int presetId,
  required String presetName,
  required String text,
  bool isLoading = false,
}) {
  return StagedResponse(
    presetId: presetId,
    presetName: presetName,
    text: text,
    isLoading: isLoading,
  );
}

// Helper to create test general settings
GeneralSettingsData createTestGeneralSettings({
  bool useAdvancedPrompting = false,
  bool yoloModeEnabled = false,
  String historyContextInstruction = 'Here is the conversation history:',
  double timeoutModifier = 1.0,
  bool persistSessionOnRestart = true,
  int maxConversationHistory = 50,
  String selectedUserAgent = 'default',
  String customUserAgent = '',
  bool webViewSupportZoom = true,
}) {
  return GeneralSettingsData(
    useAdvancedPrompting: useAdvancedPrompting,
    yoloModeEnabled: yoloModeEnabled,
    historyContextInstruction: historyContextInstruction,
    timeoutModifier: timeoutModifier,
    persistSessionOnRestart: persistSessionOnRestart,
    maxConversationHistory: maxConversationHistory,
    selectedUserAgent: selectedUserAgent,
    customUserAgent: customUserAgent,
    webViewSupportZoom: webViewSupportZoom,
  );
}
