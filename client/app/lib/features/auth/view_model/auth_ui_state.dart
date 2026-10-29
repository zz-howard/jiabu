import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:jiabu/domain/sync_state.dart';

part 'auth_ui_state.freezed.dart';

enum AuthPage { loading, welcome, server, login, password, session }

@freezed
abstract class AuthUiState with _$AuthUiState {
  const factory AuthUiState({
    @Default(AuthPage.loading) AuthPage page,
    @Default(false) bool busy,
    @Default(false) bool authenticated,
    @Default(false) bool forcedPassword,
    @Default('') String server,
    @Default('') String defaultServer,
    @Default(<String>[]) List<String> servers,
    @Default(false) bool serverProbeSucceeded,
    String? errorCode,
    DateTime? adminResetAt,
    int? switchCount,
    @Default(0) int partitionRevision,
    @Default(SyncStatus.idle) SyncStatus syncStatus,
    @Default(false) bool spaceCleared,
    @Default(0) int clearedCount,
  }) = _AuthUiState;
}
