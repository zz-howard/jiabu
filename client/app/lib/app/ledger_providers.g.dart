// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ledger_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ledgerRepository)
final ledgerRepositoryProvider = LedgerRepositoryProvider._();

final class LedgerRepositoryProvider
    extends
        $FunctionalProvider<
          LedgerRepository,
          LedgerRepository,
          LedgerRepository
        >
    with $Provider<LedgerRepository> {
  LedgerRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ledgerRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ledgerRepositoryHash();

  @$internal
  @override
  $ProviderElement<LedgerRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LedgerRepository create(Ref ref) {
    return ledgerRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LedgerRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LedgerRepository>(value),
    );
  }
}

String _$ledgerRepositoryHash() => r'2abceb8b44c502626bd2660b2eb9bd9fa41bfe6a';

@ProviderFor(currentLedgerSpace)
final currentLedgerSpaceProvider = CurrentLedgerSpaceProvider._();

final class CurrentLedgerSpaceProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, Stream<String?>>
    with $FutureModifier<String?>, $StreamProvider<String?> {
  CurrentLedgerSpaceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentLedgerSpaceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentLedgerSpaceHash();

  @$internal
  @override
  $StreamProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<String?> create(Ref ref) {
    return currentLedgerSpace(ref);
  }
}

String _$currentLedgerSpaceHash() =>
    r'7e77addac4dac3a9e72cf3cc9a2ee6cf90ed471f';

@ProviderFor(MainNavigation)
final mainNavigationProvider = MainNavigationProvider._();

final class MainNavigationProvider
    extends $NotifierProvider<MainNavigation, int> {
  MainNavigationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mainNavigationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mainNavigationHash();

  @$internal
  @override
  MainNavigation create() => MainNavigation();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$mainNavigationHash() => r'c570b2a6839ccf1fab8be4cec0fbc997abe81395';

abstract class _$MainNavigation extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Runtime status can change while the current space ID stays equal. A distinct
/// event counter keeps the shell's offline/auth notices reactive as well.

@ProviderFor(ledgerRuntimeEvents)
final ledgerRuntimeEventsProvider = LedgerRuntimeEventsProvider._();

/// Runtime status can change while the current space ID stays equal. A distinct
/// event counter keeps the shell's offline/auth notices reactive as well.

final class LedgerRuntimeEventsProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  /// Runtime status can change while the current space ID stays equal. A distinct
  /// event counter keeps the shell's offline/auth notices reactive as well.
  LedgerRuntimeEventsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ledgerRuntimeEventsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ledgerRuntimeEventsHash();

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    return ledgerRuntimeEvents(ref);
  }
}

String _$ledgerRuntimeEventsHash() =>
    r'bf2480c45064a8f6b0c8f66ef081cec84c04ab2a';
