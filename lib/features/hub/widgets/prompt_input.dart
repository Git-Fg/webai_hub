import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../shared/models/ai_provider.dart';
import '../providers/conversation_provider.dart';
import '../../automation/providers/automation_provider.dart';

class PromptInput extends ConsumerStatefulWidget {
  final Function(String) onSend;
  final bool enabled;

  const PromptInput({
    Key? key,
    required this.onSend,
    this.enabled = true,
  }) : super(key: key);

  @override
  ConsumerState<PromptInput> createState() => _PromptInputState();
}

class _PromptInputState extends ConsumerState<PromptInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isComposing = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _isComposing = _controller.text.isNotEmpty;
    });
  }

  void _handleSend() {
    if (_controller.text.trim().isEmpty || !widget.enabled) return;

    final currentConversation = ref.read(currentConversationProvider);
    final provider = currentConversation?.provider ?? AIProvider.aistudio;

    // Check if automation is already active
    final automationState = ref.read(automationProvider);
    if (automationState.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez attendre la fin de l\'automatisation en cours'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    ref.read(conversationProvider.notifier).sendMessage(
      _controller.text.trim(),
      provider: provider,
    );

    _controller.clear();
    _focusNode.unfocus();
    setState(() {
      _isComposing = false;
    });
  }

  Future<void> _attachFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'md', 'pdf', 'doc', 'docx'],
    );

    if (result != null && result.files.single.path != null) {
      // TODO: Handle file attachment
      // This will be implemented in Phase 6
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attachement de fichiers bientôt disponible!'),
          backgroundColor: Colors.deepPurpleAccent,
        ),
      );
    }
  }

  Future<void> _pasteFromClipboard() async {
    // TODO: Handle clipboard paste
    // This will be implemented in Phase 6
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fonction presse-papiers bientôt disponible!'),
        backgroundColor: Colors.deepPurpleAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade700,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Action Buttons Row
            Row(
              children: [
                // Provider Selector (placeholder)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.smart_toy,
                        size: 16,
                        color: Colors.deepPurpleAccent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Sélectionner un provider',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Context Buttons
                IconButton(
                  onPressed: _attachFile,
                  icon: Icon(
                    Icons.attach_file,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  tooltip: 'Attacher un fichier',
                ),

                IconButton(
                  onPressed: _pasteFromClipboard,
                  icon: Icon(
                    Icons.content_paste,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  tooltip: 'Coller depuis le presse-papiers',
                ),

                // Options Button
                IconButton(
                  onPressed: () {
                    // TODO: Show options dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Options bientôt disponibles!'),
                        backgroundColor: Colors.deepPurpleAccent,
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.settings,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  tooltip: 'Options',
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Input Field Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: widget.enabled
                            ? (_isComposing
                                ? Colors.deepPurpleAccent
                                : Colors.grey.shade600)
                            : Colors.grey.shade700,
                        width: _isComposing ? 2 : 1,
                      ),
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      enabled: widget.enabled,
                      maxLines: 5,
                      minLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.enabled
                            ? 'Tapez votre message ici...'
                            : 'Veuillez sélectionner un provider prêt',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade500,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Send Button
                Container(
                  decoration: BoxDecoration(
                    color: widget.enabled && _isComposing
                        ? Colors.deepPurpleAccent
                        : Colors.grey.shade700,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: widget.enabled && _isComposing ? _handleSend : null,
                    icon: const Icon(
                      Icons.send,
                      color: Colors.white,
                    ),
                    tooltip: 'Envoyer',
                  ),
                ),
              ],
            ),

            // Character Count (optional)
            if (_controller.text.length > 100)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${_controller.text.length} caractères',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}