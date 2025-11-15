// lib/features/hub/widgets/conversation_history_drawer.dart

import 'package:ai_hybrid_hub/features/hub/providers/active_conversation_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_history_provider.dart';
import 'package:ai_hybrid_hub/features/hub/services/conversation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConversationHistoryDrawer extends ConsumerWidget {
  const ConversationHistoryDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(conversationHistoryProvider);
    final activeId = ref.watch(activeConversationIdProvider);

    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Conversation History',
                style: TextStyle(
                  color: Colors.white,
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
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text('Error: $err'),
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
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No conversations yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a new chat to see it here',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
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
                        color: Colors.red,
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
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
                          ),
                        ),
                        subtitle: Text(dateStr),
                        selected: isActive,
                        selectedTileColor: Colors.blue.shade50,
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
