// lib/features/hub/widgets/curation_panel.dart

import 'dart:async';

import 'package:ai_hybrid_hub/features/automation/providers/automation_orchestrator.dart';
import 'package:ai_hybrid_hub/features/hub/providers/selected_staged_responses_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/staged_responses_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'curation_panel.g.dart';

@Riverpod(keepAlive: true)
class FinalizingPresetId extends _$FinalizingPresetId {
  @override
  int? build() => null;

  void set(int? presetId) {
    state = presetId;
  }
}

class CurationPanel extends ConsumerWidget {
  const CurationPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stagedResponses = ref.watch(stagedResponsesProvider);
    final selectedIds = ref.watch(selectedStagedResponsesProvider);
    final finalizingPresetId = ref.watch(finalizingPresetIdProvider);

    if (stagedResponses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a Response to Continue:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Divider(height: 16),
            ...stagedResponses.values.map((response) {
              final isSelected = selectedIds.contains(response.presetId);
              final isFinalizing = finalizingPresetId == response.presetId;
              final isAnyFinalizing = finalizingPresetId != null;
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
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: response.isLoading
                      ? const LinearProgressIndicator()
                      : Text(
                          response.text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                  secondary: !response.isLoading
                      ? ElevatedButton(
                          onPressed: isAnyFinalizing
                              ? null
                              : () {
                                  ref.read(finalizingPresetIdProvider.notifier).set(response.presetId);
                                  unawaited(
                                    ref
                                        .read(automationOrchestratorProvider.notifier)
                                        .finalizeTurnWithResponse(response.text)
                                        .whenComplete(() {
                                          if (context.mounted) {
                                            ref.read(finalizingPresetIdProvider.notifier).set(null);
                                          }
                                        }),
                                  );
                                },
                          child: isFinalizing
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
                            .read(automationOrchestratorProvider.notifier)
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
