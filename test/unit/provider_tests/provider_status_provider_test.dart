import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multi_webview_tab_manager/shared/models/ai_provider.dart';
import 'package:multi_webview_tab_manager/shared/models/automation_state.dart';
import 'package:multi_webview_tab_manager/features/hub/providers/provider_status_provider.dart';

void main() {
  group('ProviderStatusProvider Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is empty map', () {
      final state = container.read(providerStatusProvider);

      expect(state, isEmpty);
    });

    test('updateStatus sets status for provider', () {
      final notifier = container.read(providerStatusProvider.notifier);
      
      notifier.updateStatus(AIProvider.aistudio, ProviderStatus.ready);

      final state = container.read(providerStatusProvider);

      expect(state[AIProvider.aistudio], ProviderStatus.ready);
    });

    test('updateStatus updates existing status', () {
      final notifier = container.read(providerStatusProvider.notifier);
      
      notifier.updateStatus(AIProvider.qwen, ProviderStatus.loading);
      notifier.updateStatus(AIProvider.qwen, ProviderStatus.ready);

      final state = container.read(providerStatusProvider);

      expect(state[AIProvider.qwen], ProviderStatus.ready);
      expect(state.length, 1);
    });

    test('setAllStatuses replaces all statuses', () {
      final notifier = container.read(providerStatusProvider.notifier);
      
      notifier.setAllStatuses({
        AIProvider.aistudio: ProviderStatus.ready,
        AIProvider.qwen: ProviderStatus.login,
        AIProvider.zai: ProviderStatus.ready,
        AIProvider.kimi: ProviderStatus.login,
      });

      final state = container.read(providerStatusProvider);

      expect(state.length, 4);
      expect(state[AIProvider.aistudio], ProviderStatus.ready);
      expect(state[AIProvider.qwen], ProviderStatus.login);
      expect(state[AIProvider.zai], ProviderStatus.ready);
      expect(state[AIProvider.kimi], ProviderStatus.login);
    });

    test('markProviderInAutomation sets automation status', () {
      final notifier = container.read(providerStatusProvider.notifier);
      
      notifier.markProviderInAutomation(AIProvider.aistudio);

      final state = container.read(providerStatusProvider);

      expect(state[AIProvider.aistudio], ProviderStatus.automation);
    });

    test('clearProviderAutomation transitions to loading then ready', () async {
      final notifier = container.read(providerStatusProvider.notifier);
      
      notifier.markProviderInAutomation(AIProvider.qwen);
      expect(container.read(providerStatusProvider)[AIProvider.qwen], ProviderStatus.automation);

      notifier.clearProviderAutomation(AIProvider.qwen);
      expect(container.read(providerStatusProvider)[AIProvider.qwen], ProviderStatus.loading);

      await Future.delayed(Duration(milliseconds: 1100)); // Wait for delayed update

      final state = container.read(providerStatusProvider);
      expect(state[AIProvider.qwen], ProviderStatus.ready);
    });

    test('providerStatusProviderFamily returns status for provider', () {
      final notifier = container.read(providerStatusProvider.notifier);
      
      notifier.updateStatus(AIProvider.zai, ProviderStatus.ready);

      final status = container.read(providerStatusProviderFamily(AIProvider.zai));

      expect(status, ProviderStatus.ready);
    });

    test('providerStatusProviderFamily returns unknown for missing provider', () {
      final status = container.read(providerStatusProviderFamily(AIProvider.kimi));

      expect(status, ProviderStatus.unknown);
    });

    test('readyProvidersCountProvider counts ready providers', () {
      final notifier = container.read(providerStatusProvider.notifier);
      
      notifier.setAllStatuses({
        AIProvider.aistudio: ProviderStatus.ready,
        AIProvider.qwen: ProviderStatus.login,
        AIProvider.zai: ProviderStatus.ready,
        AIProvider.kimi: ProviderStatus.error,
      });

      final count = container.read(readyProvidersCountProvider);

      expect(count, 2);
    });

    test('readyProvidersCountProvider returns zero when none ready', () {
      final notifier = container.read(providerStatusProvider.notifier);
      
      notifier.setAllStatuses({
        AIProvider.aistudio: ProviderStatus.login,
        AIProvider.qwen: ProviderStatus.error,
      });

      final count = container.read(readyProvidersCountProvider);

      expect(count, 0);
    });

    test('hasReadyProviderProvider returns true when ready providers exist', () {
      final notifier = container.read(providerStatusProvider.notifier);
      
      notifier.updateStatus(AIProvider.aistudio, ProviderStatus.ready);

      final hasReady = container.read(hasReadyProviderProvider);

      expect(hasReady, true);
    });

    test('hasReadyProviderProvider returns false when no ready providers', () {
      final notifier = container.read(providerStatusProvider.notifier);
      
      notifier.setAllStatuses({
        AIProvider.aistudio: ProviderStatus.login,
        AIProvider.qwen: ProviderStatus.error,
      });

      final hasReady = container.read(hasReadyProviderProvider);

      expect(hasReady, false);
    });

    test('checkAllProviders sets loading then updates all providers', () async {
      final notifier = container.read(providerStatusProvider.notifier);
      
      notifier.checkAllProviders();

      // Initially all should be loading
      final initialState = container.read(providerStatusProvider);
      for (final provider in AIProvider.values) {
        expect(initialState[provider], ProviderStatus.loading);
      }

      // Wait for all delayed updates
      await Future.delayed(Duration(milliseconds: 5000));

      final finalState = container.read(providerStatusProvider);
      expect(finalState.length, AIProvider.values.length);
      
      // All should have been updated (not loading anymore)
      for (final provider in AIProvider.values) {
        expect(finalState[provider], isNot(ProviderStatus.loading));
      }
    });

    test('multiple status updates work correctly', () {
      final notifier = container.read(providerStatusProvider.notifier);
      
      notifier.updateStatus(AIProvider.aistudio, ProviderStatus.ready);
      notifier.updateStatus(AIProvider.qwen, ProviderStatus.login);
      notifier.updateStatus(AIProvider.zai, ProviderStatus.error);
      notifier.markProviderInAutomation(AIProvider.kimi);

      final state = container.read(providerStatusProvider);

      expect(state[AIProvider.aistudio], ProviderStatus.ready);
      expect(state[AIProvider.qwen], ProviderStatus.login);
      expect(state[AIProvider.zai], ProviderStatus.error);
      expect(state[AIProvider.kimi], ProviderStatus.automation);
      expect(state.length, 4);
    });
  });
}

