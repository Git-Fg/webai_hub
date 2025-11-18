import 'package:ai_hybrid_hub/features/presets/providers/presets_provider.dart';
import 'package:ai_hybrid_hub/features/presets/providers/selected_presets_provider.dart';
import 'package:ai_hybrid_hub/features/settings/providers/general_settings_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'preset_accordion_title_provider.g.dart';

@riverpod
String presetAccordionTitle(Ref ref) {
  final presetsAsync = ref.watch(presetsProvider);
  final selectedIds = ref.watch(selectedPresetIdsProvider);
  final isMultiSelect =
      ref.watch(generalSettingsProvider).value?.enableMultiPresetMode ?? false;

  return presetsAsync.maybeWhen(
    data: (presets) {
      if (presets.isEmpty) {
        return 'No presets available';
      }

      final selectedPresets = presets
          .where((p) => selectedIds.contains(p.id))
          .toList();

      if (selectedPresets.isEmpty) {
        return 'No preset selected';
      }

      // WHY: The title logic now adapts to the selection mode. It shows a clear
      // summary for multi-select and the specific name for single-select.
      if (isMultiSelect) {
        var title =
            '${selectedPresets.length} selected: ${selectedPresets.first.name}';
        if (selectedPresets.length > 1) {
          title += '...';
        }
        return title;
      } else {
        return selectedPresets.first.name;
      }
    },
    orElse: () => 'Loading presets...',
  );
}
