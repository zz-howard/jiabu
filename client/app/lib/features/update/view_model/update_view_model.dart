import 'dart:async';
import 'dart:io';

import 'package:jiabu/app/providers.dart';
import 'package:jiabu/data/repositories/update_repository.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/domain/sync_state.dart';
import 'package:jiabu/domain/update.dart';
import 'package:jiabu/features/update/view_model/update_ui_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_view_model.g.dart';

@Riverpod(keepAlive: true)
class UpdateViewModel extends _$UpdateViewModel {
  UpdateCancellation? _cancellation;
  File? _prepared;
  int _installGeneration = 0;

  @override
  UpdateUiState build() {
    final runtime = ref.watch(appRuntimeProvider);
    final subscription = runtime.events.listen((_) {
      if (!ref.mounted) return;
      if (runtime.updates == null) {
        _cancellation?.cancel();
        _prepared = null;
        state = const UpdateUiState();
        return;
      }
      final tooOld = runtime.status == SyncStatus.clientTooOld;
      final release = runtime.availableUpdate;
      state = state.copyWith(
        clientTooOld: tooOld,
        release: release,
        bannerVisible: release != null,
      );
    });
    ref.onDispose(() {
      _cancellation?.cancel();
      unawaited(subscription.cancel());
    });
    return UpdateUiState(
      release: runtime.availableUpdate,
      bannerVisible: runtime.availableUpdate != null,
      clientTooOld: runtime.status == SyncStatus.clientTooOld,
    );
  }

  void open() => state = state.copyWith(sheetOpen: true);
  void closeSheet() => state = state.copyWith(sheetOpen: false);

  Future<void> dismiss() async {
    final release = state.release;
    final runtime = ref.read(appRuntimeProvider);
    if (release == null || runtime.updates == null || mandatory) return;
    await runtime.dismissUpdate(release);
    if (ref.mounted) {
      state = state.copyWith(bannerVisible: false, sheetOpen: false);
    }
  }

  bool get mandatory =>
      state.clientTooOld || (state.release?.securityForce ?? false);

  Future<void> download() async {
    final release = state.release;
    final repository = ref.read(appRuntimeProvider).updates;
    if (release == null || repository == null) return;
    final cancellation = UpdateCancellation();
    _cancellation = cancellation;
    state = state.copyWith(
      phase: UpdatePhase.downloading,
      received: 0,
      total: release.bytes,
      failure: null,
    );
    final result = await repository.download(
      release,
      cancellation: cancellation,
      onProgress: (received, total) {
        if (ref.mounted && identical(_cancellation, cancellation)) {
          state = state.copyWith(received: received, total: total);
        }
      },
    );
    if (!ref.mounted || !identical(_cancellation, cancellation)) return;
    _cancellation = null;
    switch (result) {
      case Ok<PreparedUpdate>(:final value):
        _prepared = value.file;
        if (value.canInstall) {
          await install();
        } else {
          state = state.copyWith(phase: UpdatePhase.needsPermission);
        }
      case Failure<PreparedUpdate>(:final code):
        if (code == 'cancelled') {
          state = state.copyWith(phase: UpdatePhase.available);
        } else {
          state = state.copyWith(
            phase: UpdatePhase.failed,
            failure: switch (code) {
              'checksum_mismatch' => UpdateFailure.checksumMismatch,
              'signature_mismatch' => UpdateFailure.signatureMismatch,
              _ => UpdateFailure.interrupted,
            },
          );
        }
    }
  }

  void cancelDownload() {
    _cancellation?.cancel();
  }

  Future<void> openSettings() async {
    await ref.read(appRuntimeProvider).updates?.openInstallSettings();
  }

  Future<void> install() async {
    final generation = ++_installGeneration;
    final file = _prepared;
    final release = state.release;
    final repository = ref.read(appRuntimeProvider).updates;
    if (file == null || release == null || repository == null) return;
    final permission = await repository.refreshPermission(file);
    if (!ref.mounted || generation != _installGeneration) return;
    if (permission case Ok<PreparedUpdate>(value: final prepared)
        when !prepared.canInstall) {
      state = state.copyWith(phase: UpdatePhase.needsPermission);
      return;
    }
    state = state.copyWith(phase: UpdatePhase.installing, failure: null);
    final result = await repository.install(file, release);
    if (!ref.mounted || generation != _installGeneration) return;
    if (result case Failure<void>(:final code)) {
      state = state.copyWith(
        phase: UpdatePhase.failed,
        failure: switch (code) {
          'signature_mismatch' => UpdateFailure.signatureMismatch,
          'install_cancelled' => UpdateFailure.installCancelled,
          _ => UpdateFailure.installFailed,
        },
      );
    }
  }

  Future<void> retry() async {
    if (state.failure == UpdateFailure.installFailed ||
        state.failure == UpdateFailure.installCancelled) {
      await install();
    } else {
      await download();
    }
  }
}
