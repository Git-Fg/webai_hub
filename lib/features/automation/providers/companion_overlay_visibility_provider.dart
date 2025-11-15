import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/main.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'companion_overlay_visibility_provider.g.dart';

// WHY: Centralized provider for companion overlay visibility logic.
// This makes the business rule for when the overlay should be visible
// self-contained, testable, and reusable.
@riverpod
bool companionOverlayVisibility(Ref ref) {
  final status = ref.watch(automationStateProvider);
  final currentTabIndex = ref.watch(currentTabIndexProvider);

  final isInteractiveState = status.maybeWhen(
    refining: (activePresetId, messageCount, isExtracting) => true,
    needsLogin: (onResume) => true,
    needsUserAgentChange: () => true,
    orElse: () => false,
  );

  final isOnWebViewTab = currentTabIndex > 0;

  return isInteractiveState && isOnWebViewTab;
}
