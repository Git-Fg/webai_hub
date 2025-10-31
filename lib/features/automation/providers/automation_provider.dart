import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/automation_state.dart';
import '../../../shared/models/ai_provider.dart';
import '../../../shared/models/conversation.dart';

/// Provider for automation state management
class AutomationNotifier extends StateNotifier<AutomationState> {
  AutomationNotifier() : super(const AutomationState());

  /// Start automation workflow
  void startAutomation({
    required AIProvider provider,
    required String prompt,
    Map<String, dynamic>? options,
  }) {
    state = state.copyWith(
      phase: AutomationPhase.sending,
      provider: provider,
      currentPrompt: prompt,
      canCancel: true,
      canValidate: false,
      startTime: DateTime.now(),
    );
  }

  /// Handle generation started event
  void onGenerationStarted() {
    state = state.copyWith(
      phase: AutomationPhase.observing,
      canCancel: true,
      canValidate: false,
    );
  }

  /// Handle generation completed event
  void onGenerationCompleted() {
    state = state.copyWith(
      phase: AutomationPhase.refining,
      canCancel: true,
      canValidate: true,
    );
  }

  /// Handle automation success
  void onAutomationSuccess() {
    state = state.copyWith(
      phase: AutomationPhase.extracting,
      canCancel: false,
      canValidate: false,
    );
  }

  /// Handle automation failure
  void onAutomationFailed(String error) {
    state = state.copyWith(
      phase: AutomationPhase.error,
      errorMessage: error,
      canCancel: false,
      canValidate: false,
    );
  }

  /// Validate and extract response
  void validateResponse() {
    state = state.copyWith(
      phase: AutomationPhase.extracting,
      canCancel: false,
      canValidate: false,
    );
  }

  /// Complete automation
  void completeAutomation() {
    state = const AutomationState();
  }

  /// Cancel automation
  void cancelAutomation() {
    state = state.copyWith(
      phase: AutomationPhase.idle,
      canCancel: false,
      canValidate: false,
    );
  }

  /// Reset to idle state
  void reset() {
    state = const AutomationState();
  }
}

// Provider instances
final automationProvider = StateNotifierProvider<AutomationNotifier, AutomationState>(
  (ref) => AutomationNotifier(),
);

/// Convenience provider for checking if automation is active
final isAutomationActiveProvider = Provider<bool>(
  (ref) {
    final automationState = ref.watch(automationProvider);
    return automationState.isActive;
  },
);

/// Convenience provider for checking if automation has error
final hasAutomationErrorProvider = Provider<bool>(
  (ref) {
    final automationState = ref.watch(automationProvider);
    return automationState.hasError;
  },
);

/// Provider for automation duration tracking
final automationDurationProvider = Provider<Duration?>(
  (ref) {
    final automationState = ref.watch(automationProvider);
    final startTime = automationState.startTime;

    if (startTime == null || automationState.isIdle) {
      return null;
    }

    return DateTime.now().difference(startTime);
  },
);

/// Provider for formatted automation duration
final automationDurationTextProvider = Provider<String>(
  (ref) {
    final duration = ref.watch(automationDurationProvider);

    if (duration == null) return '';

    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  },
);

/// Provider for current automation status text
final automationStatusTextProvider = Provider<String>(
  (ref) {
    final automationState = ref.watch(automationProvider);
    final duration = ref.watch(automationDurationTextProvider);
    final statusText = automationState.statusText;

    if (statusText.isEmpty) return '';

    return duration.isNotEmpty ? '$statusText ($duration)' : statusText;
  },
);