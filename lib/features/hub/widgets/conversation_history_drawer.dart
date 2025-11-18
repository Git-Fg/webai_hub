// lib/features/hub/widgets/conversation_history_drawer.dart

import 'package:ai_hybrid_hub/core/theme/theme_facade.dart';
import 'package:ai_hybrid_hub/features/hub/providers/active_conversation_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_history_provider.dart';
import 'package:ai_hybrid_hub/features/hub/services/conversation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConversationHistoryDrawer extends ConsumerWidget {
  const ConversationHistoryDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.hubTheme;
    final historyAsync = ref.watch(conversationHistoryProvider);
    final activeId = ref.watch(activeConversationIdProvider);

    return Drawer(
      backgroundColor: theme.surfaceColor,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: theme.sendButtonColor,
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Conversation History',
                style: TextStyle(
                  color: theme.drawerHeaderTextColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: theme.messageErrorColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error: $err',
                      style: TextStyle(color: theme.onSurfaceColor),
                    ),
                  ],
                ),
              ),
              data: (conversations) {
                if (conversations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: theme.dividerColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No conversations yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: theme.onSurfaceColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a new chat to see it here',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.dividerColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];
                    final isActive = conversation.id == activeId;
                    final updatedAt = conversation.updatedAt.toLocal();
                    final dateStr =
                        '${updatedAt.month}/${updatedAt.day}/${updatedAt.year} • ${updatedAt.hour}:${updatedAt.minute.toString().padLeft(2, '0')}';

                    return Dismissible(
                      key: Key('conversation_${conversation.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: theme.messageErrorColor,
                        child: Icon(
                          Icons.delete,
                          color: theme.drawerHeaderIconColor,
                        ),
                      ),
                      onDismissed: (direction) async {
                        await ref
                            .read(conversationServiceProvider.notifier)
                            .deleteConversation(conversation.id);
                        // If we deleted the active conversation, clear it
                        if (isActive) {
                          ref
                              .read(activeConversationIdProvider.notifier)
                              .set(null);
                        }
                      },
                      child: ListTile(
                        title: Text(
                          conversation.title,
                          style: TextStyle(
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: theme.onSurfaceColor,
                          ),
                        ),
                        subtitle: Text(
                          dateStr,
                          style: TextStyle(color: theme.dividerColor),
                        ),
                        selected: isActive,
                        selectedTileColor:
                            theme.incomingBubbleDecoration?.color,
                        onTap: () {
                          // This single line changes the active conversation.
                          ref
                              .read(activeConversationIdProvider.notifier)
                              .set(conversation.id);
                          Navigator.of(context).pop(); // Close the drawer
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
