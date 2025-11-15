import 'dart:async';

import 'package:ai_hybrid_hub/core/providers/talker_provider.dart';
import 'package:ai_hybrid_hub/core/router/app_router.dart';
import 'package:ai_hybrid_hub/core/theme/theme_facade.dart';
import 'package:ai_hybrid_hub/features/hub/providers/active_conversation_details_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/active_conversation_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/scroll_request_provider.dart';
import 'package:ai_hybrid_hub/features/hub/widgets/chat_bubble.dart';
import 'package:ai_hybrid_hub/features/hub/widgets/conversation_history_drawer.dart';
import 'package:ai_hybrid_hub/features/hub/widgets/curation_panel.dart';
import 'package:ai_hybrid_hub/features/hub/widgets/hub_input_bar.dart';
import 'package:ai_hybrid_hub/shared/ui_constants.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:talker_flutter/talker_flutter.dart';

class HubScreen extends ConsumerStatefulWidget {
  const HubScreen({super.key});

  @override
  ConsumerState<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends ConsumerState<HubScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final theme = context.hubTheme;
    // The provider now returns an AsyncValue<List<Message>>
    final conversationAsync = ref.watch(conversationProvider);

    // Listen for explicit scroll-to-bottom requests (e.g., after extraction)
    ref.listen(scrollToBottomRequestProvider, (previous, next) {
      _scrollToBottom();
    });

    return Scaffold(
      backgroundColor: theme.surfaceColor,
      drawer: const ConversationHistoryDrawer(),
      appBar: AppBar(
        title: const Text(
          'AI Hybrid Hub',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: theme.sendButtonColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.notes),
            color: Colors.white,
            tooltip: 'Set System Prompt',
            onPressed: () {
              final activeId = ref.read(activeConversationIdProvider);
              if (activeId != null) {
                unawaited(_showSystemPromptDialog(context, ref, activeId));
              }
            },
          ),
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
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await Future<void>.delayed(
                              const Duration(milliseconds: 300),
                            );
                            if (context.mounted) {
                              await ref
                                  .read(conversationActionsProvider.notifier)
                                  .clearConversation();
                            }
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
                  // WHY: Expanded already provides unbounded constraints, so Center can fill the space
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
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
          const CurationPanel(),
          const HubInputBar(),
        ],
      ),
    );
  }

  Future<void> _showSystemPromptDialog(
    BuildContext context,
    WidgetRef ref,
    int conversationId,
  ) async {
    final controller = TextEditingController();

    // Load initial text from provider
    final conversationDetailsAsync = ref.read(
      activeConversationDetailsProvider,
    );
    conversationDetailsAsync.whenData((conv) {
      controller.text = conv?.systemPrompt ?? '';
    });

    await showDialog<void>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final convAsync = ref.watch(activeConversationDetailsProvider);
          convAsync.whenData((conv) {
            if (controller.text.isEmpty) {
              controller.text = conv?.systemPrompt ?? '';
            }
          });

          return AlertDialog(
            title: const Text('System Prompt'),
            content: TextField(
              controller: controller,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'e.g., You are an expert Flutter developer...',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  unawaited(
                    ref
                        .read(conversationActionsProvider.notifier)
                        .updateSystemPrompt(controller.text),
                  );
                  Navigator.of(context).pop();
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
