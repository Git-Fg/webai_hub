import 'package:ai_hybrid_hub/features/hub/providers/conversation_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

class ConversationSettingsSheet extends ConsumerStatefulWidget {
  const ConversationSettingsSheet({super.key});

  @override
  ConsumerState<ConversationSettingsSheet> createState() =>
      _ConversationSettingsSheetState();
}

class _ConversationSettingsSheetState
    extends ConsumerState<ConversationSettingsSheet> {
  late final TextEditingController _systemPromptController;
  late final TextEditingController _thinkingBudgetController;

  // WHY: This data is provider-specific and should not live in the UI.
  // In a multi-provider setup, this would come from a configuration service.
  // For now, we keep it here but acknowledge it's a candidate for abstraction.
  static const List<String> _aiStudioModels = [
    'Gemini 2.5 Pro',
    'Gemini Flash Latest',
    'Gemini Flash-Lite Latest',
    'Gemini 2.5 Flash',
    'Gemini 2.5 Flash Lite',
  ];

  @override
  void initState() {
    super.initState();
    final settings = ref.read(conversationSettingsProvider);
    _systemPromptController =
        TextEditingController(text: settings.systemPrompt);
    _thinkingBudgetController = TextEditingController(
      text: settings.thinkingBudget?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _systemPromptController.dispose();
    _thinkingBudgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(conversationSettingsProvider);
    final notifier = ref.read(conversationSettingsProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conversation Settings',
              style: textTheme.titleLarge,
            ),
            const Gap(24),
            DropdownButtonFormField<String>(
              initialValue: settings.model,
              hint: const Text('Default Model'),
              items: _aiStudioModels.map((model) {
                return DropdownMenuItem<String>(
                  value: model,
                  child: Text(model),
                );
              }).toList(),
              onChanged: notifier.updateModel,
              decoration: const InputDecoration(
                labelText: 'AI Model',
                border: OutlineInputBorder(),
              ),
            ),
            const Gap(16),
            TextField(
              controller: _systemPromptController,
              onChanged: notifier.updateSystemPrompt,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'System Prompt',
                border: OutlineInputBorder(),
              ),
            ),
            const Gap(24),
            _buildSlider(
              context,
              'Temperature',
              settings.temperature,
              notifier.updateTemperature,
            ),
            _buildSlider(
              context,
              'Top-P',
              settings.topP,
              notifier.updateTopP,
            ),
            TextField(
              controller: _thinkingBudgetController,
              onChanged: (value) =>
                  notifier.updateThinkingBudget(int.tryParse(value)),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Thinking Budget (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const Gap(16),
            Text(
              'Tools & Features',
              style: textTheme.titleSmall,
            ),
            SwitchListTile(
              title: const Text('Enable Web Search'),
              value: settings.useWebSearch,
              onChanged: (value) => notifier.toggleUseWebSearch(value: value),
            ),
            SwitchListTile(
              title: const Text('Enable URL Context'),
              value: settings.urlContext,
              onChanged: (value) => notifier.toggleUrlContext(value: value),
            ),
            SwitchListTile(
              title: const Text('Disable "Thinking" Feature'),
              value: settings.disableThinking,
              onChanged: (value) =>
                  notifier.toggleDisableThinking(value: value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(
    BuildContext context,
    String label,
    double value,
    ValueChanged<double> onChanged, {
    int divisions = 100,
    double max = 1.0,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(2)}'),
        Slider(
          value: value,
          divisions: divisions,
          max: max,
          label: value.toStringAsFixed(2),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
