// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'record_details.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(recordImage)
final recordImageProvider = RecordImageFamily._();

final class RecordImageProvider
    extends
        $FunctionalProvider<
          AsyncValue<Result<List<int>>>,
          Result<List<int>>,
          FutureOr<Result<List<int>>>
        >
    with
        $FutureModifier<Result<List<int>>>,
        $FutureProvider<Result<List<int>>> {
  RecordImageProvider._({
    required RecordImageFamily super.from,
    required (String, String, {bool download}) super.argument,
  }) : super(
         retry: null,
         name: r'recordImageProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$recordImageHash();

  @override
  String toString() {
    return r'recordImageProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<Result<List<int>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Result<List<int>>> create(Ref ref) {
    final argument = this.argument as (String, String, {bool download});
    return recordImage(
      ref,
      argument.$1,
      argument.$2,
      download: argument.download,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RecordImageProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$recordImageHash() => r'9e05a76d76176caf9ab5425ce8253c9b208350b5';

final class RecordImageFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<Result<List<int>>>,
          (String, String, {bool download})
        > {
  RecordImageFamily._()
    : super(
        retry: null,
        name: r'recordImageProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  RecordImageProvider call(
    String spaceId,
    String hash, {
    bool download = false,
  }) => RecordImageProvider._(
    argument: (spaceId, hash, download: download),
    from: this,
  );

  @override
  String toString() => r'recordImageProvider';
}
