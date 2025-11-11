// lib/features/settings/widgets/user_agent_selector.dart

import 'dart:async';

import 'package:ai_hybrid_hub/features/settings/models/browser_user_agent.dart';
import 'package:ai_hybrid_hub/features/settings/providers/general_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserAgentSelector extends ConsumerStatefulWidget {
  const UserAgentSelector({super.key});

  @override
  ConsumerState<UserAgentSelector> createState() => _UserAgentSelectorState();
}

class _UserAgentSelectorState extends ConsumerState<UserAgentSelector> {
  late final TextEditingController _customUserAgentController;

  @override
  void initState() {
    super.initState();
    final initialCustomUA = ref
        .read(generalSettingsProvider)
        .maybeWhen(
          data: (settings) => settings.customUserAgent,
          orElse: () => '',
        );
    _customUserAgentController = TextEditingController(text: initialCustomUA);
  }

  @override
  void dispose() {
    _customUserAgentController.dispose();
    super.dispose();
  }

  void _saveCustomUserAgent() {
    final notifier = ref.read(generalSettingsProvider.notifier);
    unawaited(
      notifier
          .updateCustomUserAgent(_customUserAgentController.text)
          .catchError((Object e, StackTrace s) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: ${e is ArgumentError ? e.message : e}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(generalSettingsProvider);
    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (settings) {
        final settingsNotifier = ref.read(generalSettingsProvider.notifier);

        // Keep controller in sync with state (e.g., if settings are reset)
        if (_customUserAgentController.text != settings.customUserAgent) {
          _customUserAgentController.text = settings.customUserAgent;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: settings.selectedUserAgent,
                decoration: const InputDecoration(
                  labelText: 'User Agent for OAuth',
                  border: OutlineInputBorder(),
                  helperText: 'Select a browser identity for login pages.',
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'default',
                    child: Text('Device Default (Blocks Google Login)'),
                  ),
                  ...BrowserUserAgent.values.map((ua) {
                    return DropdownMenuItem(
                      value: ua.name,
                      child: Text(ua.name),
                    );
                  }),
                  const DropdownMenuItem(
                    value: 'custom',
                    child: Text('Custom...'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    unawaited(settingsNotifier.updateSelectedUserAgent(value));
                  }
                },
              ),
              if (settings.selectedUserAgent == 'custom') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _customUserAgentController,
                  decoration: const InputDecoration(
                    labelText: 'Custom User Agent',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _saveCustomUserAgent(),
                  onEditingComplete: _saveCustomUserAgent,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
