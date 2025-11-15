import 'dart:convert';

import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/core/database/database_provider.dart';
import 'package:ai_hybrid_hub/features/presets/models/preset_settings.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> seedPresets(ProviderContainer container) async {
  final db = container.read(appDatabaseProvider);

  // Check if presets already exist
  final existingPresets = await db.watchAllPresets().first;
  if (existingPresets.isNotEmpty) {
    return;
  }

  // Load presets from JSON asset
  final jsonString = await rootBundle.loadString('assets/seed_presets.json');
  final presetsList = (jsonDecode(jsonString) as List)
      .cast<Map<String, dynamic>>();

  for (final presetData in presetsList) {
    await db.createPreset(
      PresetsCompanion.insert(
        name: presetData['name'] as String,
        providerId: Value(presetData['providerId'] as String),
        displayOrder: presetData['displayOrder'] as int,
        settings: PresetSettings.fromJson(presetData['settings'] as Map<String, dynamic>),
      ),
    );
  }
}
