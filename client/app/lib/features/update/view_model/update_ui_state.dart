import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:jiabu/domain/update.dart';

part 'update_ui_state.freezed.dart';

enum UpdatePhase {
  available,
  downloading,
  verifying,
  needsPermission,
  installing,
  failed,
}

@freezed
abstract class UpdateUiState with _$UpdateUiState {
  const factory UpdateUiState({
    ReleaseInfo? release,
    @Default(false) bool bannerVisible,
    @Default(false) bool clientTooOld,
    @Default(false) bool sheetOpen,
    @Default(UpdatePhase.available) UpdatePhase phase,
    @Default(0) int received,
    @Default(0) int total,
    UpdateFailure? failure,
  }) = _UpdateUiState;
}
