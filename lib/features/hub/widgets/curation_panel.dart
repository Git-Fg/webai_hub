// lib/features/hub/widgets/curation_panel.dart

import 'dart:async';

import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/staged_responses_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CurationPanel extends ConsumerWidget {
  const CurationPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stagedResponses = ref.watch(stagedResponsesProvider);

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
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      response.presetName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    if (response.isLoading)
                      const LinearProgressIndicator()
                    else
                      Text(
                        response.text,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    if (!response.isLoading)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              unawaited(
                                ref
                                    .read(conversationActionsProvider.notifier)
                                    .finalizeTurnWithResponse(response.text),
                              );
                            },
                            child: const Text('Use this'),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
