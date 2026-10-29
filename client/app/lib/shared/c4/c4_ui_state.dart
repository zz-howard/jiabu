import 'package:freezed_annotation/freezed_annotation.dart';

part 'c4_ui_state.freezed.dart';

@freezed
abstract class C4UiState with _$C4UiState {
  const factory C4UiState({
    @Default(false) bool busy,
    @Default(false) bool online,
    @Default(false) bool copied,
    @Default(0) int revision,
    @Default(<String, Object?>{}) Map<String, Object?> values,
    @Default(<Map<String, Object?>>[]) List<Map<String, Object?>> rows,
    String? error,
  }) = _C4UiState;
}
