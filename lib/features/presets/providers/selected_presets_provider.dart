// lib/features/presets/providers/selected_presets_provider.dart

import 'dart:async';

import 'package:ai_hybrid_hub/features/presets/providers/presets_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'selected_presets_provider.g.dart';

const _boxName = 'app_state_box';
const _lastKey = 'last_used_preset_ids';

// WHY: Service to persist selected preset IDs in Hive
class SelectedPresetsService {
  Future<Box<dynamic>> get _box async => Hive.openBox<dynamic>(_boxName);

  Future<List<int>> getLastUsedPresets() async {
    final box = await _box;
    final stored = box.get(_lastKey);
    if (stored is List) {
      return stored.cast<int>();
    }
    return [];
  }

  Future<void> setLastUsedPresets(List<int> presetIds) async {
    final box = await _box;
    await box.put(_lastKey, presetIds);
  }
}

@riverpod
SelectedPresetsService selectedPresetsService(Ref ref) {
  return SelectedPresetsService();
}

// WHY: This provider holds the IDs of presets the user has selected
// in the Hub UI. It supports both single and multi-selection modes.
// It's kept alive to remember the user's choice across the app.
@Riverpod(keepAlive: true)
class SelectedPresetIds extends _$SelectedPresetIds {
  @override
  Future<List<int>> build() async {
    final service = ref.read(selectedPresetsServiceProvider);
    final lastUsed = await service.getLastUsedPresets();

    if (lastUsed.isNotEmpty) {
      return lastUsed;
    }

    // Set a default if no saved value exists.
    final presets = await ref.read(presetsProvider.future);
    return presets.isNotEmpty ? [presets.first.id] : [];
  }

  // WHY: Set a single preset (replaces current selection)
  void setSingle(int presetId) {
    state = AsyncData([presetId]);
    _persist();
  }

  // WHY: Toggle a preset in the selection (for multi-select mode)
  void toggle(int presetId) {
    final current = state.maybeWhen(
      data: (ids) => ids,
      orElse: () => <int>[],
    );
    final newList = List<int>.from(current);
    if (newList.contains(presetId)) {
      newList.remove(presetId);
    } else {
      newList.add(presetId);
    }
    state = AsyncData(newList);
    _persist();
  }

  // WHY: Set multiple presets at once (replaces current selection)
  void setMultiple(List<int> presetIds) {
    state = AsyncData(List<int>.from(presetIds));
    _persist();
  }

  // WHY: Clear all selections
  void clear() {
    state = const AsyncData([]);
    _persist();
  }

  // WHY: Persist the selection asynchronously
  void _persist() {
    if (state.hasValue) {
      unawaited(
        ref
            .read(selectedPresetsServiceProvider)
            .setLastUsedPresets(state.requireValue),
      );
    }
  }
}
