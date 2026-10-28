// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ledger_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LedgerViewModel)
final ledgerViewModelProvider = LedgerViewModelFamily._();

final class LedgerViewModelProvider
    extends $NotifierProvider<LedgerViewModel, LedgerUiState> {
  LedgerViewModelProvider._({
    required LedgerViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'ledgerViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$ledgerViewModelHash();

  @override
  String toString() {
    return r'ledgerViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  LedgerViewModel create() => LedgerViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LedgerUiState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LedgerUiState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LedgerViewModelProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$ledgerViewModelHash() => r'142367b9e2d90c35cbb66855546c98d010a4b72b';

final class LedgerViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          LedgerViewModel,
          LedgerUiState,
          LedgerUiState,
          LedgerUiState,
          String
        > {
  LedgerViewModelFamily._()
    : super(
        retry: null,
        name: r'ledgerViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  LedgerViewModelProvider call(String spaceId) =>
      LedgerViewModelProvider._(argument: spaceId, from: this);

  @override
  String toString() => r'ledgerViewModelProvider';
}

abstract class _$LedgerViewModel extends $Notifier<LedgerUiState> {
  late final _$args = ref.$arg as String;
  String get spaceId => _$args;

  LedgerUiState build(String spaceId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LedgerUiState, LedgerUiState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LedgerUiState, LedgerUiState>,
              LedgerUiState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(LedgerFormViewModel)
final ledgerFormViewModelProvider = LedgerFormViewModelFamily._();

final class LedgerFormViewModelProvider
    extends $NotifierProvider<LedgerFormViewModel, LedgerFormState> {
  LedgerFormViewModelProvider._({
    required LedgerFormViewModelFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'ledgerFormViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$ledgerFormViewModelHash();

  @override
  String toString() {
    return r'ledgerFormViewModelProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  LedgerFormViewModel create() => LedgerFormViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LedgerFormState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LedgerFormState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LedgerFormViewModelProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$ledgerFormViewModelHash() =>
    r'69e9be06dbae2880c2aeec83ffda8416c6cc188c';

final class LedgerFormViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          LedgerFormViewModel,
          LedgerFormState,
          LedgerFormState,
          LedgerFormState,
          (String, String)
        > {
  LedgerFormViewModelFamily._()
    : super(
        retry: null,
        name: r'ledgerFormViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  LedgerFormViewModelProvider call(String spaceId, String formId) =>
      LedgerFormViewModelProvider._(argument: (spaceId, formId), from: this);

  @override
  String toString() => r'ledgerFormViewModelProvider';
}

abstract class _$LedgerFormViewModel extends $Notifier<LedgerFormState> {
  late final _$args = ref.$arg as (String, String);
  String get spaceId => _$args.$1;
  String get formId => _$args.$2;

  LedgerFormState build(String spaceId, String formId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LedgerFormState, LedgerFormState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LedgerFormState, LedgerFormState>,
              LedgerFormState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
