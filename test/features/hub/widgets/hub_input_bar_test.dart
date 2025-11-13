import 'package:ai_hybrid_hub/features/hub/widgets/hub_input_bar.dart';
import 'package:ai_hybrid_hub/features/presets/providers/selected_presets_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

  group('HubInputBar', () {
    testWidgets('send button is present', (tester) async {
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
          child: const MaterialApp(
            home: Scaffold(
              body: HubInputBar(),
            ),
          ),
        ),
      );

      final sendButton = find.byKey(const Key('hub_send_button'));
      expect(sendButton, findsOneWidget);
    });

    testWidgets('input field is present', (tester) async {
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
          child: const MaterialApp(
            home: Scaffold(
              body: HubInputBar(),
            ),
          ),
        ),
      );

      final inputField = find.byKey(const Key('hub_message_input'));
      expect(inputField, findsOneWidget);
    });
  });
}
