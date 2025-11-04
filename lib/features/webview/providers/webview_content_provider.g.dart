// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webview_content_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(initialWebViewContent)
const initialWebViewContentProvider = InitialWebViewContentProvider._();

final class InitialWebViewContentProvider
    extends $FunctionalProvider<WebViewContent, WebViewContent, WebViewContent>
    with $Provider<WebViewContent> {
  const InitialWebViewContentProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'initialWebViewContentProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$initialWebViewContentHash();

  @$internal
  @override
  $ProviderElement<WebViewContent> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WebViewContent create(Ref ref) {
    return initialWebViewContent(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WebViewContent value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WebViewContent>(value),
    );
  }
}

String _$initialWebViewContentHash() =>
    r'ee331a045b3cecadf508763704919dc7126f99e8';
