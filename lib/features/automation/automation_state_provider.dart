import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'automation_state_provider.g.dart';

enum AutomationStatus { idle, sending, observing, refining, failed }

@riverpod
class AutomationState extends _$AutomationState {
  @override
  AutomationStatus build() => AutomationStatus.idle;

  void setStatus(AutomationStatus newStatus) {
    state = newStatus;
  }
}