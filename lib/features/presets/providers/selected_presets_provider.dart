// lib/features/presets/providers/selected_presets_provider.dart

import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'selected_presets_provider.g.dart';

const _boxName = 'app_state_box';
const _lastKey = 'last_used_preset_ids';

// WHY: Service to persist selected preset IDs in Hive
// WHY: Box is opened synchronously in main.dart, so we can access it directly
class SelectedPresetsService {
  Box<dynamic> get _box => Hive.box<dynamic>(_boxName);

  List<int> getLastUsedPresets() {
    final stored = _box.get(_lastKey);
    if (stored is List) {
      return stored.cast<int>();
    }
    return [];
  }

  Future<void> setLastUsedPresets(List<int> presetIds) async {
    await _box.put(_lastKey, presetIds);
  }
}

@riverpod
SelectedPresetsService selectedPresetsService(Ref ref) {
  return SelectedPresetsService();
}

// WHY: This provider holds the IDs of presets the user has selected
// in the Hub UI. It supports both single and multi-selection modes.
// It's kept alive to remember the user's choice across the app.
// WHY: Box is opened synchronously in main.dart, so we can load the initial
// value synchronously and return List<int> directly instead of AsyncValue.
@Riverpod(keepAlive: true)
class SelectedPresetIds extends _$SelectedPresetIds {
  @override
  List<int> build() {
    final service = ref.read(selectedPresetsServiceProvider);
    final lastUsed = service.getLastUsedPresets();

    if (lastUsed.isNotEmpty) {
      return lastUsed;
    }

    // Set a default if no saved value exists.
    // WHY: We can't await presetsProvider here since build() is synchronous.
    // The default will be set when presets are first loaded via a listener or
    // the UI will handle empty selection gracefully.
    return [];
  }

  // WHY: Set a single preset (replaces current selection)
  void setSingle(int presetId) {
    state = [presetId];
    _persist();
  }

  // WHY: Toggle a preset in the selection (for multi-select mode)
  void toggle(int presetId) {
    final newList = List<int>.from(state);
    if (newList.contains(presetId)) {
      newList.remove(presetId);
    } else {
      newList.add(presetId);
    }
    state = newList;
    _persist();
  }

  // WHY: Set multiple presets at once (replaces current selection)
  void setMultiple(List<int> presetIds) {
    state = List<int>.from(presetIds);
    _persist();
  }

  // WHY: Clear all selections
  void clear() {
    state = [];
    _persist();
  }

  // WHY: Persist the selection asynchronously
  void _persist() {
    unawaited(
      ref.read(selectedPresetsServiceProvider).setLastUsedPresets(state),
    );
  }
}
