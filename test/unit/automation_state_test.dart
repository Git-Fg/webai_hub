import 'package:flutter_test/flutter_test.dart';
import 'package:multi_webview_tab_manager/shared/models/automation_state.dart';
import 'package:multi_webview_tab_manager/shared/models/ai_provider.dart';

void main() {
  group('AutomationState Tests', () {
    test('AutomationState creates with default idle state', () {
      final state = const AutomationState();

      expect(state.phase, AutomationPhase.idle);
      expect(state.provider, isNull);
      expect(state.currentPrompt, isNull);
      expect(state.errorMessage, isNull);
      expect(state.canCancel, false);
      expect(state.canValidate, false);
      expect(state.startTime, isNull);
    });

    test('AutomationState copyWith works correctly', () {
      final original = const AutomationState();

      final updated = original.copyWith(
        phase: AutomationPhase.sending,
        provider: AIProvider.kimi,
        currentPrompt: 'Test prompt',
        canCancel: true,
        startTime: DateTime.now(),
      );

      expect(updated.phase, AutomationPhase.sending);
      expect(updated.provider, AIProvider.kimi);
      expect(updated.currentPrompt, 'Test prompt');
      expect(updated.canCancel, true);
      expect(updated.canValidate, false); // Should remain default
      expect(updated.startTime, isNotNull);
    });

    test('Status text returns correct values', () {
      final state1 = const AutomationState(phase: AutomationPhase.idle);
      expect(state1.statusText, '');

      final state2 = const AutomationState(phase: AutomationPhase.sending);
      expect(state2.statusText, 'Envoi en cours...');

      final state3 = const AutomationState(phase: AutomationPhase.observing);
      expect(state3.statusText, 'Génération en cours...');

      final state4 = const AutomationState(phase: AutomationPhase.refining);
      expect(state4.statusText, 'Prêt pour raffinage');

      final state5 = const AutomationState(phase: AutomationPhase.extracting);
      expect(state5.statusText, 'Extraction en cours...');

      final state6 = const AutomationState(
        phase: AutomationPhase.error,
        errorMessage: 'Test error',
      );
      expect(state6.statusText, 'Erreur: Test error');
    });

    test('State properties work correctly', () {
      final idleState = const AutomationState();
      expect(idleState.isIdle, true);
      expect(idleState.isActive, false);
      expect(idleState.hasError, false);

      final activeState = const AutomationState(phase: AutomationPhase.sending);
      expect(activeState.isIdle, false);
      expect(activeState.isActive, true);
      expect(activeState.hasError, false);

      final errorState = const AutomationState(
        phase: AutomationPhase.error,
        errorMessage: 'Test error',
      );
      expect(errorState.isIdle, false);
      expect(errorState.isActive, false);
      expect(errorState.hasError, true);
    });

    test('Complete workflow state progression', () {
      var state = const AutomationState();

      // Phase 1: Start
      state = state.copyWith(
        phase: AutomationPhase.sending,
        canCancel: true,
      );
      expect(state.phase, AutomationPhase.sending);
      expect(state.canCancel, true);

      // Phase 2: Observing
      state = state.copyWith(phase: AutomationPhase.observing);
      expect(state.phase, AutomationPhase.observing);
      expect(state.canCancel, true);

      // Phase 3: Refining
      state = state.copyWith(
        phase: AutomationPhase.refining,
        canValidate: true,
      );
      expect(state.phase, AutomationPhase.refining);
      expect(state.canValidate, true);

      // Phase 4: Extracting
      state = state.copyWith(
        phase: AutomationPhase.extracting,
        canCancel: false,
        canValidate: false,
      );
      expect(state.phase, AutomationPhase.extracting);
      expect(state.canCancel, false);
      expect(state.canValidate, false);

      // Complete
      state = const AutomationState();
      expect(state.phase, AutomationPhase.idle);
    });
  });
}