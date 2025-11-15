import 'dart:async';

import 'package:ai_hybrid_hub/core/router/app_router.dart';
import 'package:ai_hybrid_hub/features/settings/models/general_settings.dart';
import 'package:ai_hybrid_hub/features/settings/providers/general_settings_provider.dart';
import 'package:ai_hybrid_hub/features/settings/widgets/user_agent_selector.dart';
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
    // WHY: Use maybeWhen to safely access AsyncValue in non-reactive context.
    // This prevents exceptions if the state is AsyncLoading or AsyncError.
    final initialInstruction = ref
        .read(generalSettingsProvider)
        .maybeWhen(
          data: (settings) => settings.historyContextInstruction,
          orElse: () => '',
        );
    _historyInstructionController = TextEditingController(
      text: initialInstruction,
    );

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
    // Clean up the controllers and the focus node listener.
    _historyInstructionController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(generalSettingsProvider);
    final settingsNotifier = ref.read(generalSettingsProvider.notifier);

    // Listen for changes to update the controllers if needed (e.g., reset to default)
    // WHY: Use maybeWhen to safely access AsyncValue in listener callback.
    ref.listen(generalSettingsProvider, (_, next) {
      final newInstruction = next.maybeWhen(
        data: (settings) => settings.historyContextInstruction,
        orElse: () => '',
      );
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
          final isDefault =
              settings.historyContextInstruction ==
              const GeneralSettingsData().historyContextInstruction;

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Presets',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.settings_applications),
                title: const Text('Manage Presets'),
                subtitle: const Text('Create, edit, and organize AI presets'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  unawaited(
                    context.router.push(const PresetsManagementRoute()),
                  );
                },
              ),
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
                  'Provides better context to the AI. Recommended for advanced models.',
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Conversation History',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              SwitchListTile(
                title: const Text('Persist Session on Restart'),
                subtitle: const Text(
                  'Restore the last active conversation when the app restarts.',
                ),
                value: settings.persistSessionOnRestart,
                onChanged: (bool value) {
                  unawaited(
                    settingsNotifier.togglePersistSession(value: value),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Max Conversation History: ${settings.maxConversationHistory}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Maximum number of conversations to keep. Older conversations will be automatically deleted.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    Slider(
                      value: settings.maxConversationHistory.toDouble(),
                      min: 5,
                      max: 50,
                      divisions: 9, // (5, 10, 15, 20, 25, 30, 35, 40, 45, 50)
                      label: '${settings.maxConversationHistory}',
                      onChanged: (value) {
                        unawaited(
                          settingsNotifier.updateMaxConversationHistory(
                            value.round(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'WebView Settings',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              SwitchListTile(
                title: const Text('Enable WebView Zoom'),
                subtitle: const Text(
                  'Allows pinch-to-zoom in the provider WebView.',
                ),
                value: settings.webViewSupportZoom,
                onChanged: (bool value) {
                  unawaited(settingsNotifier.toggleWebViewZoom(value: value));
                },
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Advanced Settings',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Timeout Modifier: ${settings.timeoutModifier.toStringAsFixed(1)}x',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Increase this on slower devices or networks if automation fails.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    Slider(
                      value: settings.timeoutModifier,
                      min: 1,
                      max: 3,
                      divisions: 4, // (1.0, 1.5, 2.0, 2.5, 3.0)
                      label: '${settings.timeoutModifier.toStringAsFixed(1)}x',
                      onChanged: (value) {
                        unawaited(
                          settingsNotifier.updateTimeoutModifier(value),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const UserAgentSelector(),
            ],
          );
        },
      ),
    );
  }
}
