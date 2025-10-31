import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/ai_provider.dart';
import '../../shared/models/conversation.dart';
import '../../shared/models/automation_state.dart';
import '../utils/javascript_bridge.dart';
import '../utils/prompt_formatter.dart';
import '../../features/hub/providers/conversation_provider.dart';
import '../../features/hub/providers/provider_status_provider.dart';
import '../../features/webview/providers/webview_provider.dart';
import '../../features/automation/providers/automation_provider.dart';

/// Orchestrates the complete "Assister & Valider" workflow
class WorkflowOrchestrator {
  final Ref ref;
  final Map<AIProvider, JavaScriptBridge> bridges;

  WorkflowOrchestrator({
    required this.ref,
    required this.bridges,
  });

  /// Execute the complete workflow
  Future<bool> executeWorkflow({
    required AIProvider provider,
    required String prompt,
    Map<String, dynamic>? options,
    List<String>? contextFiles,
  }) async {
    try {
      debugPrint('WorkflowOrchestrator: Starting workflow for ${provider.displayName}');

      // Phase 1: Preparation
      if (!_prepareWorkflow(provider, prompt)) return false;

      // Phase 2: Navigate to provider tab
      if (!await _navigateToProvider(provider)) return false;

      // Phase 3: Start automation
      if (!await _startAutomation(provider, prompt, options, contextFiles)) return false;

      debugPrint('WorkflowOrchestrator: Workflow started successfully');
      return true;
    } catch (e) {
      debugPrint('WorkflowOrchestrator: Workflow failed: $e');
      _handleError(e.toString());
      return false;
    }
  }

  /// Prepare workflow by setting up state
  bool _prepareWorkflow(AIProvider provider, String prompt) {
    try {
      // Update automation state
      ref.read(automationProvider.notifier).startAutomation(
        provider: provider,
        prompt: prompt,
        options: {},
      );

      // Update provider status
      ref.read(providerStatusProvider.notifier).markProviderInAutomation(provider);

      debugPrint('WorkflowOrchestrator: Preparation completed');
      return true;
    } catch (e) {
      debugPrint('WorkflowOrchestrator: Preparation failed: $e');
      return false;
    }
  }

  /// Navigate to provider tab
  Future<bool> _navigateToProvider(AIProvider provider) async {
    try {
      // This would typically involve switching to the provider tab
      // For now, we assume the tab switching is handled by the UI
      debugPrint('WorkflowOrchestrator: Navigation to ${provider.displayName} completed');
      return true;
    } catch (e) {
      debugPrint('WorkflowOrchestrator: Navigation failed: $e');
      return false;
    }
  }

  /// Start automation on the provider
  Future<bool> _startAutomation(
    AIProvider provider,
    String prompt,
    Map<String, dynamic>? options,
    List<String>? contextFiles,
  ) async {
    try {
      final bridge = bridges[provider];
      if (bridge == null) {
        throw Exception('No bridge available for ${provider.displayName}');
      }

      // Format the prompt
      final formattedPrompt = PromptFormatter.formatPrompt(
        prompt: prompt,
        contextFiles: contextFiles ?? [],
        options: options ?? {},
      );

      debugPrint('WorkflowOrchestrator: Starting automation with formatted prompt');

      // Start the automation
      await bridge.startAutomation(formattedPrompt, options ?? {});

      debugPrint('WorkflowOrchestrator: Automation started');
      return true;
    } catch (e) {
      debugPrint('WorkflowOrchestrator: Automation start failed: $e');
      return false;
    }
  }

  /// Handle automation success
  void handleAutomationSuccess(AIProvider provider) {
    debugPrint('WorkflowOrchestrator: Automation completed successfully');
    ref.read(automationProvider.notifier).onGenerationCompleted();
  }

  /// Handle automation failure
  void handleAutomationFailure(AIProvider provider, String error) {
    debugPrint('WorkflowOrchestrator: Automation failed: $error');
    ref.read(automationProvider.notifier).onAutomationFailed(error);
    ref.read(providerStatusProvider.notifier).clearProviderAutomation(provider);
  }

