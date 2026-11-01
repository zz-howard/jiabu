import 'dart:async';

import 'package:jiabu/app/chat_providers.dart';
import 'package:jiabu/domain/chat.dart';
import 'package:jiabu/domain/chat_files.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/features/chat/view_model/chat_ui_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat_view_model.g.dart';

@riverpod
class ChatViewModel extends _$ChatViewModel {
  @override
  ChatUiState build(String spaceId, String locale) {
    final repository = ref.watch(chatRepositoryProvider);
    final registry = ref.watch(chatRegistryProvider(spaceId));
    StreamSubscription<void>? subscription;
    ChatConversation? owned;
    var connecting = false;
    Future<void> connect() async {
      if (connecting || !ref.mounted) {
        return;
      }
      connecting = true;
      try {
        final result = await repository.open(
          spaceId,
          registry.capabilities(locale: locale),
        );
        if (!ref.mounted) {
          if (result is Ok<ChatConversation>) {
            await result.value.disconnect();
          }
          return;
        }
        switch (result) {
          case Ok(:final value):
            owned = value;
            await subscription?.cancel();
            state = state.copyWith(
              conversation: value,
              draft: value.draft,
              images: value.draftImages,
              files: value.draftFiles,
              error: null,
            );
            subscription = value.changes.listen((_) {
              if (!ref.mounted) {
                return;
              }
              if (value.error == 'stale_response') {
                state = state.copyWith(
                  conversation: null,
                  draft: '',
                  images: const [],
                  files: const [],
                );
                unawaited(connect());
              } else {
                state = state.copyWith(
                  revision: state.revision + 1,
                  error: value.error,
                );
              }
            });
            unawaited(value.recover());
          case Failure(:final code):
            state = state.copyWith(error: code);
        }
      } on Object {
        if (ref.mounted) {
          state = state.copyWith(error: 'local_read_failed');
        }
      } finally {
        connecting = false;
      }
    }

    unawaited(Future<void>(connect));
    ref.onDispose(() {
      unawaited(subscription?.cancel());
      unawaited(owned?.disconnect());
    });
    return const ChatUiState();
  }

  void draft(String text) {
    state = state.copyWith(draft: text);
    unawaited(state.conversation?.saveDraft(text, state.images, state.files));
  }

  void removePhoto(String hash) {
    state = state.copyWith(
      images: state.images.where((image) => image != hash).toList(),
    );
    unawaited(_saveDraft());
  }

  void removeFile(String sha256) {
    state = state.copyWith(
      files: state.files.where((file) => file.sha256 != sha256).toList(),
    );
    unawaited(_saveDraft());
  }

  Future<void> _saveDraft() async {
    await state.conversation?.saveDraft(state.draft, state.images, state.files);
  }

  /// The 文件 tab: images and PDFs in one selection; limits count what the
  /// draft holds already.
  Future<void> attachDocuments() async {
    final session = state.conversation;
    if (session == null || state.busy) {
      return;
    }
    if (state.files.length >= ChatFileLimits.maxFiles &&
        state.images.length >= ChatFileLimits.maxImages) {
      state = state.copyWith(error: 'chat_too_large');
      return;
    }
    state = state.copyWith(busy: true);
    final result = await session.documents(
      images: state.images,
      files: state.files,
    );
    if (!ref.mounted) {
      return;
    }
    switch (result) {
      case Ok(:final value):
        final known = {for (final file in state.files) file.sha256};
        state = state.copyWith(
          busy: false,
          images: {...state.images, ...value.images}.toList(),
          files: [
            ...state.files,
            ...value.files.where((file) => known.add(file.sha256)),
          ],
          error: null,
        );
        await _saveDraft();
      case Failure(:final code):
        state = state.copyWith(busy: false, error: code);
    }
  }

  Future<void> photos({required bool camera, bool files = false}) async {
    final session = state.conversation;
    if (session == null || state.busy) {
      return;
    }
    if (state.images.length >= 8) {
      state = state.copyWith(error: 'chat_too_large');
      return;
    }
    state = state.copyWith(busy: true);
    final result = await session.photos(
      camera: camera,
      files: files,
      limit: 8 - state.images.length,
    );
    if (!ref.mounted) {
      return;
    }
    switch (result) {
      case Ok(:final value):
        final images = {...state.images, ...value}.toList();
        state = state.copyWith(
          busy: false,
          images: images.take(8).toList(),
          error: images.length > 8 ? 'chat_too_large' : null,
        );
        await _saveDraft();
      case Failure(:final code):
        state = state.copyWith(busy: false, error: code);
    }
  }

  Future<bool> send(String text) async {
    final session = state.conversation;
    if (session == null || state.busy) {
      return false;
    }
    state = state.copyWith(busy: true, error: null);
    final result = await session.send(text, state.images, files: state.files);
    if (!ref.mounted) {
      return false;
    }
    if (result is Ok<void>) {
      state = state.copyWith(
        busy: false,
        draft: '',
        images: const [],
        files: const [],
      );
      await session.saveDraft('', const [], const []);
      return true;
    }
    state = state.copyWith(busy: false, error: (result as Failure<void>).code);
    return false;
  }

  Future<void> stop(String id) async {
    final session = state.conversation;
    if (session == null || state.stopping.contains(id)) {
      return;
    }
    state = state.copyWith(stopping: {...state.stopping, id});
    final result = await session.stop(id);
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      error: result is Failure<void> ? result.code : null,
      stopping: result is Failure<void> && result.code == 'chat_online_required'
          ? state.stopping.where((message) => message != id).toSet()
          : state.stopping,
    );
  }

  /// Extends the chat history window by one older page.
  Future<void> loadOlder() => _page((session) => session.loadOlder());

  /// Extends a jumped window by one newer page.
  Future<void> loadNewer() => _page((session) => session.loadNewer());

  Future<void> _page(
    Future<Result<void>> Function(ChatConversation session) load,
  ) async {
    final session = state.conversation;
    if (session == null) {
      return;
    }
    // Success arrives through the session's changes; a failure is shown.
    if (await load(session) case Failure(:final code) when ref.mounted) {
      state = state.copyWith(error: code);
    }
  }

  Future<void> command(Future<Result<void>> Function() action) async {
    final result = await action();
    if (ref.mounted) {
      state = state.copyWith(
        error: result is Failure<void> ? result.code : null,
      );
    }
  }

  Future<Map<String, Object?>?> takeOver(String id) async {
    final session = state.conversation;
    if (session == null || state.busy) {
      return null;
    }
    state = state.copyWith(busy: true);
    final result = await session.takeOver(id);
    if (!ref.mounted) {
      return null;
    }
    state = state.copyWith(
      busy: false,
      error: result is Failure<Map<String, Object?>> ? result.code : null,
    );
    return result is Ok<Map<String, Object?>> ? result.value : null;
  }
}
