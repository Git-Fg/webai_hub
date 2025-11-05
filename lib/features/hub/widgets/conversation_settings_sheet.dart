import 'package:ai_hybrid_hub/features/hub/providers/conversation_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConversationSettingsSheet extends ConsumerStatefulWidget {
  const ConversationSettingsSheet({super.key});

  @override
  ConsumerState<ConversationSettingsSheet> createState() =>
      _ConversationSettingsSheetState();
}

class _ConversationSettingsSheetState
    extends ConsumerState<ConversationSettingsSheet> {
  late final TextEditingController _systemPromptController;
  late double _currentTemperature;

  @override
  void initState() {
    super.initState();
    // WHY: We read the settings in initState to initialize local state.
    // ref.read is safe in ConsumerState.initState without any callback wrapper.
    final settings = ref.read(conversationSettingsProvider);
    _systemPromptController =
        TextEditingController(text: settings.systemPrompt);
    _currentTemperature = settings.temperature;
  }

  @override
  void dispose() {
    _systemPromptController.dispose();
    super.dispose();
  }

  void _applyChanges() {
    final notifier = ref.read(conversationSettingsProvider.notifier);
    notifier.updateSystemPrompt(_systemPromptController.text);
    notifier.updateTemperature(_currentTemperature);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Conversation Settings',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _systemPromptController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'System Prompt',
              hintText: 'e.g., You are a helpful expert...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text('Temperature: ${_currentTemperature.toStringAsFixed(2)}'),
          Slider(
            value: _currentTemperature,
            divisions: 100,
            label: _currentTemperature.toStringAsFixed(2),
            onChanged: (double value) {
              setState(() {
                _currentTemperature = value;
              });
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _applyChanges,
              child: const Text('Apply Changes'),
            ),
          ),
        ],
      ),
    );
  }
}
