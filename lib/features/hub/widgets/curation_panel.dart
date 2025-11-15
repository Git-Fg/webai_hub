// lib/features/hub/widgets/curation_panel.dart

import 'dart:async';

import 'package:ai_hybrid_hub/core/theme/theme_facade.dart';
import 'package:ai_hybrid_hub/features/automation/providers/automation_actions.dart';
import 'package:ai_hybrid_hub/features/hub/providers/selected_staged_responses_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/staged_responses_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CurationPanel extends ConsumerStatefulWidget {
  const CurationPanel({super.key});

  @override
  ConsumerState<CurationPanel> createState() => _CurationPanelState();
}

class _CurationPanelState extends ConsumerState<CurationPanel> {
  int? _finalizingPresetId;

  @override
  Widget build(BuildContext context) {
    final theme = context.hubTheme;
    final stagedResponses = ref.watch(stagedResponsesProvider);
    final selectedIds = ref.watch(selectedStagedResponsesProvider);

    if (stagedResponses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      color: theme.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a Response to Continue:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: theme.onSurfaceColor,
              ),
            ),
            Divider(height: 16, color: theme.dividerColor),
            ...stagedResponses.values.map((response) {
              final isSelected = selectedIds.contains(response.presetId);
              final isFinalizing = _finalizingPresetId == response.presetId;
              final isAnyFinalizing = _finalizingPresetId != null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CheckboxListTile(
                  value: isSelected,
                  onChanged: response.isLoading || isAnyFinalizing
                      ? null
                      : (bool? value) {
                          ref
                              .read(selectedStagedResponsesProvider.notifier)
                              .toggle(response.presetId);
                        },
                  title: Text(
                    response.presetName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.onSurfaceColor,
                    ),
                  ),
                  subtitle: response.isLoading
                      ? const LinearProgressIndicator()
                      : Text(
                          response.text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: theme.onSurfaceColor),
                        ),
                  secondary: !response.isLoading
                      ? ElevatedButton(
                          onPressed: isAnyFinalizing
                              ? null
                              : () {
                                  setState(() {
                                    _finalizingPresetId = response.presetId;
                                  });
                                  unawaited(
                                    ref
                                        .read(
                                          automationActionsProvider.notifier,
                                        )
                                        .finalizeTurnWithResponse(response.text)
                                        .whenComplete(() {
                                          if (mounted) {
                                            setState(() {
                                              _finalizingPresetId = null;
                                            });
                                          }
                                        }),
                                  );
                                },
                          child: isFinalizing
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.actionButtonTextColor,
                                  ),
                                )
                              : const Text('Use this'),
                        )
                      : null,
                ),
              );
            }),
            if (selectedIds.length >= 2)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      unawaited(
                        ref
                            .read(automationActionsProvider.notifier)
                            .synthesizeResponses(),
                      );
                    },
                    child: const Text('Synthesize Selected Responses'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
