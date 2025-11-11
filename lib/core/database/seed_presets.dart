import 'dart:convert';
import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/core/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> seedPresets(ProviderContainer container) async {
  final db = container.read(appDatabaseProvider);

  // Check if presets already exist
  final existingPresets = await db.watchAllPresets().first;
  if (existingPresets.isNotEmpty) {
    return;
  }

  // Create presets for AI Studio and Kimi
  final presets = [
    {
      'name': 'Gemini 2.5 Flash',
      'providerId': 'ai_studio',
      'displayOrder': 1,
      'settingsJson': jsonEncode({
        'model': 'Gemini 2.5 Flash',
        'temperature': 0.8,
        'topP': 0.95,
      }),
    },
    {
      'name': 'Gemini 2.5 Pro',
      'providerId': 'ai_studio',
      'displayOrder': 2,
      'settingsJson': jsonEncode({
        'model': 'Gemini 2.5 Pro',
        'temperature': 0.8,
        'topP': 0.95,
      }),
    },
    {
      'name': 'Kimi',
      'providerId': 'kimi',
      'displayOrder': 3,
      'settingsJson': jsonEncode({}),
    },
  ];

  for (final presetData in presets) {
    await db.createPreset(
      PresetsCompanion.insert(
        name: presetData['name']! as String,
        providerId: presetData['providerId']! as String,
        displayOrder: presetData['displayOrder']! as int,
        settingsJson: presetData['settingsJson']! as String,
      ),
    );
  }
}
