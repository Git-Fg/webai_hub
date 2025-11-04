import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'automation_state_provider.freezed.dart';
part 'automation_state_provider.g.dart';

@freezed
sealed class AutomationStateData with _$AutomationStateData {
  const factory AutomationStateData.idle() = _Idle;
  const factory AutomationStateData.sending() = _Sending;
  // --- SUPPRIMÉ ---
  // const factory AutomationStateData.observing() = _Observing;
  const factory AutomationStateData.refining({
    required int messageCount,
    @Default(false) bool isExtracted,
  }) = _Refining;
  const factory AutomationStateData.failed() = _Failed;
  const factory AutomationStateData.needsLogin() = _NeedsLogin;
}

@riverpod
class AutomationState extends _$AutomationState {
  @override
  AutomationStateData build() => const AutomationStateData.idle();

  // ignore: use_setters_to_change_properties, reason: Preserve existing API for MVP stability
  void setStatus(AutomationStateData newStatus) {
    state = newStatus;
  }
}

/// Provider pour l'état d'extraction pendant la phase 3
@riverpod
class IsExtracting extends _$IsExtracting {
  @override
  bool build() => false;
}
