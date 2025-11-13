// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'selected_presets_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(selectedPresetsService)
const selectedPresetsServiceProvider = SelectedPresetsServiceProvider._();

final class SelectedPresetsServiceProvider
    extends
        $FunctionalProvider<
          SelectedPresetsService,
          SelectedPresetsService,
          SelectedPresetsService
        >
    with $Provider<SelectedPresetsService> {
  const SelectedPresetsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedPresetsServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedPresetsServiceHash();

  @$internal
  @override
  $ProviderElement<SelectedPresetsService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SelectedPresetsService create(Ref ref) {
    return selectedPresetsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SelectedPresetsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SelectedPresetsService>(value),
    );
  }
}

String _$selectedPresetsServiceHash() =>
    r'acf3cb6ce3ab1c946903ec02c68ec5c5113ae713';

@ProviderFor(SelectedPresetIds)
const selectedPresetIdsProvider = SelectedPresetIdsProvider._();

final class SelectedPresetIdsProvider
    extends $NotifierProvider<SelectedPresetIds, List<int>> {
  const SelectedPresetIdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedPresetIdsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedPresetIdsHash();

  @$internal
  @override
  SelectedPresetIds create() => SelectedPresetIds();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<int> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<int>>(value),
    );
  }
}

String _$selectedPresetIdsHash() => r'd7c1534bbdd5662081f4a6709442561eeed73950';

abstract class _$SelectedPresetIds extends $Notifier<List<int>> {
  List<int> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<List<int>, List<int>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<int>, List<int>>,
              List<int>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
