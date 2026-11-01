import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:jiabu/domain/chat.dart';
import 'package:jiabu/domain/chat_files.dart';
part 'chat_ui_state.freezed.dart';

@freezed
abstract class ChatUiState with _$ChatUiState {
  const factory ChatUiState({
    ChatConversation? conversation,
    @Default(false) bool busy,
    @Default('') String draft,
    @Default(<String>[]) List<String> images,
    @Default(<ChatFile>[]) List<ChatFile> files,
    @Default(0) int revision,
    @Default(<String>{}) Set<String> stopping,
    String? error,
  }) = _ChatUiState;
}
