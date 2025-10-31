import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/app_models.dart';
import '../models/chat_message.dart';
import '../models/providers.dart';
import '../services/selector_service.dart';
import '../services/database_service.dart';
import '../services/prompt_formatter.dart';
import 'dart:convert';

/// Provider for selector configuration
final selectorServiceProvider = Provider<SelectorService>((ref) {
  return SelectorService();
});

/// Provider for all selectors
final selectorsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final selectorService = ref.watch(selectorServiceProvider);
  return await selectorService.getAllSelectors();
});

/// Provider for selected AI provider
final selectedProviderProvider = StateProvider<String>((ref) {
  return Providers.kimi.id; // Default to Kimi
});

/// Provider for provider status map
final providerStatusProvider =
    StateNotifierProvider<ProviderStatusNotifier, Map<String, ProviderStatus>>(
  (ref) => ProviderStatusNotifier(),
);

class ProviderStatusNotifier extends StateNotifier<Map<String, ProviderStatus>> {
  ProviderStatusNotifier() : super({});

  void updateStatus(String providerId, ProviderStatus status) {
    state = {...state, providerId: status};
  }

  ProviderStatus getStatus(String providerId) {
    return state[providerId] ?? ProviderStatus.unknown;
  }
}

/// Provider for overlay UI state
final overlayStateProvider =
    StateNotifierProvider<OverlayStateNotifier, OverlayUIState>(
  (ref) => OverlayStateNotifier(),
);

class OverlayStateNotifier extends StateNotifier<OverlayUIState> {
  OverlayStateNotifier() : super(OverlayUIState.hidden());

  void hide() {
    state = OverlayUIState.hidden();
  }

  void showAutomating() {
    state = OverlayUIState.automating();
  }

  void showWaitingForValidation() {
    state = OverlayUIState.waitingForValidation();
  }

  void showError(String error) {
    state = OverlayUIState.error(error);
  }
}

/// Provider for Hub chat messages
final hubMessagesProvider =
    StateNotifierProvider<HubMessagesNotifier, List<ChatMessage>>(
  (ref) => HubMessagesNotifier(),
);

class HubMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  HubMessagesNotifier() : super([]) {
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final messages = await DatabaseService.getAllMessages();
    state = messages;
  }

  Future<void> addMessage(ChatMessage message) async {
    await DatabaseService.addMessage(message);
    state = [...state, message];
  }

  Future<void> updateMessage(ChatMessage message) async {
    await DatabaseService.updateMessage(message);
    final index = state.indexWhere((m) => m.messageId == message.messageId);
    if (index != -1) {
      final newState = [...state];
      newState[index] = message;
      state = newState;
    }
  }

  Future<ChatMessage?> getMessageById(String messageId) async {
    return await DatabaseService.getMessageByMessageId(messageId);
  }
}

/// Provider for WebView controllers (indexed by provider ID)
final webViewControllersProvider =
    StateProvider<Map<String, InAppWebViewController>>((ref) {
  return {};
});

/// Provider for current tab index
final currentTabIndexProvider = StateProvider<int>((ref) {
  return 0; // Start at Hub tab
});

/// Provider for the workflow orchestrator
final workflowProvider = Provider<WorkflowOrchestrator>((ref) {
  return WorkflowOrchestrator(ref);
});

/// Main workflow orchestrator
class WorkflowOrchestrator {
  final Ref ref;
  String? _currentMessageId;
  String? _currentProvider;

  WorkflowOrchestrator(this.ref);

  /// Start the assisted workflow (Phase 1)
  Future<void> startAssistedWorkflow({
    required String prompt,
    required String providerId,
    Map<String, dynamic>? options,
  }) async {
    try {
      // Get the WebView controller
      final controllers = ref.read(webViewControllersProvider);
      final controller = controllers[providerId];

      if (controller == null) {
        throw Exception('WebView controller not found for $providerId');
      }

      // Get selectors
      final selectorsAsync = ref.read(selectorsProvider);
      if (!selectorsAsync.hasValue) {
        throw Exception('Selectors not loaded yet');
      }
      final allSelectors = selectorsAsync.value!;
      final providerSelectors = allSelectors[providerId];

      // Format the prompt
      final formattedPrompt = PromptFormatter.format(
        userPrompt: prompt,
        // Could add system instructions or context here in the future
      );

      // Create a user message
      final messageId = DateTime.now().millisecondsSinceEpoch.toString();
      _currentMessageId = messageId;
      _currentProvider = providerId;

      final userMessage = ChatMessage()
        ..messageId = messageId
        ..text = prompt
        ..role = MessageRole.user
        ..provider = providerId
        ..createdAt = DateTime.now()
        ..status = MessageStatus.sending;

      await ref.read(hubMessagesProvider.notifier).addMessage(userMessage);

      // Switch to provider tab
      final providerIndex = _getProviderTabIndex(providerId);
      ref.read(currentTabIndexProvider.notifier).state = providerIndex;

      // Show overlay
      ref.read(overlayStateProvider.notifier).showAutomating();

      // Call JavaScript bridge
      final jsCode = '''
        window.hubBridge_$providerId.start(
          ${json.encode(formattedPrompt)},
          ${json.encode(options ?? {})},
          ${json.encode(providerSelectors)}
        );
      ''';

      await controller.evaluateJavascript(source: jsCode);
    } catch (e) {
      ref.read(overlayStateProvider.notifier).showError(e.toString());
      
      if (_currentMessageId != null) {
        final message = await ref.read(hubMessagesProvider.notifier)
            .getMessageById(_currentMessageId!);
        if (message != null) {
          message.status = MessageStatus.failed;
          message.errorMessage = e.toString();
          await ref.read(hubMessagesProvider.notifier).updateMessage(message);
        }
      }
    }
  }

