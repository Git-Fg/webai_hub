import 'dart:async';

import 'package:ai_hybrid_hub/features/settings/providers/general_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(generalSettingsProvider);
    final settingsNotifier = ref.read(generalSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (settings) {
          return ListView(
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
            ],
          );
        },
      ),
    );
  }
}
