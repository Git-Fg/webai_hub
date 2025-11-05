import 'dart:developer';

import 'package:ai_hybrid_hub/core/providers/provider_config_provider.dart';
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_settings_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/ephemeral_message_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/scroll_request_provider.dart';
import 'package:ai_hybrid_hub/features/settings/providers/general_settings_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/automation_errors.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:ai_hybrid_hub/features/webview/webview_constants.dart';
import 'package:ai_hybrid_hub/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:xml/xml.dart';

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

  /// Helper to build the <system> XML node as a string fragment.
  String _buildSystemPromptXml(String systemPrompt) {
    final builder = XmlBuilder();
    builder.element(
      'system',
      nest: () {
        builder.cdata(systemPrompt);
      },
    );
    return builder.buildDocument().toXmlString(pretty: true);
  }

  /// Helper to build the <history> XML node as a string fragment.
  String _buildHistoryXml(List<Message> history) {
    final builder = XmlBuilder();
    builder.element(
      'history',
      nest: () {
        for (var i = 0; i < history.length;) {
          if (history[i].isFromUser) {
            final userMessage = history[i];
            final assistantMessage =
                (i + 1 < history.length && !history[i + 1].isFromUser)
                    ? history[i + 1]
                    : null;

            builder.element(
              'turn',
              nest: () {
                builder.element(
                  'user',
                  nest: () => builder.cdata(userMessage.text),
                );
                if (assistantMessage != null) {
                  builder.element(
                    'assistant',
                    nest: () => builder.cdata(assistantMessage.text),
                  );
                }
              },
            );

            i += (assistantMessage != null) ? 2 : 1;
          } else {
            // Skip orphaned assistant messages
            i++;
          }
        }
      },
    );
    return builder.buildDocument().toXmlString(pretty: true);
  }

  void clearConversation() {
    state = [];
    ref.read(automationStateProvider.notifier).returnToIdle();
    // WHY: When a new chat starts, we reset its specific settings to default.
    ref.invalidate(conversationSettingsProvider);
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

  // Preserve the current text-based prompt as the simple fallback
  String _buildSimplePrompt(String newPrompt, {String? excludeMessageId}) {
    final settings = ref.read(conversationSettingsProvider);
    final systemPrompt = settings.systemPrompt;

    if (state.isEmpty ||
        state.where((m) => m.status == MessageStatus.success).isEmpty) {
      return systemPrompt.isNotEmpty
          ? '$systemPrompt\n\nUser: $newPrompt'
          : newPrompt;
    }

    final previousMessages = state.where((m) {
      if (m.status != MessageStatus.success) return false;
      if (excludeMessageId != null && m.id == excludeMessageId) return false;
      return true;
    }).toList();

    if (previousMessages.isEmpty) {
      return systemPrompt.isNotEmpty
          ? '$systemPrompt\n\nUser: $newPrompt'
          : newPrompt;
    }

    final contextBuffer = StringBuffer();
    if (systemPrompt.isNotEmpty) {
      contextBuffer.writeln(systemPrompt);
      contextBuffer.writeln();
    }
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

  String _buildXmlPrompt(String newPrompt, {String? excludeMessageId}) {
    try {
      final settings = ref.read(conversationSettingsProvider);
      final systemPrompt = settings.systemPrompt;
      final providerConfig = ref.read(currentProviderConfigurationProvider);

      final history = state
          .where(
            (m) =>
                m.id != excludeMessageId && m.status == MessageStatus.success,
          )
          .toList();

      final shouldInjectSystemPrompt =
          systemPrompt.isNotEmpty && !providerConfig.supportsNativeSystemPrompt;

      // WHY: Use StringBuffer for efficient string concatenation to build the template.
      final promptBuffer = StringBuffer();

      // --- Part 1: Initial Instruction ---
      promptBuffer.writeln(newPrompt);
      if (shouldInjectSystemPrompt) {
        promptBuffer.writeln(_buildSystemPromptXml(systemPrompt));
      }

      // --- Part 2: Context ---
      if (history.isNotEmpty) {
        promptBuffer.writeln(_buildHistoryXml(history));
      }
      // Future <files> context would be added here.

      // --- Part 3: Repeated Instruction for Focus ---
      promptBuffer.writeln(newPrompt);
      if (shouldInjectSystemPrompt) {
        promptBuffer.writeln(_buildSystemPromptXml(systemPrompt));
      }

      final finalPrompt = promptBuffer.toString().trim();
      log('Generated Prompt Template:\n---\n$finalPrompt\n---');
      return finalPrompt;
    } on XmlException catch (e) {
      log(
        'XML fragment build error: ${e.message}. Falling back to simple prompt.',
        error: e,
      );
      // WHY: On any XML failure, we fall back to the reliable simple prompt.
      return _buildSimplePrompt(newPrompt, excludeMessageId: excludeMessageId);
    }
  }

  /// Constructs the prompt with conversation context via selected strategy
  String _buildPromptWithContext(String newPrompt, {String? excludeMessageId}) {
    final settingsAsync = ref.read(generalSettingsProvider);
    final useAdvanced = settingsAsync.maybeWhen(
      data: (s) => s.useAdvancedPrompting,
      // WHY: Default to simple prompting until settings are loaded to avoid
      // impacting tests and first-frame behavior.
      orElse: () => false,
    );
    if (useAdvanced) {
      return _buildXmlPrompt(newPrompt, excludeMessageId: excludeMessageId);
    } else {
      return _buildSimplePrompt(newPrompt, excludeMessageId: excludeMessageId);
    }
  }

  Future<void> _orchestrateAutomation(
    String promptForContext, {
    bool isResend = false,
    String? excludeMessageId,
  }) async {
    final promptWithContext = _buildPromptWithContext(
      promptForContext,
      excludeMessageId: excludeMessageId,
    );

    // WHY: Store original prompt (without context) to resume after login
    ref.read(pendingPromptProvider.notifier).set(promptForContext);

    if (!isResend) {
      addMessage(promptForContext, true);
    }

    final assistantMessage = Message(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: 'Sending...',
      isFromUser: false,
      status: MessageStatus.sending,
    );
    state = [...state, assistantMessage];

    ref.read(automationStateProvider.notifier).moveToSending();

    if (!ref.mounted) return;

    try {
      final bridge = ref.read(javaScriptBridgeProvider);
      final webViewController = ref.read(webViewControllerProvider);

      // Switch to the WebView tab
      ref.read(currentTabIndexProvider.notifier).changeTo(1);

      // TIMING: Yield to event loop to ensure widget tree updates before WebView reload
      await Future<void>.delayed(Duration.zero);

      if (!ref.mounted) return;

      // CRITICAL: Reload the WebView to get a clean slate, per blueprint.
      // This ensures each new turn is isolated and prevents context leaks.
      await webViewController?.loadUrl(
        urlRequest: URLRequest(url: WebUri(WebViewConstants.aiStudioUrl)),
      );

      // TIMING: 2s delay after loadUrl is required to give the WebView time to
      // initiate the page request before bridge readiness polling begins.
      // Per BLUEPRINT_MVP.md, this mitigates [PAGENOTLOADED] startup races.
      // This delay is necessary for the workflow to function correctly.
      await Future<void>.delayed(const Duration(seconds: 2));

      // WHY: We now rely entirely on waitForBridgeReady.
      // This function polls until the onLoadStop event has fired, the script has been injected,
      // and the JS side has signaled back that it's ready. This is the most robust method.
      await bridge.waitForBridgeReady();

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

      // Start the automation with the full contextual prompt.
      await bridge.startAutomation(promptWithContext);

      if (ref.mounted) {
        _updateLastMessage(
          'Assistant is responding in the WebView...',
          MessageStatus.sending,
        );

        ref.read(automationStateProvider.notifier).moveToObserving();

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
        ref.read(automationStateProvider.notifier).moveToFailed();
      }
    }
  }

  Future<void> sendPromptToAutomation(
    String prompt, {
    bool isResend = false,
    String? excludeMessageId,
  }) async {
    await _orchestrateAutomation(
      prompt,
      isResend: isResend,
      excludeMessageId: excludeMessageId,
    );
  }

  // Extract and return to Hub without finalizing automation
  Future<void> extractAndReturnToHub() async {
    final bridge = ref.read(javaScriptBridgeProvider);
    ref.read(isExtractingProvider.notifier).state = true;
    // WHY: Clear any previous error message when a new extraction attempt starts.
    ref.read(ephemeralMessageProvider.notifier).clearMessage();

    try {
      final responseText = await bridge.extractFinalResponse();

      // WHY: If we reach here, extraction succeeded even if non-critical errors were logged on JS side.
      // The important thing is that the Promise returned a value.
      if (ref.mounted) {
        _updateLastMessage(responseText, MessageStatus.success);
        ref.read(pendingPromptProvider.notifier).clear();
        ref.read(currentTabIndexProvider.notifier).changeTo(0);
        // Signal UI to scroll to bottom after successful extraction
        ref.read(scrollToBottomRequestProvider.notifier).requestScroll();
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
        // Post to ephemeral provider instead of updating last message or failing automation
        ref.read(ephemeralMessageProvider.notifier).setMessage(errorMessage);
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
    ref.read(ephemeralMessageProvider.notifier).clearMessage();
    ref.read(automationStateProvider.notifier).returnToIdle();
    ref.read(currentTabIndexProvider.notifier).changeTo(0);
  }

  void cancelAutomation() {
    _updateLastMessage('Automation cancelled by user', MessageStatus.error);
    ref.read(automationStateProvider.notifier).returnToIdle();

    ref.read(currentTabIndexProvider.notifier).changeTo(0);
  }

  void onAutomationFailed(String error) {
    _updateLastMessage('Automation failed: $error', MessageStatus.error);
    ref.read(automationStateProvider.notifier).moveToFailed();
  }

  Future<void> resumeAutomationAfterLogin() async {
    final pendingPrompt = ref.read(pendingPromptProvider);
    if (pendingPrompt == null) {
      ref.read(automationStateProvider.notifier).returnToIdle();
      return;
    }

    // WHY: Rebuild prompt with context (conversation may have changed)
    final promptWithContext = _buildPromptWithContext(pendingPrompt);

    _updateLastMessage(
      'Resuming automation after login...',
      MessageStatus.sending,
    );

    ref.read(automationStateProvider.notifier).moveToSending();

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

        ref
            .read(automationStateProvider.notifier)
            .moveToRefining(messageCount: state.length);
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
        ref.read(automationStateProvider.notifier).moveToFailed();
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