  /// Handle generation complete (Phase 2 → Phase 3)
  void onGenerationComplete() {
    ref.read(overlayStateProvider.notifier).showWaitingForValidation();
  }

  /// Validate and extract response (Phase 4)
  Future<void> validateAndReturn() async {
    if (_currentProvider == null) return;

    try {
      final controllers = ref.read(webViewControllersProvider);
      final controller = controllers[_currentProvider];

      if (controller == null) return;

      // Get selectors
      final selectorsAsync = ref.read(selectorsProvider);
      if (!selectorsAsync.hasValue) return;
      
      final allSelectors = selectorsAsync.value!;
      final providerSelectors = allSelectors[_currentProvider];

      // Call extraction
      final jsCode = '''
        window.hubBridge_$_currentProvider.getFinalResponse(
          ${json.encode(providerSelectors)}
        );
      ''';

      await controller.evaluateJavascript(source: jsCode);
    } catch (e) {
      ref.read(overlayStateProvider.notifier).showError(e.toString());
    }
  }

  /// Handle extracted content
  Future<void> onExtractionResult(String content) async {
    if (_currentMessageId == null) return;

    try {
      // Create assistant message
      final assistantMessage = ChatMessage()
        ..messageId = '${_currentMessageId}_response'
        ..text = content
        ..role = MessageRole.assistant
        ..provider = _currentProvider
        ..createdAt = DateTime.now()
        ..status = MessageStatus.completed;

      await ref.read(hubMessagesProvider.notifier).addMessage(assistantMessage);

      // Update user message status
      final userMessage = await ref.read(hubMessagesProvider.notifier)
          .getMessageById(_currentMessageId!);
      if (userMessage != null) {
        userMessage.status = MessageStatus.completed;
        await ref.read(hubMessagesProvider.notifier).updateMessage(userMessage);
      }

      // Hide overlay
      ref.read(overlayStateProvider.notifier).hide();

      // Switch back to Hub tab
      ref.read(currentTabIndexProvider.notifier).state = 0;

      // Clear current workflow
      _currentMessageId = null;
      _currentProvider = null;
    } catch (e) {
      ref.read(overlayStateProvider.notifier).showError(e.toString());
    }
  }

  /// Cancel the workflow
  Future<void> cancel() async {
    if (_currentProvider == null) return;

    try {
      final controllers = ref.read(webViewControllersProvider);
      final controller = controllers[_currentProvider];

      if (controller != null) {
        await controller.evaluateJavascript(
          source: 'window.hubBridge_$_currentProvider.cancel();',
        );
      }

      // Update message status
      if (_currentMessageId != null) {
        final message = await ref.read(hubMessagesProvider.notifier)
            .getMessageById(_currentMessageId!);
        if (message != null) {
          message.status = MessageStatus.cancelled;
          await ref.read(hubMessagesProvider.notifier).updateMessage(message);
        }
      }

      // Hide overlay
      ref.read(overlayStateProvider.notifier).hide();

      // Clear current workflow
      _currentMessageId = null;
      _currentProvider = null;
    } catch (e) {
      ref.read(overlayStateProvider.notifier).showError(e.toString());
    }
  }

  /// Handle injection failed
  Future<void> onInjectionFailed(String error) async {
    ref.read(overlayStateProvider.notifier).showError(error);

    if (_currentMessageId != null) {
      final message = await ref.read(hubMessagesProvider.notifier)
          .getMessageById(_currentMessageId!);
      if (message != null) {
        message.status = MessageStatus.failed;
        message.errorMessage = error;
        await ref.read(hubMessagesProvider.notifier).updateMessage(message);
      }
    }
  }

  /// Handle status check result
  void onStatusResult(String providerId, String status) {
    final providerStatus = status == 'ready'
        ? ProviderStatus.ready
        : status == 'login'
            ? ProviderStatus.needsLogin
            : ProviderStatus.unknown;

    ref
        .read(providerStatusProvider.notifier)
        .updateStatus(providerId, providerStatus);
  }

  /// Get tab index for provider
  int _getProviderTabIndex(String providerId) {
    // Tab 0: Hub
    // Tab 1: AI Studio
    // Tab 2: Qwen
    // Tab 3: Z-ai
    // Tab 4: Kimi
    switch (providerId) {
      case 'aistudio':
        return 1;
      case 'qwen':
        return 2;
      case 'zai':
        return 3;
      case 'kimi':
        return 4;
      default:
        return 0;
    }
  }
}
