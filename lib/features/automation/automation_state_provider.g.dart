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
    extends $NotifierProvider<AutomationState, AutomationStatus> {
  const AutomationStateProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'automationStateProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$automationStateHash();

  @$internal
  @override
  AutomationState create() => AutomationState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AutomationStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AutomationStatus>(value),
    );
  }
}

String _$automationStateHash() => r'526af3c3295550915331f10a4488c222fee7cae5';

abstract class _$AutomationState extends $Notifier<AutomationStatus> {
  AutomationStatus build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AutomationStatus, AutomationStatus>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AutomationStatus, AutomationStatus>,
        AutomationStatus,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