  /// Handle response extraction
  Future<String?> extractResponse(AIProvider provider) async {
    try {
      final bridge = bridges[provider];
      if (bridge == null) {
        throw Exception('No bridge available for ${provider.displayName}');
      }

      debugPrint('WorkflowOrchestrator: Extracting response from ${provider.displayName}');

      final response = await bridge.extractResponse();

      if (response != null && response.isNotEmpty) {
        debugPrint('WorkflowOrchestrator: Response extracted successfully');
        return response;
      } else {
        throw Exception('No response content extracted');
      }
    } catch (e) {
      debugPrint('WorkflowOrchestrator: Response extraction failed: $e');
      return null;
    }
  }

  /// Validate and complete workflow
  Future<bool> validateAndComplete({
    required AIProvider provider,
    required String conversationId,
    required String messageId,
  }) async {
    try {
      debugPrint('WorkflowOrchestrator: Validating and completing workflow');

      // Extract the response
      final response = await extractResponse(provider);
      if (response == null) {
        throw Exception('Failed to extract response');
      }

      // Update conversation with the response
      ref.read(conversationProvider.notifier).updateMessage(
        conversationId,
        messageId,
        response,
        MessageStatus.completed,
      );

      // Complete the automation
      ref.read(automationProvider.notifier).completeAutomation();
      ref.read(providerStatusProvider.notifier).clearProviderAutomation(provider);

      debugPrint('WorkflowOrchestrator: Workflow completed successfully');
      return true;
    } catch (e) {
      debugPrint('WorkflowOrchestrator: Validation/completion failed: $e');
      handleAutomationFailure(provider, e.toString());
      return false;
    }
  }

  /// Cancel current workflow
  void cancelWorkflow(AIProvider provider) {
    try {
      debugPrint('WorkflowOrchestrator: Canceling workflow for ${provider.displayName}');

      final bridge = bridges[provider];
      if (bridge != null) {
        bridge.cancelAutomation();
      }

      ref.read(automationProvider.notifier).cancelAutomation();
      ref.read(providerStatusProvider.notifier).clearProviderAutomation(provider);

      debugPrint('WorkflowOrchestrator: Workflow canceled');
    } catch (e) {
      debugPrint('WorkflowOrchestrator: Cancel failed: $e');
    }
  }

  /// Handle errors
  void _handleError(String error) {
    ref.read(automationProvider.notifier).onAutomationFailed(error);
  }

  /// Check if workflow can be started
  bool canStartWorkflow(AIProvider provider) {
    final automationState = ref.read(automationProvider);
    final bridge = bridges[provider];

    return !automationState.isActive &&
           bridge != null &&
           ref.read(webviewReadyProvider(provider));
  }

  /// Get current workflow status
  WorkflowStatus getWorkflowStatus() {
    final automationState = ref.read(automationProvider);

    switch (automationState.phase) {
      case AutomationPhase.idle:
        return WorkflowStatus.idle;
      case AutomationPhase.sending:
        return WorkflowStatus.sending;
      case AutomationPhase.observing:
        return WorkflowStatus.observing;
      case AutomationPhase.refining:
        return WorkflowStatus.refining;
      case AutomationPhase.extracting:
        return WorkflowStatus.extracting;
      case AutomationPhase.error:
        return WorkflowStatus.error;
    }
  }
}

/// Workflow status enumeration
enum WorkflowStatus {
  idle,
  sending,
  observing,
  refining,
  extracting,
  error,
}

/// Provider for workflow orchestrator
final workflowOrchestratorProvider = Provider<WorkflowOrchestrator>(
  (ref) {
    // Get all available bridges
    final bridges = <AIProvider, JavaScriptBridge>{};

    for (final provider in AIProvider.values) {
      final bridge = ref.read(javascriptBridgeProvider(provider));
      if (bridge != null) {
        bridges[provider] = bridge;
      }
    }

    return WorkflowOrchestrator(
      ref: ref,
      bridges: bridges,
    );
  },
);

/// Convenience providers
final workflowStatusProvider = Provider<WorkflowStatus>(
  (ref) {
    final orchestrator = ref.watch(workflowOrchestratorProvider);
    return orchestrator.getWorkflowStatus();
  },
);

final canStartWorkflowProvider = Provider.family<bool, AIProvider>(
  (ref, provider) {
    final orchestrator = ref.watch(workflowOrchestratorProvider);
    return orchestrator.canStartWorkflow(provider);
  },
);