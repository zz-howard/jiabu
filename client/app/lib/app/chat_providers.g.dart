// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(chatRepository)
final chatRepositoryProvider = ChatRepositoryProvider._();

final class ChatRepositoryProvider
    extends $FunctionalProvider<ChatRepository, ChatRepository, ChatRepository>
    with $Provider<ChatRepository> {
  ChatRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatRepositoryHash();

  @$internal
  @override
  $ProviderElement<ChatRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ChatRepository create(Ref ref) {
    return chatRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatRepository>(value),
    );
  }
}

String _$chatRepositoryHash() => r'a8d9d2bf8c19ed0dfa07e3077bf8248a81d7f133';

@ProviderFor(chatRegistry)
final chatRegistryProvider = ChatRegistryFamily._();

final class ChatRegistryProvider
    extends $FunctionalProvider<BlockRegistry, BlockRegistry, BlockRegistry>
    with $Provider<BlockRegistry> {
  ChatRegistryProvider._({
    required ChatRegistryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'chatRegistryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$chatRegistryHash();

  @override
  String toString() {
    return r'chatRegistryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<BlockRegistry> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BlockRegistry create(Ref ref) {
    final argument = this.argument as String;
    return chatRegistry(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BlockRegistry value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BlockRegistry>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChatRegistryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$chatRegistryHash() => r'e4c0191cb89391fa0a80601894039592bc9cc74d';

final class ChatRegistryFamily extends $Family
    with $FunctionalFamilyOverride<BlockRegistry, String> {
  ChatRegistryFamily._()
    : super(
        retry: null,
        name: r'chatRegistryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ChatRegistryProvider call(String spaceId) =>
      ChatRegistryProvider._(argument: spaceId, from: this);

  @override
  String toString() => r'chatRegistryProvider';
}
