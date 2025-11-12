import 'dart:convert';

import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/core/database/database_provider.dart';
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
  final presetsList = jsonDecode(jsonString) as List<dynamic>;

  for (final presetData in presetsList) {
    final data = presetData as Map<String, dynamic>;
    await db.createPreset(
      PresetsCompanion.insert(
        name: data['name'] as String,
        providerId: Value(data['providerId'] as String),
        displayOrder: data['displayOrder'] as int,
        settingsJson: jsonEncode(data['settings']),
      ),
    );
  }
}
