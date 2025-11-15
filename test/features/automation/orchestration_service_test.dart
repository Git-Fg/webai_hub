import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/core/database/database_provider.dart';
import 'package:ai_hybrid_hub/features/automation/services/orchestration_service.dart';
import 'package:ai_hybrid_hub/features/presets/providers/presets_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('OrchestrationService', () {
    late ProviderContainer container;
    late AppDatabase testDatabase;

    setUp(() {
      testDatabase = AppDatabase.test();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDatabase),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await testDatabase.close();
    });

    test('validatePresetsExist throws StateError for missing preset', () async {
      // ARRANGE
      final testPresets = [createTestPreset(id: 1, name: 'Existing Preset')];
      final testContainer = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDatabase),
          presetsProvider.overrideWith((ref) => Stream.value(testPresets)),
        ],
      );

      final service = testContainer.read(orchestrationServiceProvider.notifier);

      // ACT & ASSERT
      await expectLater(
        () => service.validatePresetsExist([1, 99]), // 99 does not exist
        throwsA(isA<StateError>()),
      );

      testContainer.dispose();
    });

    test('findPresetInList returns correct index or -1', () {
      // ARRANGE
      final service = container.read(orchestrationServiceProvider.notifier);
      final testPresets = [
        createTestPreset(id: 10, name: 'Preset A'),
        createTestPreset(id: 20, name: 'Preset B'),
      ];

      // ACT & ASSERT
      expect(service.findPresetInList(testPresets, 20), 1);
      expect(service.findPresetInList(testPresets, 99), -1);
    });
  });
}
