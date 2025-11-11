import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'automation_state_provider.freezed.dart';
part 'automation_state_provider.g.dart';

@freezed
sealed class AutomationStateData with _$AutomationStateData {
  const AutomationStateData._();

  const factory AutomationStateData.idle() = _Idle;
  // WHY: Store the prompt being processed so it can be retried after login
  const factory AutomationStateData.sending({String? prompt}) = _Sending;
  // AI is responding, user is observing
  const factory AutomationStateData.observing() = _Observing;
  const factory AutomationStateData.refining({
    required int activePresetId,
    required int messageCount,
    @Default(false) bool isExtracting,
  }) = _Refining;
  const factory AutomationStateData.failed() = _Failed;
  // WHY: This callback holds the original action that was interrupted.
  // This makes the state self-contained and removes the need for
  // a separate "PendingPrompt" provider.
  const factory AutomationStateData.needsLogin({
    Future<void> Function()? onResume,
  }) = _NeedsLogin;

  String get title => when(
    idle: () => '',
    sending: (prompt) => 'Phase 1: Sending prompt...',
    observing: () => 'Phase 2: Assistant is responding...',
    refining: (activePresetId, messageCount, isExtracting) =>
        'Phase 3: Ready for refinement.',
    failed: () => 'Automation Failed.',
    needsLogin: (onResume) =>
        'Please sign in to your provider Account to continue.',
  );

  IconData get icon => when(
    idle: () => Icons.info,
    sending: (prompt) => Icons.send,
    observing: () => Icons.visibility,
    refining: (activePresetId, messageCount, isExtracting) => Icons.edit,
    failed: () => Icons.error,
    needsLogin: (onResume) => Icons.login,
  );

  Color get color => when(
    idle: () => Colors.grey,
    sending: (prompt) => Colors.blue,
    observing: () => Colors.orange,
    refining: (activePresetId, messageCount, isExtracting) => Colors.green,
    failed: () => Colors.red,
    needsLogin: (onResume) => Colors.amber,
  );
}

@Riverpod(keepAlive: true)
class AutomationState extends _$AutomationState {
  @override
  AutomationStateData build() => const AutomationStateData.idle();

  // WHY: Store the current prompt being processed so it can be retrieved
  // even if state has transitioned from sending to observing
  String? _currentPrompt;

  String? get currentPrompt => _currentPrompt;

  void moveToSending({String? prompt}) {
    _currentPrompt = prompt;
    state = AutomationStateData.sending(prompt: prompt);
  }

  void moveToObserving() {
    // WHY: Keep the prompt when transitioning to observing so it can be
    // retrieved if login is required during observation phase
    state = const AutomationStateData.observing();
  }

  void moveToRefining({
    required int activePresetId,
    required int messageCount,
  }) => state = AutomationStateData.refining(
    activePresetId: activePresetId,
    messageCount: messageCount,
  );

  void setExtracting({required bool extracting}) {
    state.mapOrNull(
      refining: (refiningState) {
        state = refiningState.copyWith(isExtracting: extracting);
      },
    );
  }

  void moveToFailed() {
    _currentPrompt = null;
    state = const AutomationStateData.failed();
  }

  void moveToNeedsLogin({Future<void> Function()? onResume}) =>
      state = AutomationStateData.needsLogin(onResume: onResume);

  void returnToIdle() {
    _currentPrompt = null;
    state = const AutomationStateData.idle();
  }
}
