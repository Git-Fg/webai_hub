import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/common/widgets/loading_indicator.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/selected_message_provider.dart';
import 'package:ai_hybrid_hub/shared/ui_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

class ChatBubble extends ConsumerStatefulWidget {
  const ChatBubble({
    required this.message,
    super.key,
  });
  final Message message;

  @override
  ConsumerState<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends ConsumerState<ChatBubble> {
  bool _isEditing = false;
  late final TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.message.text);
  }

  @override
  void didUpdateWidget(covariant ChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message.text != oldWidget.message.text) {
      _textController.text = widget.message.text;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      if (_isEditing) {
        // Deselect message to hide the action hub while editing.
        ref.read(selectedMessageIdProvider.notifier).clear();
        // Request focus when entering edit mode.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _focusNode.requestFocus();
        });
      }
    });
  }

  void _saveChanges() {
    final newText = _textController.text.trim();
    if (newText.isNotEmpty) {
      ref
          .read(conversationProvider.notifier)
          .updateMessageContent(widget.message.id, newText);
    }
    _toggleEditMode();
  }

  void _cancelEdit() {
    _textController.text = widget.message.text;
    _toggleEditMode();
  }

  @override
  Widget build(BuildContext context) {
    final automationState = ref.watch(automationStateProvider);
    final selectedMessageId = ref.watch(selectedMessageIdProvider);

    final isSelected = selectedMessageId == widget.message.id;
    // WHY: Allow editing of any message (user or assistant) when automation is idle.
    final isEditable =
        automationState == const AutomationStateData.idle();

    final semanticLabel =
        '${widget.message.isFromUser ? 'Your' : 'Assistant'} message: ${widget.message.text}. ${isEditable ? 'Tap to show actions.' : ''}';

    return Semantics(
      label: semanticLabel,
      button: isEditable,
      child: GestureDetector(
        onTap: isEditable && !_isEditing
            ? () => ref
                .read(selectedMessageIdProvider.notifier)
                .select(widget.message.id)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: kDefaultPadding,
            vertical: kTinyPadding,
          ),
          child: Row(
            mainAxisAlignment: widget.message.isFromUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.message.isFromUser) ..._buildAvatar(isUser: false),
              Flexible(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildMessageContent(),
                    if (isSelected && !_isEditing)
                      _buildActionHub(context),
                  ],
                ),
              ),
              if (widget.message.isFromUser) ..._buildAvatar(isUser: true),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAvatar({required bool isUser}) {
    final avatarColor =
        isUser ? Colors.green.shade100 : Colors.blue.shade100;
    final icon = isUser ? Icons.person : Icons.smart_toy;
    final iconColor =
        isUser ? Colors.green.shade700 : Colors.blue.shade700;

    return [
      if (isUser) const SizedBox(width: kDefaultSpacing),
      CircleAvatar(
        radius: kMediumIconSize,
        backgroundColor: avatarColor,
        child: Icon(icon, size: kDefaultIconSize, color: iconColor),
      ),
      if (!isUser) const SizedBox(width: kDefaultSpacing),
    ];
  }

  Widget _buildMessageContent() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding, vertical: 10),
      decoration: BoxDecoration(
        color: widget.message.isFromUser
            ? Colors.blue.shade500
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(kDefaultBorderRadius).copyWith(
          bottomLeft: Radius.circular(
            widget.message.isFromUser ? kDefaultBorderRadius : kChatBubbleSmallRadius,
          ),
          bottomRight: Radius.circular(
            widget.message.isFromUser ? kChatBubbleSmallRadius : kDefaultBorderRadius,
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
      child: AnimatedSwitcher(
        duration: kShortAnimationDuration,
        child: _isEditing ? _buildEditView() : _buildMarkdownView(),
      ),
    );
  }

  Widget _buildMarkdownView() {
    // WHY: Use GptMarkdown to render AI responses, which supports code blocks,
    // tables, and LaTeX. The content is selectable by default.
    return Column(
      key: const ValueKey('markdown_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GptMarkdown(
          widget.message.text,
          style: TextStyle(
            color: widget.message.isFromUser ? Colors.white : Colors.black87,
            fontSize: kDefaultTextFontSize,
          ),
        ),
        if (widget.message.status != MessageStatus.success)
          _buildStatusIndicator(),
      ],
    );
  }

  Widget _buildEditView() {
    return Column(
      key: const ValueKey('edit_view'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: _textController,
          focusNode: _focusNode,
          autofocus: true,
          maxLines: null,
          style: TextStyle(
            color: widget.message.isFromUser ? Colors.white : Colors.black87,
          ),
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: kDefaultSpacing),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.close, color: Colors.red.shade200),
              onPressed: _cancelEdit,
              tooltip: 'Cancel',
            ),
            IconButton(
              icon: Icon(Icons.check, color: Colors.green.shade200),
              onPressed: _saveChanges,
              tooltip: 'Save',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionHub(BuildContext context) {
    return Positioned(
      top: -12,
      right: 0,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(kDefaultBorderRadius),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.copy, size: kDefaultIconSize),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: widget.message.text));
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  }
                });
                ref.read(selectedMessageIdProvider.notifier).clear();
              },
              tooltip: 'Copy Markdown',
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: kDefaultIconSize),
              onPressed: _toggleEditMode,
              tooltip: 'Edit Message',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    final isSending = widget.message.status == MessageStatus.sending;
    final icon = isSending ? null : Icons.error_outline;
    final text = isSending ? 'Sending...' : 'Error';
    final color = widget.message.isFromUser
        ? (isSending ? Colors.white70 : Colors.red.shade200)
        : (isSending ? Colors.grey.shade600 : Colors.red.shade600);

    return Padding(
      padding: const EdgeInsets.only(top: kTinyPadding),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSending)
            LoadingIndicator(size: kTinyFontSize, color: color)
          else
            Icon(icon, size: kTinyFontSize, color: color),
          const SizedBox(width: kTinyPadding),
          Text(text, style: TextStyle(fontSize: kTinyFontSize, color: color)),
        ],
      ),
    );
  }
}
