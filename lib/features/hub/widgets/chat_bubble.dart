import 'dart:async';
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/common/widgets/loading_indicator.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';
import 'package:ai_hybrid_hub/shared/ui_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatBubble extends ConsumerWidget {
  const ChatBubble({
    required this.message,
    super.key,
  });
  final Message message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // WHY: Only allow editing for user messages when automation is idle
    final isEditable = message.isFromUser &&
        ref.watch(automationStateProvider) == const AutomationStateData.idle();

    // This user-friendly label describes the content and the available action.
    final semanticLabel = message.isFromUser
        ? 'Your message: ${message.text}. ${isEditable ? 'Tap to edit and resend.' : ''}'
        : 'Assistant message: ${message.text}';

    return Semantics(
      label: semanticLabel,
      button: isEditable,
      child: GestureDetector(
        onTap: isEditable
            ? () {
                _showEditDialog(context, ref, message);
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: kDefaultPadding,
            vertical: kTinyPadding,
          ),
          child: Row(
            mainAxisAlignment: message.isFromUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!message.isFromUser) ...[
                CircleAvatar(
                  radius: kMediumIconSize,
                  backgroundColor: Colors.blue.shade100,
                  child: Icon(
                    Icons.smart_toy,
                    size: kDefaultIconSize,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: kDefaultSpacing),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kDefaultPadding,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: message.isFromUser
                        ? Colors.blue.shade500
                        : Colors.grey.shade200,
                    borderRadius:
                        BorderRadius.circular(kDefaultBorderRadius).copyWith(
                      bottomLeft: Radius.circular(
                        message.isFromUser
                            ? kDefaultBorderRadius
                            : kChatBubbleSmallRadius,
                      ),
                      bottomRight: Radius.circular(
                        message.isFromUser
                            ? kChatBubbleSmallRadius
                            : kDefaultBorderRadius,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: kSmallBlurRadius,
                        offset: kDefaultShadowOffset,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: TextStyle(
                          color: message.isFromUser
                              ? Colors.white
                              : Colors.black87,
                          fontSize: kDefaultTextFontSize,
                        ),
                      ),
                      if (message.status == MessageStatus.sending)
                        Padding(
                          padding: const EdgeInsets.only(top: kTinyPadding),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              LoadingIndicator(
                                size: kTinyFontSize,
                                color: message.isFromUser
                                    ? Colors.white70
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Sending...',
                                style: TextStyle(
                                  fontSize: kTinyFontSize,
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
                          padding: const EdgeInsets.only(top: kTinyPadding),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: kTinyFontSize,
                                color: message.isFromUser
                                    ? Colors.red.shade200
                                    : Colors.red.shade600,
                              ),
                              const SizedBox(width: kTinyPadding),
                              Text(
                                'Error',
                                style: TextStyle(
                                  fontSize: kTinyFontSize,
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
                const SizedBox(width: kDefaultSpacing),
                CircleAvatar(
                  radius: kMediumIconSize,
                  backgroundColor: Colors.green.shade100,
                  child: Icon(
                    Icons.person,
                    size: kDefaultIconSize,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Message message) {
    final textController = TextEditingController(text: message.text);
    unawaited(
      showDialog<void>(
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
                    unawaited(
                      ref
                          .read(conversationProvider.notifier)
                          .editAndResendPrompt(message.id, newText),
                    );
                  }
                  Navigator.of(context).pop();
                },
                child: const Text('Save & Resend'),
              ),
            ],
          );
        },
      ),
    );
  }
}
