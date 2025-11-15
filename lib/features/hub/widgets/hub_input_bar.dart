import 'dart:async';

import 'package:ai_hybrid_hub/features/automation/providers/automation_actions.dart';
import 'package:ai_hybrid_hub/features/presets/providers/selected_presets_provider.dart';
import 'package:ai_hybrid_hub/features/presets/widgets/preset_accordion.dart';
import 'package:ai_hybrid_hub/shared/ui_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

class HubInputBar extends ConsumerStatefulWidget {
  const HubInputBar({super.key});

  @override
  ConsumerState<HubInputBar> createState() => _HubInputBarState();
}

class _HubInputBarState extends ConsumerState<HubInputBar> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_textController.text.trim().isEmpty) return;

    final message = _textController.text.trim();
    // Get selected preset IDs directly from the provider
    final selectedPresetIds = ref.read(selectedPresetIdsProvider);
    if (selectedPresetIds.isEmpty) {
      // No preset selected, can't send
      return;
    }

    unawaited(
      ref
          .read(automationActionsProvider.notifier)
          .sendPromptToAutomation(
            message,
            selectedPresetIds: selectedPresetIds,
          ),
    );
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (!HardwareKeyboard.instance.isShiftPressed) {
            unawaited(_sendMessage());
          }
        },
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: kDefaultBlurRadius,
              offset: kTopShadowOffset,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Part A: The clean input bar
            Padding(
              padding: const EdgeInsets.fromLTRB(
                kDefaultPadding,
                kDefaultPadding,
                kDefaultPadding,
                kDefaultPadding,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(left: kDefaultPadding),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(kInputBorderRadius),
                      ),
                      child: TextField(
                        key: const Key('hub_message_input'),
                        focusNode: _focusNode,
                        controller: _textController,
                        decoration: const InputDecoration(
                          hintText: 'Type your message...',
                          border: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: kDefaultPadding + kTinyPadding,
                            vertical: kMediumVerticalPadding,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                      ),
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
            // Part B: The Accordion (now simplified)
            const PresetAccordion(),
          ],
        ),
      ),
    );
  }
}
