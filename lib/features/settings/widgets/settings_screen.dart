import 'dart:async';

import 'package:ai_hybrid_hub/features/settings/providers/general_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(generalSettingsProvider);
    final settingsNotifier = ref.read(generalSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
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
        ],
      ),
    );
  }
}
