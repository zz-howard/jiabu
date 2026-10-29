// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'c4_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(spacesRepository)
final spacesRepositoryProvider = SpacesRepositoryProvider._();

final class SpacesRepositoryProvider
    extends
        $FunctionalProvider<
          SpacesRepository,
          SpacesRepository,
          SpacesRepository
        >
    with $Provider<SpacesRepository> {
  SpacesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'spacesRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$spacesRepositoryHash();

  @$internal
  @override
  $ProviderElement<SpacesRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SpacesRepository create(Ref ref) {
    return spacesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SpacesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SpacesRepository>(value),
    );
  }
}

String _$spacesRepositoryHash() => r'81411068741b5815c425d3069bbbe15d6f51df88';

@ProviderFor(apiKeysRepository)
final apiKeysRepositoryProvider = ApiKeysRepositoryProvider._();

final class ApiKeysRepositoryProvider
    extends
        $FunctionalProvider<
          ApiKeysRepository,
          ApiKeysRepository,
          ApiKeysRepository
        >
    with $Provider<ApiKeysRepository> {
  ApiKeysRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'apiKeysRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$apiKeysRepositoryHash();

  @$internal
  @override
  $ProviderElement<ApiKeysRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ApiKeysRepository create(Ref ref) {
    return apiKeysRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ApiKeysRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ApiKeysRepository>(value),
    );
  }
}

String _$apiKeysRepositoryHash() => r'aa1324a39d103eab5767573a0f04c628a0968f5f';

@ProviderFor(spacesDirectory)
final spacesDirectoryProvider = SpacesDirectoryProvider._();

final class SpacesDirectoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SpaceInfo>>,
          List<SpaceInfo>,
          Stream<List<SpaceInfo>>
        >
    with $FutureModifier<List<SpaceInfo>>, $StreamProvider<List<SpaceInfo>> {
  SpacesDirectoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'spacesDirectoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$spacesDirectoryHash();

  @$internal
  @override
  $StreamProviderElement<List<SpaceInfo>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<SpaceInfo>> create(Ref ref) {
    return spacesDirectory(ref);
  }
}

String _$spacesDirectoryHash() => r'82d41bd78084661b7d9e862898b54860404b4c76';

@ProviderFor(lockEvents)
final lockEventsProvider = LockEventsProvider._();

final class LockEventsProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  LockEventsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lockEventsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lockEventsHash();

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    return lockEvents(ref);
  }
}

String _$lockEventsHash() => r'acb86ab8b361209289e881e7f978252b900a4bf7';

@ProviderFor(deviceTimezone)
final deviceTimezoneProvider = DeviceTimezoneProvider._();

final class DeviceTimezoneProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  DeviceTimezoneProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceTimezoneProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceTimezoneHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return deviceTimezone(ref);
  }
}

String _$deviceTimezoneHash() => r'f634254f893d38a03044f1c24d29ea8258453a3d';

@ProviderFor(activeKeyCount)
final activeKeyCountProvider = ActiveKeyCountProvider._();

final class ActiveKeyCountProvider
    extends $FunctionalProvider<AsyncValue<int?>, int?, FutureOr<int?>>
    with $FutureModifier<int?>, $FutureProvider<int?> {
  ActiveKeyCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeKeyCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeKeyCountHash();

  @$internal
  @override
  $FutureProviderElement<int?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int?> create(Ref ref) {
    return activeKeyCount(ref);
  }
}

String _$activeKeyCountHash() => r'54b2edfc7c075f6be9c95e23692cec7821b0ef49';

@ProviderFor(restrictedAuthenticationReady)
final restrictedAuthenticationReadyProvider =
    RestrictedAuthenticationReadyProvider._();

final class RestrictedAuthenticationReadyProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  RestrictedAuthenticationReadyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'restrictedAuthenticationReadyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$restrictedAuthenticationReadyHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return restrictedAuthenticationReady(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$restrictedAuthenticationReadyHash() =>
    r'40cf9797a2a9f4452fcb706d5bbcb73939d39945';
