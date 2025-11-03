import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/common/widgets/loading_indicator.dart';

class ChatBubble extends ConsumerWidget {
  final Message message;

  const ChatBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // On n'autorise l'édition que si c'est un message de l'utilisateur
    // et qu'il n'y a pas d'automatisation en cours.
    final isEditable = message.isFromUser &&
        ref.watch(automationStateProvider) == AutomationStatus.idle;

    return GestureDetector(
      onTap: isEditable
          ? () {
              _showEditDialog(context, ref, message);
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: Row(
          mainAxisAlignment: message.isFromUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (!message.isFromUser) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.blue.shade100,
                child: Icon(
                  Icons.smart_toy,
                  size: 20,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: message.isFromUser
                      ? Colors.blue.shade500
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20).copyWith(
                    bottomLeft: Radius.circular(message.isFromUser ? 20 : 4),
                    bottomRight: Radius.circular(message.isFromUser ? 4 : 20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.text,
                      style: TextStyle(
                        color:
                            message.isFromUser ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                    if (message.status == MessageStatus.sending)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LoadingIndicator(
                              size: 12,
                              color: message.isFromUser
                                  ? Colors.white70
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Sending...',
                              style: TextStyle(
                                fontSize: 12,
                                color: message.isFromUser
                                    ? Colors.white70
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (message.status == MessageStatus.error)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 12,
                              color: message.isFromUser
                                  ? Colors.red.shade200
                                  : Colors.red.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Error',
                              style: TextStyle(
                                fontSize: 12,
                                color: message.isFromUser
                                    ? Colors.red.shade200
                                    : Colors.red.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (message.isFromUser) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.green.shade100,
                child: Icon(
                  Icons.person,
                  size: 20,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Message message) {
    final textController = TextEditingController(text: message.text);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Prompt'),
          content: TextField(
            controller: textController,
            autofocus: true,
            maxLines: null,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newText = textController.text.trim();
                if (newText.isNotEmpty && newText != message.text) {
                  ref
                      .read(conversationProvider.notifier)
                      .editAndResendPrompt(message.id, newText);
                }
                Navigator.of(context).pop();
              },
              child: const Text('Save & Resend'),
            ),
          ],
        );
      },
    );
  }
}
