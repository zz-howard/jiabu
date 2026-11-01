// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AuthViewModel)
final authViewModelProvider = AuthViewModelProvider._();

final class AuthViewModelProvider
    extends $NotifierProvider<AuthViewModel, AuthUiState> {
  AuthViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authViewModelHash();

  @$internal
  @override
  AuthViewModel create() => AuthViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthUiState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthUiState>(value),
    );
  }
}

String _$authViewModelHash() => r'3e44aaac956ead843a3fc71bcdd9fb8a85bff58f';

abstract class _$AuthViewModel extends $Notifier<AuthUiState> {
  AuthUiState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AuthUiState, AuthUiState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AuthUiState, AuthUiState>,
              AuthUiState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
