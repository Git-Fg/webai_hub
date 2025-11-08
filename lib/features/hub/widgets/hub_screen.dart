import 'dart:async';

import 'package:ai_hybrid_hub/core/providers/talker_provider.dart';
import 'package:ai_hybrid_hub/core/router/app_router.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/scroll_request_provider.dart';
import 'package:ai_hybrid_hub/features/hub/widgets/chat_bubble.dart';
import 'package:ai_hybrid_hub/features/hub/widgets/conversation_history_drawer.dart';
import 'package:ai_hybrid_hub/features/hub/widgets/conversation_settings_sheet.dart';
import 'package:ai_hybrid_hub/shared/ui_constants.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:talker_flutter/talker_flutter.dart';

class HubScreen extends ConsumerStatefulWidget {
  const HubScreen({super.key});

  @override
  ConsumerState<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends ConsumerState<HubScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        unawaited(
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: kShortAnimationDuration,
            curve: Curves.easeOut,
          ),
        );
      }
    });
  }

  void _sendMessage() {
    if (_textController.text.trim().isEmpty) return;

    final message = _textController.text.trim();
    unawaited(
      ref
          .read(conversationActionsProvider.notifier)
          .sendPromptToAutomation(message),
    );
    _textController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    // The provider now returns an AsyncValue<List<Message>>
    final conversationAsync = ref.watch(conversationProvider);

    // Listen for explicit scroll-to-bottom requests (e.g., after extraction)
    ref.listen(scrollToBottomRequestProvider, (previous, next) {
      _scrollToBottom();
    });

    ref.listen<AsyncValue<List<Message>>>(conversationProvider, (
      previous,
      next,
    ) {
      next.maybeWhen(
        data: (conversation) {
          final previousLength =
              previous?.maybeWhen(
                data: (prev) => prev.length,
                orElse: () => 0,
              ) ??
              0;
          if (conversation.length > previousLength) {
            _scrollToBottom();
          }
        },
        orElse: () {},
      );
    });

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      drawer: const ConversationHistoryDrawer(),
      appBar: AppBar(
        title: const Text(
          'AI Hybrid Hub',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue.shade600,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.monitor_heart),
            color: Colors.white,
            tooltip: 'Open Logs',
            onPressed: () {
              unawaited(
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TalkerScreen(
                      talker: ref.read(talkerProvider),
                    ),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            color: Colors.white,
            tooltip: 'Open application settings',
            onPressed: () {
              unawaited(context.router.push(const SettingsRoute()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            color: Colors.white,
            tooltip: 'Open conversation settings',
            onPressed: () {
              unawaited(
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (BuildContext context) {
                    return const ConversationSettingsSheet();
                  },
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            color: Colors.white,
            tooltip: 'Start a new chat',
            onPressed: () {
              unawaited(
                showDialog<void>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Start New Chat?'),
                      content: const Text(
                        'This will clear the current conversation.',
                      ),
                      actions: <Widget>[
                        TextButton(
                          child: const Text('Cancel'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        TextButton(
                          child: const Text('Confirm'),
                          onPressed: () {
                            unawaited(
                              ref
                                  .read(conversationActionsProvider.notifier)
                                  .clearConversation(),
                            );
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            // WHY: Using .when() is the standard, robust way to build UI from an
            // AsyncValue. It forces you to handle all possible states, preventing
            // common errors like trying to access data that hasn't loaded yet.
            child: conversationAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Error: $error'),
              ),
              data: (conversation) {
                if (conversation.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: kLargeIconSize,
                          color: Colors.grey.shade400,
                        ),
                        const Gap(kLargeSpacing),
                        Text(
                          'Welcome to AI Hybrid Hub!',
                          style: TextStyle(
                            fontSize: kMediumFontSize,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const Gap(kDefaultSpacing),
                        Text(
                          'Send your first message to start',
                          style: TextStyle(
                            fontSize: kSmallFontSize,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    vertical: kDefaultPadding,
                  ),
                  itemCount: conversation.length,
                  itemBuilder: (context, index) {
                    return ChatBubble(message: conversation[index]);
                  },
                );
              },
            ),
          ),
          CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.enter): () {
                if (!HardwareKeyboard.instance.isShiftPressed) {
                  _sendMessage();
                }
              },
            },
            child: Container(
              padding: const EdgeInsets.all(kDefaultPadding),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: kDefaultBlurRadius,
                    offset: kTopShadowOffset,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('hub_message_input'),
                      focusNode: _focusNode,
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            kInputBorderRadius,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: kDefaultPadding + kTinyPadding,
                          vertical: kMediumVerticalPadding,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const Gap(kDefaultSpacing),
                  FloatingActionButton(
                    key: const Key('hub_send_button'),
                    tooltip: 'Send message',
                    onPressed: _sendMessage,
                    backgroundColor: Colors.blue.shade600,
                    mini: true,
                    elevation: 2,
                    child: const Icon(
                      Icons.send,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
