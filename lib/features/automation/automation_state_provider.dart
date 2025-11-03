import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'automation_state_provider.g.dart';

enum AutomationStatus { idle, sending, observing, refining, failed, needsLogin }

@riverpod
class AutomationState extends _$AutomationState {
  @override
  AutomationStatus build() => AutomationStatus.idle;

  void setStatus(AutomationStatus newStatus) {
    state = newStatus;
  }
}

/// Provider pour l'état d'extraction pendant la phase 3
@riverpod
class IsExtracting extends _$IsExtracting {
  @override
  bool build() => false;
}
