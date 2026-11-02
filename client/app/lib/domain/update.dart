import 'dart:async';
import 'dart:io';

final class ReleaseInfo {
  const ReleaseInfo({
    required this.build,
    required this.version,
    required this.channel,
    required this.bytes,
    required this.sha256,
    required this.notes,
    required this.securityForce,
    required this.minServerApi,
  });

  final int build;
  final String version;
  final String channel;
  final int bytes;
  final String sha256;
  final Map<String, String> notes;
  final bool securityForce;
  final int minServerApi;

  String note(String locale) =>
      notes[locale] ?? notes[locale == 'en' ? 'zh-Hans' : 'en'] ?? '';
}

enum UpdateCheckReason { opening, resume, manual, clientTooOld }

enum UpdateFailure {
  interrupted,
  checksumMismatch,
  signatureMismatch,
  installFailed,
  installCancelled,
}

enum InstallResult { success, failed, cancelled }

final class DownloadedUpdate {
  const DownloadedUpdate(this.file);
  final File file;
}

final class UpdateCancellation {
  final Completer<void> _cancelledSignal = Completer<void>();
  bool _cancelled = false;
  bool get cancelled => _cancelled;
  Future<void> get whenCancelled => _cancelledSignal.future;
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _cancelledSignal.complete();
  }
}

final class UpdateCancelled implements Exception {
  const UpdateCancelled();
}

final class UpdateChecksumMismatch implements Exception {
  const UpdateChecksumMismatch();
}
