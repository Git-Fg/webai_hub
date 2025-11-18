import 'dart:async';

import 'package:ai_hybrid_hub/core/router/app_router.dart';
import 'package:ai_hybrid_hub/core/theme/theme_facade.dart';
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/automation/models/overlay_config.dart';
import 'package:ai_hybrid_hub/features/automation/providers/automation_actions.dart';
import 'package:ai_hybrid_hub/features/common/widgets/loading_indicator.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/automation_errors.dart';
import 'package:ai_hybrid_hub/main.dart' show currentTabIndexProvider;
import 'package:ai_hybrid_hub/shared/ui_constants.dart';
import 'package:auto_route/auto_route.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'overlay_config_provider.g.dart';

// WHY: Extension to provide UI presentation properties for AutomationStateData.
// This separates presentation logic from the pure state model.
extension AutomationStateUI on AutomationStateData {
  String get displayTitle => when(
    idle: () => '',
    sending: (prompt) => 'Phase 1: Sending prompt...',
    observing: () => 'Phase 2: Assistant is responding...',
    refining: (activePresetId, messageCount, isExtracting) =>
        'Phase 3: Ready for refinement.',
    failed: () => 'Automation Failed.',
    needsLogin: (onResume) =>
        'Please sign in to your provider Account to continue.',
    needsUserAgentChange: () => 'Google Login Blocked - User Agent Required',
  );

  IconData get displayIcon => when(
    idle: () => Icons.info,
    sending: (prompt) => Icons.send,
    observing: () => Icons.visibility,
    refining: (activePresetId, messageCount, isExtracting) => Icons.edit,
    failed: () => Icons.error,
    needsLogin: (onResume) => Icons.login,
    needsUserAgentChange: () => Icons.warning,
  );

  // WHY: Colors are retrieved from theme which always provides non-null values
  Color displayColor(BuildContext context) {
    final theme = context.hubTheme;
    return when(
      idle: () => theme.dividerColor!,
      sending: (prompt) => theme.sendButtonColor!,
      observing: () => theme.messageSendingColor!,
      refining: (activePresetId, messageCount, isExtracting) =>
          theme.editSaveIconColor!,
      failed: () => theme.messageErrorColor!,
      needsLogin: (onResume) => theme.messageSendingColor!,
      needsUserAgentChange: () => theme.messageSendingColor!,
    );
  }
}

@riverpod
OverlayConfig? overlayConfig(Ref ref) {
  final automationState = ref.watch(automationStateProvider);

  return automationState.maybeWhen(
    refining: (activePresetId, messageCount, isExtracting) => OverlayConfig(
      content: _buildRefiningContent(
        ref,
        activePresetId,
        messageCount,
        isExtracting,
      ),
    ),
    needsLogin: (onResume) => OverlayConfig(
      content: _buildNeedsLoginContent(ref, onResume),
    ),
    needsUserAgentChange: () => OverlayConfig(
      content: _buildNeedsUserAgentChangeContent(ref),
      isDraggable: false,
      showHeader: false,
    ),
    orElse: () => null,
  );
}

Widget _buildRefiningContent(
  Ref ref,
  int activePresetId,
  int messageCount,
  bool isExtracting,
) {
  return Consumer(
    builder: (context, ref, _) {
      final theme = context.hubTheme;
      final status = ref.watch(automationStateProvider);

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusUI(context, status),
          const Gap(kMediumSpacing),
          Wrap(
            spacing: kDefaultSpacing,
            runSpacing: kDefaultSpacing,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                key: Key('companion_extract_and_view_hub_button_$messageCount'),
                icon: isExtracting
                    ? SizedBox(
                        width: kDefaultIconSize,
                        height: kDefaultIconSize,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.actionButtonTextColor!,
                          ),
                        ),
                      )
                    : const Icon(Icons.check_circle),
                label: const Text('Extract & View Hub'),
                onPressed: isExtracting
                    ? null
                    : () => _onExtract(context, ref, activePresetId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.successActionButtonColor,
                  foregroundColor: theme.actionButtonTextColor,
                ),
              ),
              ElevatedButton.icon(
                key: const Key('companion_done_button'),
                icon: const Icon(Icons.check_circle),
                label: const Text('Done'),
                onPressed: isExtracting ? null : () => _onDone(ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.secondaryNeutralButtonColor,
                  foregroundColor: theme.actionButtonTextColor,
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

Widget _buildNeedsLoginContent(Ref ref, Future<void> Function()? onResume) {
  return Consumer(
    builder: (context, ref, _) {
      final theme = context.hubTheme;
      final status = ref.watch(automationStateProvider);

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusUI(context, status),
          const Gap(kMediumSpacing),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle),
            label: const Text("I'm logged in, Continue"),
            onPressed: onResume,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.warningActionButtonColor,
              foregroundColor: theme.actionButtonTextColor,
            ),
          ),
        ],
      );
    },
  );
}

Widget _buildNeedsUserAgentChangeContent(Ref ref) {
  return Consumer(
    builder: (context, ref, _) {
      final theme = context.hubTheme;
      final status = ref.watch(automationStateProvider);

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusUI(context, status),
          const Gap(kMediumSpacing),
          ElevatedButton.icon(
            icon: const Icon(Icons.settings),
            label: const Text('Go to Settings'),
            onPressed: () =>
                unawaited(context.router.push(const SettingsRoute())),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.secondaryActionButtonColor,
              foregroundColor: theme.actionButtonTextColor,
            ),
          ),
        ],
      );
    },
  );
}

Widget _buildStatusUI(
  BuildContext context,
  AutomationStateData status, {
  bool isLoading = false,
}) {
  final theme = context.hubTheme;
  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(kSmallPadding),
        decoration: BoxDecoration(
          color: status.displayColor(context).withAlpha(25),
          borderRadius: BorderRadius.circular(kSmallBorderRadius),
        ),
        child: isLoading
            ? const LoadingIndicator(size: kDefaultIconSize)
            : Icon(
                status.displayIcon,
                color: status.displayColor(context),
                size: kDefaultIconSize,
              ),
      ),
      const Gap(kMediumSpacing),
      Flexible(
        child: Semantics(
          liveRegion: true,
          child: Text(
            status.displayTitle,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: kSmallFontSize,
              color: theme.onSurfaceColor,
            ),
          ),
        ),
      ),
    ],
  );
}

void _onExtract(BuildContext context, WidgetRef ref, int presetId) {
  unawaited(
    ref
        .read(automationActionsProvider.notifier)
        .extractAndReturnToHub(presetId)
        .catchError((Object e) {
          if (e is AutomationError && context.mounted) {
            ElegantNotification.error(
              title: const Text('Extraction Failed'),
              description: Text(e.message),
              toastDuration: const Duration(seconds: 5),
            ).show(context);
          }
        }),
  );
}

void _onDone(WidgetRef ref) {
  ref.read(automationStateProvider.notifier).returnToIdle();
  ref.read(currentTabIndexProvider.notifier).changeTo(0);
}
