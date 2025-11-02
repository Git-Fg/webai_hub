import 'package:flutter/material.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';

class ChatBubble extends StatelessWidget {
  final Message message;

  const ChatBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
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
                      color: message.isFromUser ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  if (message.status == MessageStatus.sending)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                message.isFromUser
                                    ? Colors.white70
                                    : Colors.grey.shade600,
                              ),
                            ),
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
    );
  }
}
