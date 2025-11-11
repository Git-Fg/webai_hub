// lib/features/presets/widgets/presets_management_screen.dart

import 'dart:convert';

import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/core/database/database_provider.dart';
import 'package:ai_hybrid_hub/features/presets/models/provider_type.dart';
import 'package:ai_hybrid_hub/features/presets/providers/presets_provider.dart';
import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart' hide Column;
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

          return ListView.builder(
            itemCount: presets.length,
            itemBuilder: (context, index) {
              final preset = presets[index];
              // Get provider metadata for display
              final providerId = preset.providerId;
              final providerType = ProviderType.values.firstWhere(
                (pt) => providerDetails[pt]!.id == providerId,
                orElse: () => ProviderType.aiStudio,
              );
              final providerName = providerDetails[providerType]!.name;

              return ListTile(
                title: Text(preset.name),
                subtitle: Text(providerName),
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
    final result = await _showPresetDialog(context);
    if (result == null) return;

    final db = ref.read(appDatabaseProvider);
    final name = result['name'] as String;
    final providerType = result['providerType'] as ProviderType;
    final providerId = providerDetails[providerType]!.id;
    final settingsJson = jsonEncode(result['settings'] as Map<String, dynamic>);

    if (name.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name is required')),
        );
      }
      return;
    }

    // Create new preset
    final allPresets = await db.watchAllPresets().first;
    final maxOrder = allPresets.isNotEmpty
        ? allPresets
              .map((PresetData p) => p.displayOrder)
              .reduce(
                (int a, int b) => a > b ? a : b,
              )
        : 0;
    final newOrder = maxOrder + 1;

    await db.createPreset(
      PresetsCompanion.insert(
        name: name,
        providerId: providerId,
        displayOrder: newOrder,
        settingsJson: settingsJson,
      ),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preset added')),
      );
    }
  }

  Future<void> _editPreset(BuildContext context, PresetData preset) async {
    final settings = jsonDecode(preset.settingsJson) as Map<String, dynamic>;
    // Convert providerId back to ProviderType for initial selection
    final providerId = preset.providerId;
    final initialProviderType = ProviderType.values.firstWhere(
      (pt) => providerDetails[pt]!.id == providerId,
      orElse: () => ProviderType.aiStudio,
    );

    final result = await _showPresetDialog(
      context,
      initialName: preset.name,
      initialProviderType: initialProviderType,
      initialSettings: settings,
    );
    if (result == null) return;

    final db = ref.read(appDatabaseProvider);
    final name = result['name'] as String;
    final providerType = result['providerType'] as ProviderType;
    final newProviderId = providerDetails[providerType]!.id;
    final settingsJson = jsonEncode(result['settings'] as Map<String, dynamic>);

    if (name.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name is required')),
        );
      }
      return;
    }

    await db.updatePreset(
      PresetsCompanion(
        id: Value(preset.id),
        name: Value(name),
        providerId: Value(newProviderId),
        settingsJson: Value(settingsJson),
      ),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preset updated')),
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
      final db = ref.read(appDatabaseProvider);
      await db.deletePreset(presetId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preset deleted')),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _showPresetDialog(
    BuildContext context, {
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
                    initialName == null ? 'Add Preset' : 'Edit Preset',
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            hintText: 'e.g., Gemini 2.5 Flash',
                          ),
                        ),
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

                        Navigator.of(context).pop({
                          'name': nameController.text,
                          'providerType': selectedProviderType.value,
                          'settings': settings,
                        });
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
