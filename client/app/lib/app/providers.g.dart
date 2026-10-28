// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appRuntime)
final appRuntimeProvider = AppRuntimeProvider._();

final class AppRuntimeProvider
    extends $FunctionalProvider<AppRuntime, AppRuntime, AppRuntime>
    with $Provider<AppRuntime> {
  AppRuntimeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appRuntimeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appRuntimeHash();

  @$internal
  @override
  $ProviderElement<AppRuntime> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppRuntime create(Ref ref) {
    return appRuntime(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppRuntime value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppRuntime>(value),
    );
  }
}

String _$appRuntimeHash() => r'cdd61510618a8fc50939086a0df049515c4aba61';

@ProviderFor(authRepository)
final authRepositoryProvider = AuthRepositoryProvider._();

final class AuthRepositoryProvider
    extends $FunctionalProvider<AuthRepository, AuthRepository, AuthRepository>
    with $Provider<AuthRepository> {
  AuthRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authRepositoryHash();

  @$internal
  @override
  $ProviderElement<AuthRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthRepository create(Ref ref) {
    return authRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthRepository>(value),
    );
  }
}

String _$authRepositoryHash() => r'2b5a44f971b81873ff3de0d2190e18e3be303d7a';

@ProviderFor(partitionStore)
final partitionStoreProvider = PartitionStoreProvider._();

final class PartitionStoreProvider
    extends $FunctionalProvider<LocalStore, LocalStore, LocalStore>
    with $Provider<LocalStore> {
  PartitionStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'partitionStoreProvider',
        isAutoDispose: true,
        dependencies: <ProviderOrFamily>[],
        $allTransitiveDependencies: <ProviderOrFamily>[],
      );

  @override
  String debugGetCreateSourceHash() => _$partitionStoreHash();

  @$internal
  @override
  $ProviderElement<LocalStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LocalStore create(Ref ref) {
    return partitionStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocalStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocalStore>(value),
    );
  }
}

String _$partitionStoreHash() => r'c4709c607032b10c09ce357df4efdbb46a89a791';
