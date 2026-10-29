// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'c4_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Each route/modal owns an auto-disposed form; no secret is in freezed state,
/// toString, persistence, logs, or a reusable list/detail result.

@ProviderFor(C4ViewModel)
final c4ViewModelProvider = C4ViewModelFamily._();

/// Each route/modal owns an auto-disposed form; no secret is in freezed state,
/// toString, persistence, logs, or a reusable list/detail result.
final class C4ViewModelProvider
    extends $NotifierProvider<C4ViewModel, C4UiState> {
  /// Each route/modal owns an auto-disposed form; no secret is in freezed state,
  /// toString, persistence, logs, or a reusable list/detail result.
  C4ViewModelProvider._({
    required C4ViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'c4ViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$c4ViewModelHash();

  @override
  String toString() {
    return r'c4ViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  C4ViewModel create() => C4ViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(C4UiState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<C4UiState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is C4ViewModelProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$c4ViewModelHash() => r'ac201a5ae973b26ecab3730b5678b320492d728a';

/// Each route/modal owns an auto-disposed form; no secret is in freezed state,
/// toString, persistence, logs, or a reusable list/detail result.

final class C4ViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          C4ViewModel,
          C4UiState,
          C4UiState,
          C4UiState,
          String
        > {
  C4ViewModelFamily._()
    : super(
        retry: null,
        name: r'c4ViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Each route/modal owns an auto-disposed form; no secret is in freezed state,
  /// toString, persistence, logs, or a reusable list/detail result.

  C4ViewModelProvider call(String formId) =>
      C4ViewModelProvider._(argument: formId, from: this);

  @override
  String toString() => r'c4ViewModelProvider';
}

/// Each route/modal owns an auto-disposed form; no secret is in freezed state,
/// toString, persistence, logs, or a reusable list/detail result.

abstract class _$C4ViewModel extends $Notifier<C4UiState> {
  late final _$args = ref.$arg as String;
  String get formId => _$args;

  C4UiState build(String formId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<C4UiState, C4UiState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<C4UiState, C4UiState>,
              C4UiState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
