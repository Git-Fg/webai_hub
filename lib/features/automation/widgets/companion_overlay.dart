import 'package:ai_hybrid_hub/core/theme/theme_facade.dart';
import 'package:ai_hybrid_hub/features/automation/models/overlay_config.dart';
import 'package:ai_hybrid_hub/features/automation/providers/overlay_config_provider.dart';
import 'package:ai_hybrid_hub/features/automation/providers/overlay_state_provider.dart';
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
    final overlayNotifier = ref.read(overlayManagerProvider.notifier);
    final overlayConfig = ref.watch(overlayConfigProvider);

    if (overlayConfig == null) {
      return const SizedBox.shrink();
    }

    // Reset position to center for non-draggable overlays.
    if (!overlayConfig.isDraggable && overlayState.position != Offset.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        overlayNotifier.resetPosition();
      });
    }

    final content = AnimatedSwitcher(
      duration: kShortAnimationDuration,
      child: overlayState.isMinimized
          ? _buildMinimizedView(ref)
          : _buildExpandedView(context, ref, overlayConfig),
    );

    final screenSize = MediaQuery.of(context).size;
    final widgetSize = overlayKey.currentContext?.size ?? Size.zero;
    final position = overlayConfig.isDraggable
        ? overlayState.position
        : Offset.zero;

    return Align(
      alignment: Alignment.topCenter,
      child: Transform.translate(
        offset: position,
        child: Padding(
          padding: const EdgeInsets.all(kDefaultPadding),
          child: overlayConfig.isDraggable
              ? GestureDetector(
                  onPanUpdate: (details) => overlayNotifier.updatePosition(
                    details.delta,
                    screenSize,
                    widgetSize,
                  ),
                  child: content,
                )
              : content,
        ),
      ),
    );
  }

  Widget _buildMinimizedView(WidgetRef ref) {
    return FloatingActionButton(
      key: const Key('minimized_overlay'),
      tooltip: 'Expand Automation Panel',
      onPressed: () =>
          ref.read(overlayManagerProvider.notifier).toggleMinimized(),
      child: const Icon(Icons.open_in_full),
    );
  }

  Widget _buildExpandedView(
    BuildContext context,
    WidgetRef ref,
    OverlayConfig config,
  ) {
    final theme = context.hubTheme;
    final screenSize = MediaQuery.of(context).size;
    final maxWidth = (screenSize.width * 0.9).clamp(0.0, 400.0);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Material(
        key: const Key('expanded_overlay'),
        elevation: kDefaultElevation,
        borderRadius: BorderRadius.circular(kMediumBorderRadius),
        color: theme.surfaceColor?.withAlpha(240),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (config.showHeader) _buildHeader(context, ref),
            Container(
              padding: const EdgeInsets.all(kMediumSpacing),
              child: config.content,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final theme = context.hubTheme;
    return Material(
      color: theme.overlayHeaderColor,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(kMediumBorderRadius),
        topRight: Radius.circular(kMediumBorderRadius),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: kSmallPadding),
        height: 32,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(Icons.drag_handle, color: theme.overlayIconColor),
            Row(
              children: [
                IconButton(
                  tooltip: 'Reset Position',
                  icon: Icon(
                    Icons.center_focus_strong,
                    color: theme.overlayIconColor,
                  ),
                  onPressed: () =>
                      ref.read(overlayManagerProvider.notifier).resetPosition(),
                ),
                IconButton(
                  tooltip: 'Minimize Automation Panel',
                  icon: Icon(
                    Icons.close_fullscreen,
                    color: theme.overlayIconColor,
                  ),
                  onPressed: () => ref
                      .read(overlayManagerProvider.notifier)
                      .toggleMinimized(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
