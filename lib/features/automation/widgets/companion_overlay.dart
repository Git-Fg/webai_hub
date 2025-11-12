import 'dart:async';

import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/automation/providers/overlay_state_provider.dart';
import 'package:ai_hybrid_hub/features/common/widgets/loading_indicator.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/automation_errors.dart';
import 'package:ai_hybrid_hub/main.dart';
import 'package:ai_hybrid_hub/shared/ui_constants.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

class CompanionOverlay extends ConsumerWidget {
  const CompanionOverlay({
    required this.overlayKey,
    super.key,
  });

  final GlobalKey overlayKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlayState = ref.watch(overlayManagerProvider);
    final overlayNotifier = ref.read(overlayManagerProvider.notifier);

    final content = AnimatedSwitcher(
      duration: kShortAnimationDuration,
      child: overlayState.isMinimized
          ? _buildMinimizedView(context, ref)
          : _buildExpandedView(context, ref),
    );

    final screenSize = MediaQuery.of(context).size;
    final widgetSize = overlayKey.currentContext?.size ?? Size.zero;

    return Align(
      alignment: Alignment.topCenter,
      child: Transform.translate(
        offset: overlayState.position,
        child: Padding(
          padding: const EdgeInsets.all(kDefaultPadding),
          child: GestureDetector(
            onPanUpdate: (details) => overlayNotifier.updatePosition(
              details.delta,
              screenSize,
              widgetSize,
            ),
            child: content,
          ),
        ),
      ),
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
    final screenSize = MediaQuery.of(context).size;
    // WHY: Visibility logic ensures this widget is only built for refining and needsLogin states.
    // Therefore, we only need to handle those two cases here.
    final content = status.maybeWhen(
      refining: (activePresetId, messageCount, isExtracting) => _buildStatusUI(
        context: context,
        status: status,
        actionButton: _buildRefiningButtons(context, ref, messageCount),
      ),
      needsLogin: (onResume) => _buildStatusUI(
        context: context,
        status: status,
        actionButton: ElevatedButton.icon(
          icon: const Icon(Icons.check_circle),
          label: const Text("I'm logged in, Continue"),
          onPressed: onResume == null
              ? null
              : () {
                  // Simply execute the provided callback.
                  unawaited(onResume());
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      orElse: () =>
          const SizedBox.shrink(), // Safety fallback (should never be reached)
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
                height: 32, // Reduced height for a slimmer profile
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
              // WHY: Parent ensures this widget is only built for refining and needsLogin states,
              // so we always apply padding (idle state cannot occur).
              padding: const EdgeInsets.all(kMediumSpacing),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(kMediumBorderRadius),
                  bottomRight: Radius.circular(kMediumBorderRadius),
                ),
                // Apply border and shadow here, where it belongs.
                // WHY: Parent ensures this widget is only built for refining and needsLogin states,
                // so we always apply border and shadow (idle state cannot occur).
                border: Border.all(
                  color: status.color.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: kDefaultBlurRadius,
                    offset: kMediumShadowOffset,
                  ),
                ],
              ),
              child: content,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefiningButtons(
    BuildContext context,
    WidgetRef ref,
    int messageCount,
  ) {
    final isExtracting = ref.watch(
      automationStateProvider.select(
        (s) => s.maybeWhen(
          refining: (activePresetId, messageCount, isExtracting) =>
              isExtracting,
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
              : () async {
                  try {
                    // Get presetId directly from the state
                    final refiningState = ref.read(automationStateProvider);
                    refiningState.mapOrNull(
                      refining: (data) {
                        unawaited(
                          ref
                              .read(conversationActionsProvider.notifier)
                              .extractAndReturnToHub(data.activePresetId),
                        );
                      },
                    );
                  } on Object catch (e) {
                    // WHY: This is the clean, reactive way. The UI layer catches the
                    // error from the business logic layer and decides how to display it.
                    if (e is AutomationError) {
                      if (!context.mounted) return;
                      ElegantNotification.error(
                        title: const Text('Extraction Failed'),
                        description: Text(e.message),
                        toastDuration: const Duration(seconds: 5),
                      ).show(context);
                    }
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  ref.read(automationStateProvider.notifier).returnToIdle();
                  ref.read(currentTabIndexProvider.notifier).changeTo(0);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusUI({
    required BuildContext context,
    required AutomationStateData status,
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
                  color: status.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(kSmallBorderRadius),
                ),
                child: isLoading
                    ? const LoadingIndicator(size: kDefaultIconSize)
                    : Icon(
                        status.icon,
                        color: status.color,
                        size: kDefaultIconSize,
                      ),
              ),
              const Gap(kMediumSpacing),
              Flexible(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    status.title,
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
          const Gap(kMediumSpacing),
          actionButton,
        ],
      ],
    );
  }
}
