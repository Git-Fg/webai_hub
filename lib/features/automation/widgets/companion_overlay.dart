import 'dart:async';

import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/automation/providers/overlay_state_provider.dart';
import 'package:ai_hybrid_hub/features/common/widgets/loading_indicator.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';
import 'package:ai_hybrid_hub/shared/ui_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CompanionOverlay extends ConsumerWidget {
  const CompanionOverlay({
    required this.overlayKey,
    super.key,
  });

  final GlobalKey overlayKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlayState = ref.watch(overlayManagerProvider);
    return AnimatedSwitcher(
      duration: kShortAnimationDuration,
      child: overlayState.isMinimized
          ? _buildMinimizedView(context, ref)
          : _buildExpandedView(context, ref),
    );
  }

  Widget _buildMinimizedView(BuildContext context, WidgetRef ref) {
    // WHY: The GestureDetector is removed. The parent now handles dragging for both minimized and expanded states.
    return FloatingActionButton(
      key: const Key('minimized_overlay'),
      tooltip: 'Expand Automation Panel',
      onPressed: () {
        ref.read(overlayManagerProvider.notifier).toggleMinimized();
      },
      child: const Icon(Icons.open_in_full),
    );
  }

  Widget _buildExpandedView(BuildContext context, WidgetRef ref) {
    final status = ref.watch(automationStateProvider);
    final statusColor = _getStatusColor(status);
    final screenSize = MediaQuery.of(context).size;
    final content = status.when(
      idle: () => const SizedBox.shrink(),
      sending: () => _buildStatusUI(
        context: context,
        statusIcon: Icons.send,
        statusColor: Colors.blue,
        message: 'Phase 1: Sending prompt...',
        isLoading: true,
      ),
      observing: () => _buildStatusUI(
        context: context,
        statusIcon: Icons.visibility,
        statusColor: Colors.orange,
        message: 'Phase 2: Assistant is responding...',
        isLoading: true,
      ),
      refining: (messageCount, isExtracting) => _buildStatusUI(
        context: context,
        statusIcon: Icons.edit,
        statusColor: Colors.green,
        message: 'Phase 3: Ready for refinement.',
        actionButton: _buildRefiningButtons(ref, messageCount),
      ),
      needsLogin: () => _buildStatusUI(
        context: context,
        statusIcon: Icons.login,
        statusColor: Colors.amber,
        message: 'Please sign in to your Google Account to continue.',
        actionButton: ElevatedButton.icon(
          icon: const Icon(Icons.check_circle),
          label: const Text("OK I'm logged"),
          onPressed: () {
            unawaited(
              ref
                  .read(conversationProvider.notifier)
                  .resumeAutomationAfterLogin(),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      failed: () => _buildStatusUI(
        context: context,
        statusIcon: Icons.error,
        statusColor: Colors.red,
        message: 'Automation Failed.',
        actionButton: ElevatedButton.icon(
          icon: const Icon(Icons.close),
          label: const Text('Dismiss'),
          onPressed: () {
            ref.read(automationStateProvider.notifier).returnToIdle();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[600],
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );

    // WHY: Constrain overlay width to prevent it from growing too large
    // Use 90% of screen width with a maximum of 400px for better UX
    final maxWidth = (screenSize.width * 0.9).clamp(0.0, 400.0);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth,
      ),
      child: Material(
        key: const Key('expanded_overlay'),
        elevation: kDefaultElevation,
        borderRadius: BorderRadius.circular(kMediumBorderRadius),
        color: Colors.white.withValues(
          alpha: 0.95,
        ), // Semi-transparent white to ensure pointer events work
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // WHY: The GestureDetector with onPanUpdate is removed. The parent now handles dragging.
            // The header is now just a simple Material widget for visuals.
            Material(
              color: Colors.grey[700],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(kMediumBorderRadius),
                topRight: Radius.circular(kMediumBorderRadius),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: kSmallPadding),
                height: 40,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.drag_handle, color: Colors.white70),
                    Row(
                      children: [
                        // WHY: Added a reset button for better UX and robustness.
                        // If the user drags the overlay off-screen, they can easily recover.
                        Material(
                          color: Colors.transparent,
                          child: IconButton(
                            tooltip: 'Reset Position',
                            icon: const Icon(
                              Icons.center_focus_strong,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              ref
                                  .read(overlayManagerProvider.notifier)
                                  .resetPosition();
                            },
                            // WHY: Ensure button receives tap events and doesn't conflict with drag gesture
                            mouseCursor: SystemMouseCursors.click,
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: IconButton(
                            tooltip: 'Minimize Automation Panel',
                            icon: const Icon(
                              Icons.close_fullscreen,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              ref
                                  .read(overlayManagerProvider.notifier)
                                  .toggleMinimized();
                            },
                            // WHY: Ensure button receives tap events and doesn't conflict with drag gesture
                            mouseCursor: SystemMouseCursors.click,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: status.maybeWhen(
                idle: () => EdgeInsets.zero,
                orElse: () => const EdgeInsets.all(kDefaultPadding),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(kMediumBorderRadius),
                  bottomRight: Radius.circular(kMediumBorderRadius),
                ),
                // Apply border and shadow here, where it belongs.
                border: status.maybeWhen(
                  idle: () => null,
                  orElse: () => Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                boxShadow: status.maybeWhen(
                  idle: () => null,
                  orElse: () => [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: kDefaultBlurRadius,
                      offset: kMediumShadowOffset,
                    ),
                  ],
                ),
              ),
              child: content,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefiningButtons(
    WidgetRef ref,
    int messageCount,
  ) {
    final isExtracting = ref.watch(
      automationStateProvider.select(
        (s) => s.maybeWhen(
          refining: (messageCount, isExtracting) => isExtracting,
          orElse: () => false,
        ),
      ),
    );
    return Wrap(
      spacing: kDefaultSpacing,
      runSpacing: kDefaultSpacing,
      children: [
        // Primary: Extract & View Hub
        ElevatedButton.icon(
          key: Key('companion_extract_and_view_hub_button_$messageCount'),
          icon: isExtracting
              ? const SizedBox(
                  width: kDefaultIconSize,
                  height: kDefaultIconSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle),
          label: const Text('Extract & View Hub'),
          onPressed: isExtracting
              ? null
              : () {
                  unawaited(
                    ref
                        .read(conversationProvider.notifier)
                        .extractAndReturnToHub(),
                  );
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
        // Secondary: Done
        ElevatedButton.icon(
          key: const Key('companion_done_button'),
          icon: const Icon(Icons.check_circle),
          label: const Text('Done'),
          onPressed: isExtracting
              ? null
              : () {
                  ref.read(conversationProvider.notifier).finalizeAutomation();
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  // Helper method to get color from state
  Color _getStatusColor(AutomationStateData status) {
    return status.when(
      idle: () => Colors.grey,
      sending: () => Colors.blue,
      observing: () => Colors.orange,
      refining: (_, isExtracting) => Colors.green,
      needsLogin: () => Colors.amber,
      failed: () => Colors.red,
    );
  }

  Widget _buildStatusUI({
    required BuildContext context,
    required String message,
    required Color statusColor,
    required IconData statusIcon,
    Widget? actionButton,
    bool isLoading = false,
  }) {
    // No Material or Container needed here anymore. It just returns the content.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(kSmallPadding),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(kSmallBorderRadius),
                ),
                child: isLoading
                    ? const LoadingIndicator(size: kDefaultIconSize)
                    : Icon(
                        statusIcon,
                        color: statusColor,
                        size: kDefaultIconSize,
                      ),
              ),
              const SizedBox(width: kMediumSpacing),
              Flexible(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: kSmallFontSize,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (actionButton != null) ...[
          const SizedBox(height: kMediumSpacing),
          actionButton,
        ],
      ],
    );
  }
}
