// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(UpdateViewModel)
final updateViewModelProvider = UpdateViewModelProvider._();

final class UpdateViewModelProvider
    extends $NotifierProvider<UpdateViewModel, UpdateUiState> {
  UpdateViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateViewModelHash();

  @$internal
  @override
  UpdateViewModel create() => UpdateViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateUiState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateUiState>(value),
    );
  }
}

String _$updateViewModelHash() => r'eab811658eb726713ff83eab0b92d97272da24c0';

abstract class _$UpdateViewModel extends $Notifier<UpdateUiState> {
  UpdateUiState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<UpdateUiState, UpdateUiState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UpdateUiState, UpdateUiState>,
              UpdateUiState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
