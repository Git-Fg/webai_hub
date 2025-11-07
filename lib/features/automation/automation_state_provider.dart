import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'automation_state_provider.freezed.dart';
part 'automation_state_provider.g.dart';

@freezed
sealed class AutomationStateData with _$AutomationStateData {
  const factory AutomationStateData.idle() = _Idle;
  const factory AutomationStateData.sending() = _Sending;
  // AI is responding, user is observing
  const factory AutomationStateData.observing() = _Observing;
  const factory AutomationStateData.refining({
    required int messageCount,
    @Default(false) bool isExtracting,
  }) = _Refining;
  const factory AutomationStateData.failed() = _Failed;
  const factory AutomationStateData.needsLogin() = _NeedsLogin;
}

@Riverpod(keepAlive: true)
class AutomationState extends _$AutomationState {
  @override
  AutomationStateData build() => const AutomationStateData.idle();

  void moveToSending() => state = const AutomationStateData.sending();

  void moveToObserving() => state = const AutomationStateData.observing();

  void moveToRefining({required int messageCount}) =>
      state = AutomationStateData.refining(
        messageCount: messageCount,
      );

  void setExtracting({required bool extracting}) {
    state.mapOrNull(
      refining: (refiningState) {
        state = refiningState.copyWith(isExtracting: extracting);
      },
    );
  }

  void moveToFailed() => state = const AutomationStateData.failed();

  void moveToNeedsLogin() => state = const AutomationStateData.needsLogin();

  void returnToIdle() => state = const AutomationStateData.idle();
}
