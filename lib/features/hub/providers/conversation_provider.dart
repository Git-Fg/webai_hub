import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/automation_errors.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:ai_hybrid_hub/main.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'conversation_provider.g.dart';

@riverpod
class PendingPrompt extends _$PendingPrompt {
  @override
  String? build() => null;

  void set(String prompt) {
    state = prompt;
  }

  void clear() {
    state = null;
  }
}

@riverpod
class Conversation extends _$Conversation {
  @override
  List<Message> build() => [];

  // ignore: avoid_positional_boolean_parameters, reason: Compact API for widget call sites
  void addMessage(String text, bool isFromUser, {MessageStatus? status}) {
    final message = Message(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      isFromUser: isFromUser,
      status: status ?? MessageStatus.success,
    );
    state = [...state, message];
  }

  void clearConversation() {
    state = [];
    ref
        .read(automationStateProvider.notifier)
        .setStatus(const AutomationStateData.idle());
  }

  Future<void> editAndResendPrompt(String messageId, String newText) async {
    final messageIndex = state.indexWhere((msg) => msg.id == messageId);
    if (messageIndex == -1) return;

    // WHY: Truncate conversation to the edited message (inclusive) to maintain context consistency
    final truncatedConversation = state.sublist(0, messageIndex + 1);

    final editedMessage = truncatedConversation.last.copyWith(text: newText);
    truncatedConversation[messageIndex] = editedMessage;
    state = truncatedConversation;

    await sendPromptToAutomation(
      newText,
      isResend: true,
      excludeMessageId: messageId,
    );
  }

  /// Constructs the prompt with conversation context
  String _buildPromptWithContext(String newPrompt, {String? excludeMessageId}) {
    if (state.isEmpty ||
        state.where((m) => m.status == MessageStatus.success).isEmpty) {
      return newPrompt;
    }

    // WHY: Build context from previous messages, excluding error/sending messages
    final previousMessages = state.where((m) {
      if (m.status != MessageStatus.success) return false;
      if (excludeMessageId != null && m.id == excludeMessageId) return false;
      return true;
    }).toList();

    if (previousMessages.isEmpty) {
      return newPrompt;
    }

    final contextBuffer = StringBuffer();
    for (final message in previousMessages) {
      if (message.isFromUser) {
        contextBuffer.writeln('User: ${message.text}');
      } else {
        contextBuffer.writeln('Assistant: ${message.text}');
      }
      contextBuffer.writeln();
    }

    final fullPrompt = '''
Context from previous conversation:

$contextBuffer
Current message:
User: $newPrompt
''';

    return fullPrompt.trim();
  }

  Future<void> sendPromptToAutomation(
    String prompt, {
    bool isResend = false,
    String? excludeMessageId,
  }) async {
    final promptWithContext =
        _buildPromptWithContext(prompt, excludeMessageId: excludeMessageId);

    // WHY: Store original prompt (without context) to resume after login
    ref.read(pendingPromptProvider.notifier).set(prompt);

    if (!isResend) {
      addMessage(prompt, true);
    }

    final assistantMessage = Message(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: 'Sending...',
      isFromUser: false,
      status: MessageStatus.sending,
    );
    state = [...state, assistantMessage];

    ref
        .read(automationStateProvider.notifier)
        .setStatus(const AutomationStateData.sending());

    if (!ref.mounted) return;

    try {
      // Utilise le provider Riverpod qui EXISTE et FONCTIONNE
      ref.read(currentTabIndexProvider.notifier).changeTo(1);

      // Let Flutter's render cycle complete to build the WebView widget
      // Duration.zero cedes control to the event loop, allowing Flutter to
      // process widget rebuilds (IndexedStack shows WebView, AiWebviewScreen is created)
      await Future<void>.delayed(Duration.zero);

      if (!ref.mounted) return;

      final bridge = ref.read(javaScriptBridgeProvider);

      // Wait for WebView to be created and bridge to be ready
      // This method handles all timing internally (WebView creation + JS bridge ready)
      await bridge.waitForBridgeReady();

      // TIMING: No fixed delay; detection happens on JS side via immediate notification

      if (!ref.mounted) return;

      // Get console logs to debug selector issues (captured before automation starts)
      // Note: getCapturedLogs is only available on JavaScriptBridge, not on interface
      try {
        final jsBridge = bridge as JavaScriptBridge;
        final logs = await jsBridge.getCapturedLogs();
        if (logs.isNotEmpty) {
          debugPrint(
            '[ConversationProvider] JS Logs before automation: ${logs.map((log) => log['args']).toList()}',
          );
        }
      } on Object catch (_) {
        // Ignore cast errors in tests - FakeJavaScriptBridge doesn't extend JavaScriptBridge
      }

      await bridge.startAutomation(promptWithContext);

      if (ref.mounted) {
        _updateLastMessage(
          'Assistant is responding in the WebView...',
          MessageStatus.sending,
        );

        ref.read(automationStateProvider.notifier).setStatus(
              const AutomationStateData.observing(),
            );

        await bridge.startResponseObserver();
      }
    } on Object catch (e) {
      if (ref.mounted) {
        String errorMessage;
        if (e is AutomationError) {
          errorMessage = 'Error: ${e.message} (Code: ${e.errorCode.name})';
        } else {
          errorMessage = 'An unexpected error occurred: $e';
        }

        _updateLastMessage(errorMessage, MessageStatus.error);
        ref
            .read(automationStateProvider.notifier)
            .setStatus(const AutomationStateData.failed());
      }
    }
  }

