import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/ai_provider.dart';
import '../../../shared/models/automation_state.dart';

class ProviderStatusNotifier extends StateNotifier<Map<AIProvider, ProviderStatus>> {
  ProviderStatusNotifier() : super({});

  void updateStatus(AIProvider provider, ProviderStatus status) {
    state = {
      ...state,
      provider: status,
    };
  }

  void setAllStatuses(Map<AIProvider, ProviderStatus> statuses) {
    state = statuses;
  }

  void checkAllProviders() {
    for (final provider in AIProvider.values) {
      updateStatus(provider, ProviderStatus.loading);

      // Simulate status checking
      Future.delayed(Duration(seconds: 1 + AIProvider.values.indexOf(provider)), () {
        // Random status for demo - in real implementation, this would check actual login status
        final statuses = [
          ProviderStatus.ready,
          ProviderStatus.login,
          ProviderStatus.ready,
          ProviderStatus.login,
        ];
        updateStatus(provider, statuses[AIProvider.values.indexOf(provider)]);
      });
    }
  }

  void markProviderInAutomation(AIProvider provider) {
    updateStatus(provider, ProviderStatus.automation);
  }

  void clearProviderAutomation(AIProvider provider) {
    // Re-check status after automation completes
    updateStatus(provider, ProviderStatus.loading);
    Future.delayed(const Duration(seconds: 1), () {
      updateStatus(provider, ProviderStatus.ready);
    });
  }
}

final providerStatusProvider = StateNotifierProvider<ProviderStatusNotifier, Map<AIProvider, ProviderStatus>>(
  (ref) => ProviderStatusNotifier(),
);

// Individual provider status
final providerStatusProviderFamily = Provider.family<ProviderStatus, AIProvider>(
  (ref, provider) {
    final statuses = ref.watch(providerStatusProvider);
    return statuses[provider] ?? ProviderStatus.unknown;
  },
);

// Count of ready providers
final readyProvidersCountProvider = Provider<int>(
  (ref) {
    final statuses = ref.watch(providerStatusProvider);
    return statuses.values.where((status) => status == ProviderStatus.ready).length;
  },
);

// Check if any provider is ready
final hasReadyProviderProvider = Provider<bool>(
  (ref) {
    final count = ref.watch(readyProvidersCountProvider);
    return count > 0;
  },
);