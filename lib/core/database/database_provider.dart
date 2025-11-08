// lib/core/database/database_provider.dart

import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_provider.g.dart';

// WHY: keepAlive is true because the database connection is a long-lived resource
// that should persist for the entire application lifecycle, not be disposed
// and recreated when UI parts are unmounted.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  return AppDatabase();
}