  // Extract and return to Hub without finalizing automation
  Future<void> extractAndReturnToHub() async {
    final bridge = ref.read(javaScriptBridgeProvider);
    ref.read(isExtractingProvider.notifier).state = true;

    try {
      final responseText = await bridge.extractFinalResponse();

      // WHY: If we reach here, extraction succeeded even if non-critical errors were logged on JS side.
      // The important thing is that the Promise returned a value.
      if (ref.mounted) {
        _updateLastMessage(responseText, MessageStatus.success);
        ref.read(pendingPromptProvider.notifier).clear();
        ref.read(currentTabIndexProvider.notifier).changeTo(0);
      }
    } on Object catch (e) {
      // WHY: If we reach here, a REAL exception was thrown, preventing the Promise from returning a value
      if (ref.mounted) {
        String errorMessage;
        if (e is AutomationError) {
          errorMessage =
              'Extraction Error: ${e.message} (Code: ${e.errorCode.name})';
        } else {
          errorMessage = 'Failed to extract response: $e';
        }
        _updateLastMessage(errorMessage, MessageStatus.error);
        // WHY: Set failed state ONLY if extraction fails
        ref.read(automationStateProvider.notifier).setStatus(
              const AutomationStateData.failed(),
            );
      }
    } finally {
      // WHY: This block executes after try OR catch, ensuring loading indicator is always disabled
      if (ref.mounted) {
        ref.read(isExtractingProvider.notifier).state = false;
      }
    }
  }

  // Finalize automation and return to Hub
  void finalizeAutomation() {
    ref
        .read(automationStateProvider.notifier)
        .setStatus(const AutomationStateData.idle());
    ref.read(currentTabIndexProvider.notifier).changeTo(0);
  }

  void cancelAutomation() {
    _updateLastMessage('Automation cancelled by user', MessageStatus.error);
    ref
        .read(automationStateProvider.notifier)
        .setStatus(const AutomationStateData.idle());

    ref.read(currentTabIndexProvider.notifier).changeTo(0);
  }

  void onAutomationFailed(String error) {
    _updateLastMessage('Automation failed: $error', MessageStatus.error);
    ref
        .read(automationStateProvider.notifier)
        .setStatus(const AutomationStateData.failed());
  }

  Future<void> resumeAutomationAfterLogin() async {
    final pendingPrompt = ref.read(pendingPromptProvider);
    if (pendingPrompt == null) {
      ref
          .read(automationStateProvider.notifier)
          .setStatus(const AutomationStateData.idle());
      return;
    }

    // WHY: Rebuild prompt with context (conversation may have changed)
    final promptWithContext = _buildPromptWithContext(pendingPrompt);

    _updateLastMessage(
      'Resuming automation after login...',
      MessageStatus.sending,
    );

    ref
        .read(automationStateProvider.notifier)
        .setStatus(const AutomationStateData.sending());

    if (!ref.mounted) return;

    try {
      final bridge = ref.read(javaScriptBridgeProvider);

      // WHY: Wait for bridge to be ready (WebView may have been reloaded)
      await bridge.waitForBridgeReady();

      if (!ref.mounted) return;

      // WHY: Let startAutomation detect login page again if necessary
      await bridge.startAutomation(promptWithContext);

      if (ref.mounted) {
        _updateLastMessage(
          'Assistant is responding in the WebView...',
          MessageStatus.sending,
        );

        ref.read(automationStateProvider.notifier).setStatus(
              AutomationStateData.refining(
                messageCount: state.length,
              ),
            );
      }
    } on Object catch (e) {
      if (ref.mounted) {
        String errorMessage;
        if (e is AutomationError) {
          errorMessage = 'Error: ${e.message} (Code: ${e.errorCode.name})';
        } else {
          errorMessage = 'An unexpected error occurred: $e';
        }

        _updateLastMessage(errorMessage, MessageStatus.error);
        ref
            .read(automationStateProvider.notifier)
            .setStatus(const AutomationStateData.failed());
      }
    }
  }

  void _updateLastMessage(String text, MessageStatus status) {
    if (!ref.mounted) return;

    if (state.isNotEmpty) {
      final lastMessage = state.last;
      if (!lastMessage.isFromUser &&
          lastMessage.status == MessageStatus.sending) {
        final newMessages = List<Message>.from(state);
        newMessages[newMessages.length - 1] = lastMessage.copyWith(
          text: text,
          status: status,
        );
        state = newMessages;
      }
    }
  }
}
