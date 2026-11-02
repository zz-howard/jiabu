import 'dart:io';

import 'package:jiabu/data/services/log_redactor_service.dart';
import 'package:jiabu/data/services/update_installer.dart';
import 'package:jiabu/data/services/update_service.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/domain/update.dart';
import 'package:logging/logging.dart';

final class PreparedUpdate {
  const PreparedUpdate(this.file, {required this.canInstall});
  final File file;
  final bool canInstall;
}

final class UpdateRepository {
  UpdateRepository(this.service, this.installer);
  final UpdateService service;
  final UpdateInstaller installer;

  Future<Result<ReleaseInfo?>> check(UpdateCheckReason reason) async {
    try {
      return Ok(await service.check(reason));
    } on Object {
      Logger('update')
          .warning(const SafeLogEvent('update_check_failed', code: 'network'));
      return const Failure('network');
    }
  }

  Future<void> dismiss(ReleaseInfo release) => service.dismiss(release);

  Future<Result<PreparedUpdate>> download(
    ReleaseInfo release, {
    required UpdateCancellation cancellation,
    required void Function(int received, int total) onProgress,
  }) async {
    try {
      final file = await service.download(
        release,
        cancellation: cancellation,
        onProgress: onProgress,
      );
      if (!await installer.verifySignature(file.path)) {
        await service.deletePackage(release.build);
        return const Failure('signature_mismatch');
      }
      return Ok(PreparedUpdate(file, canInstall: await installer.canInstall()));
    } on UpdateCancelled {
      return const Failure('cancelled');
    } on UpdateChecksumMismatch {
      return const Failure('checksum_mismatch');
    } on Object {
      return cancellation.cancelled
          ? const Failure('cancelled')
          : const Failure('network');
    }
  }

  Future<Result<PreparedUpdate>> refreshPermission(File file) async {
    try {
      return Ok(PreparedUpdate(file, canInstall: await installer.canInstall()));
    } on Object {
      return const Failure<PreparedUpdate>('install_failed');
    }
  }

  Future<Result<void>> openInstallSettings() async {
    try {
      await installer.openInstallSettings();
      return const Ok<void>(null);
    } on Object {
      return const Failure('install_failed');
    }
  }

  Future<Result<void>> install(File file, ReleaseInfo release) async {
    try {
      if (!await installer.verifySignature(file.path)) {
        await service.deletePackage(release.build);
        return const Failure<void>('signature_mismatch');
      }
      return switch (await installer.install(file.path)) {
        InstallResult.success => const Ok<void>(null),
        InstallResult.cancelled => const Failure<void>('install_cancelled'),
        InstallResult.failed => const Failure<void>('install_failed'),
      };
    } on Object {
      return const Failure<void>('install_failed');
    }
  }
}
