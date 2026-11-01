// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ChatViewModel)
final chatViewModelProvider = ChatViewModelFamily._();

final class ChatViewModelProvider
    extends $NotifierProvider<ChatViewModel, ChatUiState> {
  ChatViewModelProvider._({
    required ChatViewModelFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'chatViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$chatViewModelHash();

  @override
  String toString() {
    return r'chatViewModelProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  ChatViewModel create() => ChatViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatUiState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatUiState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChatViewModelProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$chatViewModelHash() => r'1688f3bf6915d8985a6c73f6ae147e9f61c6d966';

final class ChatViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          ChatViewModel,
          ChatUiState,
          ChatUiState,
          ChatUiState,
          (String, String)
        > {
  ChatViewModelFamily._()
    : super(
        retry: null,
        name: r'chatViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ChatViewModelProvider call(String spaceId, String locale) =>
      ChatViewModelProvider._(argument: (spaceId, locale), from: this);

  @override
  String toString() => r'chatViewModelProvider';
}

abstract class _$ChatViewModel extends $Notifier<ChatUiState> {
  late final _$args = ref.$arg as (String, String);
  String get spaceId => _$args.$1;
  String get locale => _$args.$2;

  ChatUiState build(String spaceId, String locale);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ChatUiState, ChatUiState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ChatUiState, ChatUiState>,
              ChatUiState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
