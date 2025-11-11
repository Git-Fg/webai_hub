// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'presets_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(presets)
const presetsProvider = PresetsProvider._();

final class PresetsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PresetData>>,
          List<PresetData>,
          Stream<List<PresetData>>
        >
    with $FutureModifier<List<PresetData>>, $StreamProvider<List<PresetData>> {
  const PresetsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'presetsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$presetsHash();

  @$internal
  @override
  $StreamProviderElement<List<PresetData>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<PresetData>> create(Ref ref) {
    return presets(ref);
  }
}

String _$presetsHash() => r'5c6b3ae09a968fa1b0e325982c828e10d9af434d';
