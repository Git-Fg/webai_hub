import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multi_webview_tab_manager/shared/models/ai_provider.dart';
import 'package:multi_webview_tab_manager/shared/models/automation_state.dart';
import 'package:multi_webview_tab_manager/features/automation/providers/automation_provider.dart';

void main() {
  group('AutomationProvider Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is idle', () {
      final state = container.read(automationProvider);

      expect(state.phase, AutomationPhase.idle);
      expect(state.provider, isNull);
      expect(state.currentPrompt, isNull);
      expect(state.errorMessage, isNull);
      expect(state.canCancel, false);
      expect(state.canValidate, false);
      expect(state.startTime, isNull);
    });

    test('startAutomation sets sending phase', () {
      final notifier = container.read(automationProvider.notifier);
      
      notifier.startAutomation(
        provider: AIProvider.kimi,
        prompt: 'Test prompt',
      );

      final state = container.read(automationProvider);

      expect(state.phase, AutomationPhase.sending);
      expect(state.provider, AIProvider.kimi);
      expect(state.currentPrompt, 'Test prompt');
      expect(state.canCancel, true);
      expect(state.canValidate, false);
      expect(state.startTime, isNotNull);
    });

    test('startAutomation accepts options', () {
      final notifier = container.read(automationProvider.notifier);
      
      notifier.startAutomation(
        provider: AIProvider.aistudio,
        prompt: 'Prompt',
        options: {'temperature': 0.7},
      );

      final state = container.read(automationProvider);
      expect(state.phase, AutomationPhase.sending);
    });

    test('onGenerationStarted transitions to observing phase', () {
      final notifier = container.read(automationProvider.notifier);
      
      notifier.startAutomation(
        provider: AIProvider.qwen,
        prompt: 'Test',
      );
      
      notifier.onGenerationStarted();
      final state = container.read(automationProvider);

      expect(state.phase, AutomationPhase.observing);
      expect(state.canCancel, true);
      expect(state.canValidate, false);
    });

    test('onGenerationCompleted transitions to refining phase', () {
      final notifier = container.read(automationProvider.notifier);
      
      notifier.startAutomation(provider: AIProvider.zai, prompt: 'Test');
      notifier.onGenerationStarted();
      notifier.onGenerationCompleted();

      final state = container.read(automationProvider);

      expect(state.phase, AutomationPhase.refining);
      expect(state.canCancel, true);
      expect(state.canValidate, true);
    });

    test('onAutomationSuccess transitions to extracting phase', () {
      final notifier = container.read(automationProvider.notifier);
      
      notifier.startAutomation(provider: AIProvider.kimi, prompt: 'Test');
      notifier.onAutomationSuccess();

      final state = container.read(automationProvider);

      expect(state.phase, AutomationPhase.extracting);
      expect(state.canCancel, false);
      expect(state.canValidate, false);
    });

    test('onAutomationFailed sets error state', () {
      final notifier = container.read(automationProvider.notifier);
      
      notifier.startAutomation(provider: AIProvider.aistudio, prompt: 'Test');
      notifier.onAutomationFailed('Test error');

      final state = container.read(automationProvider);

      expect(state.phase, AutomationPhase.error);
      expect(state.errorMessage, 'Test error');
      expect(state.canCancel, false);
      expect(state.canValidate, false);
    });

    test('validateResponse transitions to extracting phase', () {
      final notifier = container.read(automationProvider.notifier);
      
      notifier.startAutomation(provider: AIProvider.qwen, prompt: 'Test');
      notifier.onGenerationCompleted();
      notifier.validateResponse();

      final state = container.read(automationProvider);

      expect(state.phase, AutomationPhase.extracting);
      expect(state.canCancel, false);
      expect(state.canValidate, false);
    });

    test('completeAutomation resets to idle', () {
      final notifier = container.read(automationProvider.notifier);
      
      notifier.startAutomation(provider: AIProvider.zai, prompt: 'Test');
      notifier.completeAutomation();

      final state = container.read(automationProvider);

      expect(state.phase, AutomationPhase.idle);
      expect(state.provider, isNull);
      expect(state.currentPrompt, isNull);
    });

    test('cancelAutomation resets to idle', () {
      final notifier = container.read(automationProvider.notifier);
      
      notifier.startAutomation(provider: AIProvider.kimi, prompt: 'Test');
      notifier.cancelAutomation();

      final state = container.read(automationProvider);

      expect(state.phase, AutomationPhase.idle);
      expect(state.canCancel, false);
      expect(state.canValidate, false);
    });

    test('reset returns to initial state', () {
      final notifier = container.read(automationProvider.notifier);
      
      notifier.startAutomation(provider: AIProvider.aistudio, prompt: 'Test');
      notifier.reset();

      final state = container.read(automationProvider);

      expect(state.phase, AutomationPhase.idle);
      expect(state.provider, isNull);
    });

    test('isAutomationActiveProvider returns true when active', () {
      final notifier = container.read(automationProvider.notifier);
      
      notifier.startAutomation(provider: AIProvider.qwen, prompt: 'Test');

      final isActive = container.read(isAutomationActiveProvider);

      expect(isActive, true);
    });

    test('isAutomationActiveProvider returns false when idle', () {
      final isActive = container.read(isAutomationActiveProvider);
      expect(isActive, false);
    });

    test('isAutomationActiveProvider returns false when error', () {
      final notifier = container.read(automationProvider.notifier);
      
      notifier.startAutomation(provider: AIProvider.zai, prompt: 'Test');
      notifier.onAutomationFailed('Error');

      final isActive = container.read(isAutomationActiveProvider);

      expect(isActive, false);
    });

    test('hasAutomationErrorProvider returns true on error', () {
      final notifier = container.read(automationProvider.notifier);
      
      notifier.startAutomation(provider: AIProvider.kimi, prompt: 'Test');
      notifier.onAutomationFailed('Error');

      final hasError = container.read(hasAutomationErrorProvider);

      expect(hasError, true);
    });

    test('hasAutomationErrorProvider returns false when no error', () {
      final hasError = container.read(hasAutomationErrorProvider);
      expect(hasError, false);
    });

    test('automationDurationProvider returns null when idle', () {
      final duration = container.read(automationDurationProvider);
      expect(duration, isNull);
    });

    test('automationDurationProvider returns duration when active', () async {
      final notifier = container.read(automationProvider.notifier);
      
      notifier.startAutomation(provider: AIProvider.aistudio, prompt: 'Test');
      // Small delay to ensure duration > 0
      await Future.delayed(Duration(milliseconds: 10));

      final duration = container.read(automationDurationProvider);

      expect(duration, isNotNull);
      expect(duration!.inMilliseconds, greaterThan(0));
    });

    test('automationDurationTextProvider returns empty string when idle', () {
      final text = container.read(automationDurationTextProvider);
      expect(text, '');
    });

    test('automationDurationTextProvider formats seconds correctly', () async {
      final notifier = container.read(automationProvider.notifier);
      
      notifier.startAutomation(provider: AIProvider.qwen, prompt: 'Test');
      await Future.delayed(Duration(milliseconds: 500));

      final text = container.read(automationDurationTextProvider);

      expect(text, isNotEmpty);
      expect(text.contains('s'), true);
    });

    test('automationStatusTextProvider includes duration when active', () async {
      final notifier = container.read(automationProvider.notifier);
      
      notifier.startAutomation(provider: AIProvider.zai, prompt: 'Test');
      await Future.delayed(Duration(milliseconds: 10));

      final statusText = container.read(automationStatusTextProvider);

      expect(statusText, isNotEmpty);
      expect(statusText.contains('Envoi en cours'), true);
    });

    test('complete workflow state progression', () {
      final notifier = container.read(automationProvider.notifier);

      // Start
      notifier.startAutomation(provider: AIProvider.kimi, prompt: 'Test');
      expect(container.read(automationProvider).phase, AutomationPhase.sending);

      // Generation started
      notifier.onGenerationStarted();
      expect(container.read(automationProvider).phase, AutomationPhase.observing);

      // Generation completed
      notifier.onGenerationCompleted();
      expect(container.read(automationProvider).phase, AutomationPhase.refining);

      // Validate and extract
      notifier.validateResponse();
      expect(container.read(automationProvider).phase, AutomationPhase.extracting);

      // Complete
      notifier.completeAutomation();
      expect(container.read(automationProvider).phase, AutomationPhase.idle);
    });
  });
}

