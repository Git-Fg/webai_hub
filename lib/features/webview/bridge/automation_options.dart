// lib/features/webview/bridge/automation_options.dart

import 'package:freezed_annotation/freezed_annotation.dart';

part 'automation_options.freezed.dart';
part 'automation_options.g.dart';

// WHY: Freezed model matching the TypeScript AutomationOptions interface.
// This ensures type safety at compile time when passing options to the bridge.
@freezed
sealed class AutomationOptions with _$AutomationOptions {
  const factory AutomationOptions({
    required String providerId,
    required String prompt,
    String? model,
    String? systemPrompt,
    double? temperature,
    double? topP,
    int? thinkingBudget,
    bool? useWebSearch,
    bool? disableThinking,
    bool? urlContext,
    double? timeoutModifier,
  }) = _AutomationOptions;

  factory AutomationOptions.fromJson(Map<String, dynamic> json) =>
      _$AutomationOptionsFromJson(json);
}
