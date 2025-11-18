// lib/features/automation/widgets/automation_state_observer.dart

import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/automation/providers/overlay_config_provider.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AutomationStateObserver extends ConsumerWidget {
  const AutomationStateObserver({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AutomationStateData>(automationStateProvider, (_, next) {
      // Note: We don't need to explicitly dismiss notifications as they will be replaced
      // when new ones are shown with the same position

      next.whenOrNull(
        sending: (prompt) {
          ElegantNotification.info(
            title: Text(next.displayTitle),
            description: const Text('Configuring model and sending prompt...'),
          ).show(context);
        },
        observing: () {
          ElegantNotification.info(
            title: Text(next.displayTitle),
            description: const Text(
              'Waiting for the AI to complete its response in the WebView.',
            ),
          ).show(context);
        },
        failed: () {
          ElegantNotification.error(
            title: Text(next.displayTitle),
            description: const Text(
              'An error occurred. Check the logs for details.',
            ),
          ).show(context);
        },
      );
    });

    return child;
  }
}
