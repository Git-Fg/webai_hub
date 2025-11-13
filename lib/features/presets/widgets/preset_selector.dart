// lib/features/presets/widgets/preset_selector.dart

import 'package:ai_hybrid_hub/features/presets/providers/presets_provider.dart';
import 'package:ai_hybrid_hub/features/presets/providers/selected_presets_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// WHY: Widget for selecting presets in multi-select mode.
// Designed for use inside an ExpansionTile accordion, always showing FilterChip widgets.
class PresetSelector extends ConsumerWidget {
  const PresetSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetsAsync = ref.watch(presetsProvider);
    final selectedIds = ref.watch(selectedPresetIdsProvider);

    return presetsAsync.when(
      data: (presets) {
        if (presets.isEmpty) {
          return const SizedBox.shrink();
        }

        // WHY: Filter out groups (presets without providerId) from selection
        // Groups are for UI organization only and cannot be used for automation
        final selectablePresets = presets.where((p) => p.providerId != null).toList();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectablePresets.map((preset) {
              final isSelected = selectedIds.contains(preset.id);
              return FilterChip(
                label: Text(preset.name),
                selected: isSelected,
                onSelected: (selected) {
                  ref
                      .read(selectedPresetIdsProvider.notifier)
                      .toggle(preset.id);
                },
              );
            }).toList(),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
