import 'dart:io';

import 'package:ai_hybrid_hub/features/settings/models/general_settings.dart';
import 'package:ai_hybrid_hub/features/settings/providers/general_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  group('GeneralSettings', () {
    late HiveInterface hive;
    late Directory tempDir;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();

      // WHY: Use Hive.init() instead of Hive.initFlutter() for tests
      // to avoid platform channel dependencies
      tempDir = await Directory.systemTemp.createTemp('hive_test_');
      Hive.init(tempDir.path);
      hive = Hive;

      // Register adapter
      if (!hive.isAdapterRegistered(0)) {
        hive.registerAdapter<GeneralSettingsData>(GeneralSettingsDataAdapter());
      }

      // Open test box with the same name the provider expects
      await hive.openBox<GeneralSettingsData>('general_settings_box');
    });

    tearDown(() async {
      await hive.deleteBoxFromDisk('general_settings_box');
      await tempDir.delete(recursive: true);
    });

    test('toggleAdvancedPrompting updates state', () async {
      final container = ProviderContainer();

      // Wait for initial load
      await container.read(generalSettingsProvider.future);

      final initialValue =
          container.read(generalSettingsProvider).value?.useAdvancedPrompting ??
          false;

      // Toggle
      await container
          .read(generalSettingsProvider.notifier)
          .toggleAdvancedPrompting();
      await container.read(generalSettingsProvider.future);

      final newValue = container
          .read(generalSettingsProvider)
          .value
          ?.useAdvancedPrompting;
      expect(newValue, !initialValue);

      container.dispose();
    });

    test('updateTimeoutModifier updates state', () async {
      final container = ProviderContainer();

      // Wait for initial load
      await container.read(generalSettingsProvider.future);

      const newModifier = 2.0;

      // Update
      await container
          .read(generalSettingsProvider.notifier)
          .updateTimeoutModifier(newModifier);
      await container.read(generalSettingsProvider.future);

      final updatedValue = container
          .read(generalSettingsProvider)
          .value
          ?.timeoutModifier;
      expect(updatedValue, newModifier);

      container.dispose();
    });

    test('updateCustomUserAgent validates input', () async {
      final container = ProviderContainer();

      // Wait for initial load
      await container.read(generalSettingsProvider.future);

      // Test invalid user agent (doesn't start with Mozilla/)
      expect(
        () => container
            .read(generalSettingsProvider.notifier)
            .updateCustomUserAgent('Invalid UA'),
        throwsA(isA<ArgumentError>()),
      );

      // Test valid user agent
      const validUA = 'Mozilla/5.0 (Test)';
      await container
          .read(generalSettingsProvider.notifier)
          .updateCustomUserAgent(validUA);
      await container.read(generalSettingsProvider.future);

      final updatedValue = container
          .read(generalSettingsProvider)
          .value
          ?.customUserAgent;
      expect(updatedValue, validUA);

      container.dispose();
    });

    test('updateMaxConversationHistory updates state', () async {
      final container = ProviderContainer();

      // Wait for initial load
      await container.read(generalSettingsProvider.future);

      const newMax = 100;

      // Update
      await container
          .read(generalSettingsProvider.notifier)
          .updateMaxConversationHistory(newMax);
      await container.read(generalSettingsProvider.future);

      final updatedValue = container
          .read(generalSettingsProvider)
          .value
          ?.maxConversationHistory;
      expect(updatedValue, newMax);

      container.dispose();
    });
  });
}
