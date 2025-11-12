import 'package:ai_hybrid_hub/features/presets/providers/presets_provider.dart';
import 'package:ai_hybrid_hub/features/presets/providers/selected_presets_provider.dart';
import 'package:ai_hybrid_hub/features/presets/widgets/preset_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PresetAccordion extends ConsumerWidget {
  const PresetAccordion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetsAsync = ref.watch(presetsProvider);
    final selectedIdsAsync = ref.watch(selectedPresetIdsProvider);

    return presetsAsync.when(
      data: (presets) {
        if (presets.isEmpty) return const SizedBox.shrink();

        final selectedIds = selectedIdsAsync.maybeWhen(
          data: (ids) => ids,
          orElse: () => <int>[],
        );
        final selectedPresets = presets
            .where((p) => selectedIds.contains(p.id))
            .toList();

        var title = 'No preset selected';
        if (selectedPresets.isNotEmpty) {
          title =
              '${selectedPresets.length} selected: ${selectedPresets.first.name}';
          if (selectedPresets.length > 1) {
            title += '...';
          }
        }

        return ExpansionTile(
          title: Text(title, style: const TextStyle(fontSize: 14)),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 8),
          children: const [PresetSelector()],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}
