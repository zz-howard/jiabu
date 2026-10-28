import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:jiabu/domain/history_filter.dart';
import 'package:jiabu/domain/ledger.dart';

part 'ledger_ui_state.freezed.dart';

@freezed
abstract class LedgerUiState with _$LedgerUiState {
  const factory LedgerUiState({
    LedgerSnapshot? snapshot,
    @Default(HistoryFilter()) HistoryFilter filter,
    @Default(false) bool busy,
    String? error,
  }) = _LedgerUiState;
}

@freezed
abstract class LedgerFormState with _$LedgerFormState {
  const factory LedgerFormState({
    @Default(<String, Object?>{}) Map<String, Object?> values,
    @Default(false) bool busy,
    String? error,
  }) = _LedgerFormState;
}
