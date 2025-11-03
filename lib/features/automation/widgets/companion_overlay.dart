import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';
import 'package:ai_hybrid_hub/features/common/widgets/loading_indicator.dart';

class CompanionOverlay extends ConsumerWidget {
  const CompanionOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(automationStateProvider);

    String message;
    Widget? actionButton;
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case AutomationStatus.sending:
        message = "Phase 1: Sending prompt...";
        statusColor = Colors.blue;
        statusIcon = Icons.send;
        break;
      case AutomationStatus.observing:
        message = "Phase 2: Observing for response...";
        statusColor = Colors.orange;
        statusIcon = Icons.visibility;
        break;
      case AutomationStatus.refining:
        message = "Phase 3: Ready for refinement.";
        statusColor = Colors.green;
        statusIcon = Icons.edit;
        actionButton = Builder(
          builder: (context) {
            final isExtracting = ref.watch(isExtractingProvider);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.cancel),
                  label: const Text("Cancel"),
                  onPressed: isExtracting
                      ? null
                      : () {
                          ref
                              .read(conversationProvider.notifier)
                              .cancelAutomation();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: isExtracting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle),
                  label: const Text("Validate & Extract"),
                  onPressed: isExtracting
                      ? null
                      : () {
                          ref
                              .read(conversationProvider.notifier)
                              .validateAndFinalizeResponse();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
        break;
      case AutomationStatus.needsLogin:
        message = "Please sign in to your Google Account to continue.";
        statusColor = Colors.amber;
        statusIcon = Icons.login;
        actionButton = ElevatedButton.icon(
          icon: const Icon(Icons.check_circle),
          label: const Text("OK I'm logged"),
          onPressed: () {
            // Reprendre l'automatisation après login
            ref
                .read(conversationProvider.notifier)
                .resumeAutomationAfterLogin();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.white,
          ),
        );
        break;
      case AutomationStatus.failed:
        message = "Automation Failed.";
        statusColor = Colors.red;
        statusIcon = Icons.error;
        actionButton = ElevatedButton.icon(
          icon: const Icon(Icons.close),
          label: const Text("Dismiss"),
          onPressed: () {
            ref
                .read(automationStateProvider.notifier)
                .setStatus(AutomationStatus.idle);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[600],
            foregroundColor: Colors.white,
          ),
        );
        break;
      case AutomationStatus.idle:
        return const SizedBox.shrink(); // Don't show overlay when idle
    }

    // Positioned is now handled in main.dart - return Material directly
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: statusColor.withValues(alpha: 0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: status == AutomationStatus.sending ||
                          status == AutomationStatus.observing
                      ? const LoadingIndicator(
                          size: 20,
                          color: Colors.blue,
                        )
                      : Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
            if (actionButton != null) ...[
              const SizedBox(height: 12),
              actionButton,
            ],
          ],
        ),
      ),
    );
  }
}
