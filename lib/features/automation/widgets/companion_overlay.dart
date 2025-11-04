import 'dart:async';

import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/common/widgets/loading_indicator.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';
import 'package:ai_hybrid_hub/shared/ui_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CompanionOverlay extends ConsumerWidget {
  const CompanionOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(automationStateProvider);
    return status.when(
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
        isLoading: true, // Affiche un indicateur de chargement
      ),
      refining: (messageCount) => _buildStatusUI(
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
            ref
                .read(automationStateProvider.notifier)
                .setStatus(const AutomationStateData.idle());
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[600],
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildRefiningButtons(
    WidgetRef ref,
    int messageCount,
  ) {
    final isExtracting = ref.watch(isExtractingProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Primary: Extract & View Hub
        Semantics(
          label: 'companion_extract_and_view_hub_button',
          button: true,
          child: ElevatedButton.icon(
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
        ),
        const SizedBox(width: kDefaultSpacing),
        // Secondary: Done
        Semantics(
          label: 'companion_done_button',
          button: true,
          child: ElevatedButton.icon(
            key: const Key('companion_done_button'),
            icon: const Icon(Icons.check_circle),
            label: const Text('Done'),
            onPressed: isExtracting
                ? null
                : () {
                    ref
                        .read(conversationProvider.notifier)
                        .finalizeAutomation();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
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
    // Positioned is now handled in main.dart - return Material directly
    return Material(
      elevation: kDefaultElevation,
      borderRadius: BorderRadius.circular(kMediumBorderRadius),
      child: Container(
        padding: const EdgeInsets.all(kDefaultPadding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(kMediumBorderRadius),
          border:
              Border.all(color: statusColor.withValues(alpha: 0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: kDefaultBlurRadius,
              offset: kMediumShadowOffset,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(kSmallPadding),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(kSmallBorderRadius),
                  ),
                  child: isLoading
                      ? const LoadingIndicator(size: kDefaultIconSize)
                      : Icon(statusIcon, color: statusColor, size: kDefaultIconSize),
                ),
                const SizedBox(width: kMediumSpacing),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: kSmallFontSize,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
            if (actionButton != null) ...[
              const SizedBox(height: kMediumSpacing),
              actionButton,
            ],
          ],
        ),
      ),
    );
  }
}
