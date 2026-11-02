import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/repositories/update_repository.dart';
import 'package:jiabu/data/services/app_settings_service.dart';
import 'package:jiabu/data/services/update_installer.dart';
import 'package:jiabu/data/services/update_service.dart';
import 'package:jiabu/data/services/update_transport.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/domain/update.dart';

final class _Installer implements UpdateInstaller {
  _Installer({this.signature = true, this.permission = true});
  final bool signature;
  final bool permission;
  int installs = 0;
  @override
  Future<bool> verifySignature(String path) async => signature;
  @override
  Future<bool> canInstall() async => permission;
  @override
  Future<void> openInstallSettings() async {}
  @override
  Future<InstallResult> install(String path) async {
    installs++;
    return InstallResult.success;
  }
}

final class _NoTransport implements UpdateTransport {
  @override
  Future<ReleaseInfo?> latest(String channel) async => null;
  @override
  Future<UpdateDownloadResponse> download({
    required int build,
    required int start,
    required UpdateCancellation cancellation,
  }) => throw UnimplementedError();
}

final class _NoSettings implements SettingsStorage {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String? value) async {}
}

// Download behavior is covered through the real service in
// c7_update_service_test; repository tests use this narrow override seam.
final class _PreparedService extends UpdateService {
  _PreparedService(this.prepared)
    : super(
        transport: _NoTransport(),
        settings: AppSettingsService(_NoSettings()),
        directory: prepared.parent,
        server: 'https://example.invalid',
        channel: 'stable',
        localBuild: 1,
      );
  final File prepared;
  bool deleted = false;
  int downloads = 0;
  @override
  Future<File> download(
    ReleaseInfo release, {
    required UpdateCancellation cancellation,
    required void Function(int, int) onProgress,
  }) async {
    downloads++;
    return prepared;
  }

  @override
  Future<void> deletePackage(int build) {
    deleted = true;
    return Future<void>.value();
  }
}

void main() {
  test('signature mismatch deletes package and never installs', () async {
    final directory = await Directory.systemTemp.createTemp('jiabu-c7-repo-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/fake.apk')..writeAsBytesSync([1]);
    final service = _PreparedService(file);
    final installer = _Installer(signature: false);
    final repository = UpdateRepository(service, installer);
    const release = ReleaseInfo(
      build: 2,
      version: '1.0.2',
      channel: 'stable',
      bytes: 1,
      sha256: '00',
      notes: {'en': 'Fictional'},
      securityForce: false,
      minServerApi: 1,
    );
    final result = await repository.download(
      release,
      cancellation: UpdateCancellation(),
      onProgress: (_, _) {},
    );
    expect(result, isA<Failure<PreparedUpdate>>());
    expect(service.deleted, isTrue);
    expect(installer.installs, 0);
    await repository.download(
      release,
      cancellation: UpdateCancellation(),
      onProgress: (_, _) {},
    );
    expect(service.downloads, 2);
  });

  test(
    'missing permission keeps verified package without installing',
    () async {
      final directory = await Directory.systemTemp.createTemp('jiabu-c7-auth-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/fake.apk')..writeAsBytesSync([1]);
      final installer = _Installer(permission: false);
      final result = await UpdateRepository(_PreparedService(file), installer)
          .download(
            const ReleaseInfo(
              build: 2,
              version: '1.0.2',
              channel: 'stable',
              bytes: 1,
              sha256: '00',
              notes: {'en': 'Fictional'},
              securityForce: false,
              minServerApi: 1,
            ),
            cancellation: UpdateCancellation(),
            onProgress: (_, _) {},
          );
      expect((result as Ok<PreparedUpdate>).value.canInstall, isFalse);
      expect(installer.installs, 0);
      expect(file.existsSync(), isTrue);
    },
  );
}
