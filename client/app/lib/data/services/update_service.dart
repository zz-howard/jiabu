import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:jiabu/data/services/app_settings_service.dart';
import 'package:jiabu/data/services/update_transport.dart';
import 'package:jiabu/data/sync/sync_policy.dart';
import 'package:jiabu/domain/update.dart';
import 'package:path/path.dart' as p;

base class UpdateService {
  UpdateService({
    required this.transport,
    required this.settings,
    required this.directory,
    required this.server,
    required this.channel,
    required this.localBuild,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final UpdateTransport transport;
  final AppSettingsService settings;
  final Directory directory;
  final String server;
  final String channel;
  final int localBuild;
  final DateTime Function() now;
  Future<ReleaseInfo?>? _checking;

  Future<ReleaseInfo?> check(UpdateCheckReason reason) {
    final current = _checking;
    if (current != null) return current;
    final next = _check(reason);
    _checking = next;
    return next.whenComplete(() {
      if (identical(_checking, next)) _checking = null;
    });
  }

  Future<ReleaseInfo?> _check(UpdateCheckReason reason) async {
    final checked = await settings.updateLastChecked(server, channel);
    final current = now().toUtc();
    if (reason == UpdateCheckReason.resume &&
        checked != null &&
        current.difference(checked) < SyncPolicy.updateCheckInterval) {
      return null;
    }
    await settings.setUpdateLastChecked(server, channel, current);
    final release = await transport.latest(channel);
    if (release == null || release.build <= localBuild) return null;
    await _removeOtherBuilds(release.build);
    if (reason == UpdateCheckReason.manual ||
        reason == UpdateCheckReason.clientTooOld ||
        release.securityForce) {
      return release;
    }
    final dismissed = await settings.dismissedUpdate(channel);
    if (dismissed != null &&
        dismissed.build == release.build &&
        current.difference(dismissed.at) < SyncPolicy.updateDismissInterval) {
      return null;
    }
    return release;
  }

  Future<void> dismiss(ReleaseInfo release) =>
      settings.dismissUpdate(channel, release.build, now().toUtc());

  Future<File> download(
    ReleaseInfo release, {
    required UpdateCancellation cancellation,
    required void Function(int received, int total) onProgress,
  }) async {
    directory.createSync(recursive: true);
    final complete = _file(release.build, '.apk');
    if (complete.existsSync()) {
      if (await _matches(complete, release)) {
        return complete;
      }
      complete.deleteSync();
    }
    final partial = _file(release.build, '.apk.part');
    var start = partial.existsSync() ? partial.lengthSync() : 0;
    if (start >= release.bytes) {
      partial.deleteSync();
      start = 0;
    }
    var response = await transport.download(
      build: release.build,
      start: start,
      cancellation: cancellation,
    );
    if (response.statusCode == 416) {
      if (partial.existsSync()) {
        partial.deleteSync();
      }
      start = 0;
      response = await transport.download(
        build: release.build,
        start: 0,
        cancellation: cancellation,
      );
    }
    if (response.statusCode == 200) {
      start = 0;
    } else if (response.statusCode != 206 || response.start != start) {
      if (partial.existsSync()) {
        partial.deleteSync();
      }
      throw const FileSystemException('invalid_range_response');
    }
    final sink = partial.openWrite(
      mode: start == 0 ? FileMode.write : FileMode.append,
    );
    var received = start;
    try {
      await for (final chunk in response.bytes) {
        if (cancellation.cancelled) throw const UpdateCancelled();
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, release.bytes);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (received != release.bytes || !await _matches(partial, release)) {
      if (partial.existsSync()) {
        partial.deleteSync();
      }
      throw const UpdateChecksumMismatch();
    }
    if (complete.existsSync()) {
      complete.deleteSync();
    }
    return partial.renameSync(complete.path);
  }

  Future<void> deletePackage(int build) {
    for (final suffix in const ['.apk.part', '.apk']) {
      final file = _file(build, suffix);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
    return Future<void>.value();
  }

  File _file(int build, String suffix) =>
      File(p.join(directory.path, 'jiabu-$build$suffix'));

  Future<bool> _matches(File file, ReleaseInfo release) async {
    if (file.lengthSync() != release.bytes) {
      return false;
    }
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString().toLowerCase() == release.sha256.toLowerCase();
  }

  Future<void> _removeOtherBuilds(int build) {
    if (!directory.existsSync()) {
      return Future<void>.value();
    }
    for (final entity in directory.listSync()) {
      if (entity is File &&
          p.basename(entity.path).startsWith('jiabu-') &&
          !p.basename(entity.path).startsWith('jiabu-$build.')) {
        entity.deleteSync();
      }
    }
    return Future<void>.value();
  }
}
