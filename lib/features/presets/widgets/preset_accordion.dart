import 'package:ai_hybrid_hub/core/theme/theme_facade.dart';
import 'package:ai_hybrid_hub/features/presets/providers/preset_accordion_title_provider.dart';
import 'package:ai_hybrid_hub/features/presets/providers/presets_provider.dart';
import 'package:ai_hybrid_hub/features/presets/widgets/preset_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PresetAccordion extends ConsumerWidget {
  const PresetAccordion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.hubTheme;
    final presetsAsync = ref.watch(presetsProvider);
    final title = ref.watch(presetAccordionTitleProvider);

    return presetsAsync.maybeWhen(
      data: (presets) {
        if (presets.isEmpty) return const SizedBox.shrink();

        return ExpansionTile(
          title: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: theme.onSurfaceColor,
            ),
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 8),
          children: const [PresetSelector()],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
