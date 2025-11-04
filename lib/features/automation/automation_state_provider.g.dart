// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'automation_state_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AutomationState)
const automationStateProvider = AutomationStateProvider._();

final class AutomationStateProvider
    extends $NotifierProvider<AutomationState, AutomationStateData> {
  const AutomationStateProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'automationStateProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$automationStateHash();

  @$internal
  @override
  AutomationState create() => AutomationState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AutomationStateData value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AutomationStateData>(value),
    );
  }
}

String _$automationStateHash() => r'71713d6dd13fc24c0686da24088d63f5b644163a';

abstract class _$AutomationState extends $Notifier<AutomationStateData> {
  AutomationStateData build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AutomationStateData, AutomationStateData>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AutomationStateData, AutomationStateData>,
        AutomationStateData,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

/// Provider for extraction state during phase 3

@ProviderFor(IsExtracting)
const isExtractingProvider = IsExtractingProvider._();

/// Provider for extraction state during phase 3
final class IsExtractingProvider extends $NotifierProvider<IsExtracting, bool> {
  /// Provider for extraction state during phase 3
  const IsExtractingProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'isExtractingProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$isExtractingHash();

  @$internal
  @override
  IsExtracting create() => IsExtracting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isExtractingHash() => r'504af2c83363ee55c63ca8e079ba22c6e5f16e03';

/// Provider for extraction state during phase 3

abstract class _$IsExtracting extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<bool, bool>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<bool, bool>, bool, Object?, Object?>;
    element.handleValue(ref, created);
  }
}
