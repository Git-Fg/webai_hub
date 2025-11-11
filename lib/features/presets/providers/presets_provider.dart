// lib/features/presets/providers/presets_provider.dart

import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/core/database/database_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'presets_provider.g.dart';

// WHY: Use explicit type from database method to avoid code generation issues
// PresetData is generated in database.g.dart (part of database.dart)
@riverpod
Stream<List<PresetData>> presets(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  // Return type is inferred from db.watchAllPresets() which returns Stream<List<PresetData>>
  return db.watchAllPresets();
}
