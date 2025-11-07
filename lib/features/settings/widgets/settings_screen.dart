import 'dart:async';

import 'package:ai_hybrid_hub/features/settings/models/general_settings.dart';
import 'package:ai_hybrid_hub/features/settings/providers/general_settings_provider.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _historyInstructionController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    // Initialize the controller with the current setting value.
    // We read the value directly. `value` might be null if settings are loading/error.
    final initialInstruction =
        ref.read(generalSettingsProvider).value?.historyContextInstruction ??
            '';
    _historyInstructionController =
        TextEditingController(text: initialInstruction);

    // Initialize the FocusNode and add a listener to save on unfocus.
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    // Save the text only when the text field loses focus.
    if (!_focusNode.hasFocus) {
      unawaited(
        ref
            .read(generalSettingsProvider.notifier)
            .updateHistoryContextInstruction(
              _historyInstructionController.text,
            ),
      );
    }
  }

  @override
  void dispose() {
    // Clean up the controller and the focus node listener.
    _historyInstructionController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(generalSettingsProvider);
    final settingsNotifier = ref.read(generalSettingsProvider.notifier);

    // Listen for changes to update the controller if needed (e.g., reset to default)
    ref.listen(generalSettingsProvider, (_, next) {
      final newInstruction = next.value?.historyContextInstruction ?? '';
      if (_historyInstructionController.text != newInstruction) {
        _historyInstructionController.text = newInstruction;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (settings) {
          // Determine if the reset button should be visible.
          final isDefault = settings.historyContextInstruction ==
              const GeneralSettingsData().historyContextInstruction;

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Provider Management',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              SwitchListTile(
                title: const Text('Google AI Studio'),
                value: settings.enabledProviders.contains('ai_studio'),
                onChanged: (bool value) {
                  unawaited(settingsNotifier.toggleProvider('ai_studio'));
                },
              ),
              // Add more providers here in the future
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Prompt Engineering',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              SwitchListTile(
                title: const Text('Use Advanced (XML) Prompting'),
                subtitle: const Text(
                  'Provides better context to the AI. Recommended for models like Claude.',
                ),
                value: settings.useAdvancedPrompting,
                onChanged: (bool value) {
                  unawaited(settingsNotifier.toggleAdvancedPrompting());
                },
              ),
              SwitchListTile(
                title: const Text('Enable "YOLO" Mode'),
                subtitle: const Text(
                  'Automatically extracts the AI response as soon as it is ready.',
                ),
                value: settings.yoloModeEnabled,
                onChanged: (bool value) {
                  unawaited(settingsNotifier.toggleYoloMode());
                },
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _historyInstructionController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    labelText: 'History Context Instruction',
                    border: const OutlineInputBorder(),
                    helperText:
                        'The text that introduces the conversation history to the AI.',
                    // Conditionally add the reset button as a suffix icon.
                    suffixIcon: !isDefault
                        ? IconButton(
                            icon: const Icon(Icons.restore),
                            tooltip: 'Reset to default',
                            onPressed: () {
                              unawaited(
                                settingsNotifier
                                    .resetHistoryContextInstruction(),
                              );
                              // Unfocus to prevent saving the old value after reset.
                              _focusNode.unfocus();
                            },
                          )
                        : null, // Icon is null (hidden) if the value is already the default.
                  ),
                  maxLines: 3,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
