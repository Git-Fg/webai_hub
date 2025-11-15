// lib/features/presets/widgets/presets_management_screen.dart

import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/features/presets/models/preset_settings.dart';
import 'package:ai_hybrid_hub/features/presets/models/provider_type.dart';
import 'package:ai_hybrid_hub/features/presets/providers/presets_provider.dart';
import 'package:ai_hybrid_hub/features/presets/services/preset_service.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class PresetsManagementScreen extends ConsumerStatefulWidget {
  const PresetsManagementScreen({super.key});

  @override
  ConsumerState<PresetsManagementScreen> createState() =>
      _PresetsManagementScreenState();
}

class _PresetsManagementScreenState
    extends ConsumerState<PresetsManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final presetsAsync = ref.watch(presetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Presets'),
        backgroundColor: Colors.blue.shade600,
      ),
      body: presetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
          child: Text('Error loading presets: $err'),
        ),
        data: (presets) {
          if (presets.isEmpty) {
            return const Center(
              child: Text('No presets configured.'),
            );
          }

          return ReorderableListView.builder(
            itemCount: presets.length,
            itemBuilder: (context, index) {
              final preset = presets[index];
              final isGroup = preset.providerId == null;

              // Visual differentiation for Groups
              if (isGroup) {
                return ListTile(
                  key: ValueKey('group_${preset.id}'),
                  leading: const Icon(Icons.folder_open),
                  title: Text(
                    preset.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  tileColor: Colors.grey.shade200,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editPreset(context, preset),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deletePreset(context, preset.id),
                      ),
                    ],
                  ),
                );
              }

              // Standard Preset item
              final providerName = providerDetails.values
                  .firstWhere(
                    (p) => p.id == preset.providerId,
                    orElse: () => const ProviderMetadata(
                      id: 'unknown',
                      name: 'Unknown',
                      url: '',
                      configurableSettings: [],
                    ),
                  )
                  .name;

              return ListTile(
                key: ValueKey('preset_${preset.id}'),
                leading: const Icon(
                  Icons.settings_input_component,
                  color: Colors.blue,
                ),
                title: Text(preset.name),
                subtitle: Text(providerName),
                contentPadding: const EdgeInsets.only(
                  left: 32,
                ), // Indent presets
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editPreset(context, preset),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deletePreset(context, preset.id),
                    ),
                  ],
                ),
              );
            },
            onReorder: (int oldIndex, int newIndex) async {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final reorderedPresets = List<PresetData>.from(presets);
              final item = reorderedPresets.removeAt(oldIndex);
              reorderedPresets.insert(newIndex, item);

              await ref
                  .read(presetServiceProvider.notifier)
                  .updatePresetOrders(reorderedPresets);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addPreset(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _addPreset(BuildContext context) async {
    // Ask user if they want to create a Group or Preset
    final itemType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Group'),
              subtitle: const Text('Organize presets with shared affixes'),
              onTap: () => Navigator.of(context).pop('group'),
            ),
            ListTile(
              leading: const Icon(Icons.settings_input_component),
              title: const Text('Preset'),
              subtitle: const Text('Configure a specific provider and model'),
              onTap: () => Navigator.of(context).pop('preset'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted) return;

    if (itemType == null) return;

    final isGroup = itemType == 'group';
    final result = await _showPresetDialog(
      context,
      isGroup: isGroup,
    );
    if (!context.mounted) return;
    if (result == null) return;

    final name = result['name'] as String;
    final settings = PresetSettings.fromJson(
      result['settings'] as Map<String, dynamic>,
    );

    if (name.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name is required')),
        );
      }
      return;
    }

    // Create new preset or group
    final presetService = ref.read(presetServiceProvider.notifier);
    final newOrder = await presetService.getNextDisplayOrder();

    await presetService.createPreset(
      name: name,
      providerId: isGroup ? null : result['providerId'] as String?,
      settings: settings,
      displayOrder: newOrder,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isGroup ? 'Group added' : 'Preset added')),
      );
    }
  }

  Future<void> _editPreset(BuildContext context, PresetData preset) async {
    final initialSettingsMap = preset.settings.toJson();
    final isGroup = preset.providerId == null;

    ProviderType? initialProviderType;
    if (!isGroup) {
      final providerId = preset.providerId;
      initialProviderType = ProviderType.values.firstWhere(
        (pt) => providerDetails[pt]!.id == providerId,
        orElse: () => ProviderType.aiStudio,
      );
    }

    final result = await _showPresetDialog(
      context,
      isGroup: isGroup,
      initialName: preset.name,
      initialProviderType: initialProviderType,
      initialSettings: initialSettingsMap,
    );
    if (result == null) return;

    final name = result['name'] as String;
    final settings = PresetSettings.fromJson(
      result['settings'] as Map<String, dynamic>,
    );

    if (name.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name is required')),
        );
      }
      return;
    }

    final presetService = ref.read(presetServiceProvider.notifier);
    await presetService.updatePreset(
      id: preset.id,
      name: name,
      providerId: isGroup ? null : result['providerId'] as String?,
      settings: settings,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isGroup ? 'Group updated' : 'Preset updated')),
      );
    }
  }

  Future<void> _deletePreset(BuildContext context, int presetId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Preset?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await ref.read(presetServiceProvider.notifier).deletePreset(presetId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preset deleted')),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _showPresetDialog(
    BuildContext context, {
    bool isGroup = false,
    String? initialName,
    ProviderType? initialProviderType,
    Map<String, dynamic>? initialSettings,
  }) async {
    final nameController = TextEditingController(text: initialName);
    final selectedProviderType = ValueNotifier<ProviderType>(
      initialProviderType ?? ProviderType.aiStudio,
    );

    // Controllers for settings fields
    final modelController = TextEditingController(
      text: initialSettings?['model'] as String? ?? '',
    );
    final temperatureController = TextEditingController(
      text: (initialSettings?['temperature'] as num?)?.toString() ?? '0.8',
    );
    final topPController = TextEditingController(
      text: (initialSettings?['topP'] as num?)?.toString() ?? '0.95',
    );
    // Controllers for affix fields
    final prefixController = TextEditingController(
      text: initialSettings?['promptPrefix'] as String? ?? '',
    );
    final suffixController = TextEditingController(
      text: initialSettings?['promptSuffix'] as String? ?? '',
    );
    // WHY: The setting is 'disableThinking', so the UI should show the opposite state.
    final useWebSearchNotifier = ValueNotifier<bool>(
      initialSettings?['useWebSearch'] as bool? ?? true,
    );
    final enableThinkingNotifier = ValueNotifier<bool>(
      !(initialSettings?['disableThinking'] as bool? ?? false),
    );

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return ValueListenableBuilder<ProviderType>(
              valueListenable: selectedProviderType,
              builder: (context, currentProviderType, _) {
                final currentProvider = providerDetails[currentProviderType]!;
                final configurableSettings =
                    currentProvider.configurableSettings;

                return AlertDialog(
                  title: Text(
                    initialName == null
                        ? (isGroup ? 'Add Group' : 'Add Preset')
                        : (isGroup ? 'Edit Group' : 'Edit Preset'),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: 'Name',
                            hintText: isGroup
                                ? 'e.g., Creative Writing'
                                : 'e.g., Gemini 2.5 Flash',
                          ),
                        ),
                        if (!isGroup) ...[
                          const SizedBox(height: 16),
                          DropdownButtonFormField<ProviderType>(
                            initialValue: currentProviderType,
                            decoration: const InputDecoration(
                              labelText: 'Provider',
                            ),
                            items: ProviderType.values.map((providerType) {
                              final metadata = providerDetails[providerType]!;
                              return DropdownMenuItem<ProviderType>(
                                value: providerType,
                                child: Text(metadata.name),
                              );
                            }).toList(),
                            onChanged: (ProviderType? newValue) {
                              if (newValue != null) {
                                selectedProviderType.value = newValue;
                              }
                            },
                          ),
                          if (configurableSettings.contains('model')) ...[
                            const SizedBox(height: 16),
                            TextField(
                              controller: modelController,
                              decoration: const InputDecoration(
                                labelText: 'Model',
                                hintText: 'e.g., Gemini 2.5 Flash',
                              ),
                            ),
                          ],
                          if (configurableSettings.contains('temperature')) ...[
                            const SizedBox(height: 16),
                            TextField(
                              controller: temperatureController,
                              decoration: const InputDecoration(
                                labelText: 'Temperature',
                                hintText: '0.0 - 1.0',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ],
                          if (configurableSettings.contains('topP')) ...[
                            const SizedBox(height: 16),
                            TextField(
                              controller: topPController,
                              decoration: const InputDecoration(
                                labelText: 'Top P',
                                hintText: '0.0 - 1.0',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ],
                          if (configurableSettings.contains(
                            'useWebSearch',
                          )) ...[
                            const SizedBox(height: 16),
                            ValueListenableBuilder<bool>(
                              valueListenable: useWebSearchNotifier,
                              builder: (context, value, _) {
                                return CheckboxListTile(
                                  title: const Text('Enable Web Search'),
                                  value: value,
                                  onChanged: (newValue) {
                                    if (newValue != null) {
                                      useWebSearchNotifier.value = newValue;
                                    }
                                  },
                                );
                              },
                            ),
                          ],
                          if (configurableSettings.contains(
                            'disableThinking',
                          )) ...[
                            ValueListenableBuilder<bool>(
                              valueListenable: enableThinkingNotifier,
                              builder: (context, value, _) {
                                return CheckboxListTile(
                                  title: const Text('Enable K2 Thinking'),
                                  value: value,
                                  onChanged: (newValue) {
                                    if (newValue != null) {
                                      enableThinkingNotifier.value = newValue;
                                    }
                                  },
                                );
                              },
                            ),
                          ],
                        ],
                        // Affix fields (shown for both Groups and Presets)
                        const SizedBox(height: 16),
                        TextField(
                          controller: prefixController,
                          decoration: const InputDecoration(
                            labelText: 'Prompt Prefix',
                            hintText: 'e.g., You are an expert...',
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: suffixController,
                          decoration: const InputDecoration(
                            labelText: 'Prompt Suffix',
                            hintText: 'e.g., Format your response as...',
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        final settings = <String, dynamic>{};
                        if (!isGroup) {
                          if (configurableSettings.contains('model')) {
                            settings['model'] = modelController.text;
                          }
                          if (configurableSettings.contains('temperature')) {
                            settings['temperature'] =
                                double.tryParse(temperatureController.text) ??
                                0.8;
                          }
                          if (configurableSettings.contains('topP')) {
                            settings['topP'] =
                                double.tryParse(topPController.text) ?? 0.95;
                          }
                          if (configurableSettings.contains('useWebSearch')) {
                            settings['useWebSearch'] =
                                useWebSearchNotifier.value;
                          }
                          if (configurableSettings.contains(
                            'disableThinking',
                          )) {
                            settings['disableThinking'] =
                                !enableThinkingNotifier.value;
                          }
                        }
                        // Always include affixes
                        if (prefixController.text.isNotEmpty) {
                          settings['promptPrefix'] = prefixController.text;
                        }
                        if (suffixController.text.isNotEmpty) {
                          settings['promptSuffix'] = suffixController.text;
                        }

                        final result = <String, dynamic>{
                          'name': nameController.text,
                          'settings': settings,
                        };
                        if (!isGroup) {
                          result['providerId'] =
                              providerDetails[selectedProviderType.value]!.id;
                        }

                        Navigator.of(context).pop(result);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
