import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/automation_state.dart';
import '../../../shared/models/ai_provider.dart';
import '../providers/automation_provider.dart';

/// Companion overlay that appears during automation
class CompanionOverlay extends ConsumerWidget {
  const CompanionOverlay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final automationState = ref.watch(automationProvider);
    final isVisible = automationState.isActive;

    if (!isVisible) return const SizedBox.shrink();

    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: _buildOverlay(context, ref, automationState),
    );
  }

  Widget _buildOverlay(
    BuildContext context,
    WidgetRef ref,
    AutomationState automationState,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getBorderColor(automationState.phase),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status indicator
          _buildStatusIndicator(automationState),
          const SizedBox(height: 12),

          // Status text
          _buildStatusText(automationState),
          const SizedBox(height: 8),

          // Provider info
          if (automationState.provider != null)
            _buildProviderInfo(automationState.provider!),
          const SizedBox(height: 16),

          // Action buttons
          _buildActionButtons(context, ref, automationState),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(AutomationState automationState) {
    Color color;
    IconData icon;
    double size;

    switch (automationState.phase) {
      case AutomationPhase.sending:
        color = Colors.blue;
        icon = Icons.send;
        size = 20;
        break;
      case AutomationPhase.observing:
        color = Colors.orange;
        icon = Icons.hourglass_top;
        size = 20;
        break;
      case AutomationPhase.refining:
        color = Colors.green;
        icon = Icons.check_circle_outline;
        size = 20;
        break;
      case AutomationPhase.extracting:
        color = Colors.purple;
        icon = Icons.download;
        size = 20;
        break;
      case AutomationPhase.error:
        color = Colors.red;
        icon = Icons.error_outline;
        size = 20;
        break;
      default:
        color = Colors.grey;
        icon = Icons.info_outline;
        size = 20;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (automationState.phase == AutomationPhase.observing ||
              automationState.phase == AutomationPhase.extracting)
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          Icon(
            icon,
            color: color,
            size: size,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusText(AutomationState automationState) {
    String statusText = automationState.statusText;

    return Text(
      statusText.isNotEmpty ? statusText : 'En cours...',
      style: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildProviderInfo(AIProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getProviderIcon(provider),
            color: Colors.white.withOpacity(0.8),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            provider.displayName,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    AutomationState automationState,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Cancel button
        if (automationState.canCancel)
          Expanded(
            child: _buildActionButton(
              context,
              onPressed: () => _cancelAutomation(ref),
              icon: Icons.close,
              label: 'Annuler',
              backgroundColor: Colors.red.withOpacity(0.8),
              textColor: Colors.white,
            ),
          ),

        if (automationState.canCancel && automationState.canValidate)
          const SizedBox(width: 12),

        // Validate button
        if (automationState.canValidate)
          Expanded(
            child: _buildActionButton(
              context,
              onPressed: () => _validateResponse(ref),
              icon: Icons.check,
              label: 'Valider',
              backgroundColor: Colors.green.withOpacity(0.8),
              textColor: Colors.white,
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
      ),
    );
  }

  Color _getBorderColor(AutomationPhase phase) {
    switch (phase) {
      case AutomationPhase.sending:
        return Colors.blue;
      case AutomationPhase.observing:
        return Colors.orange;
      case AutomationPhase.refining:
        return Colors.green;
      case AutomationPhase.extracting:
        return Colors.purple;
      case AutomationPhase.error:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getProviderIcon(AIProvider provider) {
    switch (provider) {
      case AIProvider.aistudio:
        return Icons.auto_awesome;
      case AIProvider.qwen:
        return Icons.cloud;
      case AIProvider.zai:
        return Icons.flash_on;
      case AIProvider.kimi:
        return Icons.document_scanner;
    }
  }

  void _cancelAutomation(WidgetRef ref) {
    ref.read(automationProvider.notifier).cancelAutomation();
  }

  void _validateResponse(WidgetRef ref) {
    ref.read(automationProvider.notifier).validateResponse();
  }
}