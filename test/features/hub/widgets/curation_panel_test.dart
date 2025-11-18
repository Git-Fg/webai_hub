import 'package:ai_hybrid_hub/features/hub/models/staged_response.dart';
import 'package:ai_hybrid_hub/features/hub/providers/selected_staged_responses_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/staged_responses_provider.dart';
import 'package:ai_hybrid_hub/features/hub/widgets/curation_panel.dart';
import 'package:ai_hybrid_hub/features/presets/providers/selected_presets_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_helpers.dart';

// Test implementation of SelectedPresetIds to avoid Hive dependency
class _TestSelectedPresetIds extends SelectedPresetIds {
  _TestSelectedPresetIds(this._value);

  final List<int> _value;

  @override
  List<int> build() => _value;
}

void main() {
  // WHY: No Hive initialization needed since we use test overrides
  // for selectedPresetIdsProvider that don't require Hive

  group('CurationPanel', () {
    testWidgets('synthesize button is enabled when 2+ responses selected', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          // Override selectedPresetIdsProvider to avoid Hive dependency issues
          selectedPresetIdsProvider.overrideWith(
            () => _TestSelectedPresetIds([]),
          ),
        ],
      );

      // Add staged responses
      container
          .read(stagedResponsesProvider.notifier)
          .addOrUpdate(
            const StagedResponse(
              presetId: 1,
              presetName: 'Preset 1',
              text: 'Response 1',
            ),
          );
      container
          .read(stagedResponsesProvider.notifier)
          .addOrUpdate(
            const StagedResponse(
              presetId: 2,
              presetName: 'Preset 2',
              text: 'Response 2',
            ),
          );

      // Select both responses
      container.read(selectedStagedResponsesProvider.notifier).toggle(1);
      container.read(selectedStagedResponsesProvider.notifier).toggle(2);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: createTestMaterialApp(
            home: const Scaffold(
              body: CurationPanel(),
            ),
          ),
        ),
      );

      final synthesizeButtonText = find.text('Synthesize Selected Responses');
      expect(synthesizeButtonText, findsOneWidget);

      // Find the ElevatedButton that contains this text
      final button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: synthesizeButtonText,
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNotNull);

      // WHY: Dispose container to clean up Riverpod timers
      container.dispose();
      await tester.pumpAndSettle();
    });

    testWidgets(
      'synthesize button is hidden when less than 2 responses selected',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            // Override selectedPresetIdsProvider to avoid Hive dependency issues
            selectedPresetIdsProvider.overrideWith(
              () => _TestSelectedPresetIds([]),
            ),
          ],
        );

        // Add staged responses
        container
            .read(stagedResponsesProvider.notifier)
            .addOrUpdate(
              const StagedResponse(
                presetId: 1,
                presetName: 'Preset 1',
                text: 'Response 1',
              ),
            );

        // Select only one response
        container.read(selectedStagedResponsesProvider.notifier).toggle(1);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: createTestMaterialApp(
              home: const Scaffold(
                body: CurationPanel(),
              ),
            ),
          ),
        );

        final synthesizeButton = find.text('Synthesize Selected Responses');
        expect(synthesizeButton, findsNothing);

        // WHY: Dispose container to clean up Riverpod timers
        container.dispose();
        await tester.pumpAndSettle();
      },
    );

    testWidgets('use this button is present for each response', (tester) async {
      final container = ProviderContainer(
        overrides: [
          // Override selectedPresetIdsProvider to avoid Hive dependency issues
          selectedPresetIdsProvider.overrideWith(
            () => _TestSelectedPresetIds([]),
          ),
        ],
      );

      // Add staged responses
      container
          .read(stagedResponsesProvider.notifier)
          .addOrUpdate(
            const StagedResponse(
              presetId: 1,
              presetName: 'Preset 1',
              text: 'Response 1',
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: createTestMaterialApp(
            home: const Scaffold(
              body: CurationPanel(),
            ),
          ),
        ),
      );

      final useThisButtonText = find.text('Use this');
      expect(useThisButtonText, findsOneWidget);

      // Find the ElevatedButton that contains this text
      final button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: useThisButtonText,
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNotNull);

      // WHY: Dispose container to clean up Riverpod timers
      container.dispose();
      await tester.pumpAndSettle();
    });

    testWidgets('panel is hidden when no staged responses', (tester) async {
      final container = ProviderContainer(
        overrides: [
          // Override selectedPresetIdsProvider to avoid Hive dependency issues
          selectedPresetIdsProvider.overrideWith(
            () => _TestSelectedPresetIds([]),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: createTestMaterialApp(
            home: const Scaffold(
              body: CurationPanel(),
            ),
          ),
        ),
      );

      final panel = find.byType(Card);
      expect(panel, findsNothing);

      // WHY: Dispose container to clean up Riverpod timers
      container.dispose();
      await tester.pumpAndSettle();
    });
  });
}
