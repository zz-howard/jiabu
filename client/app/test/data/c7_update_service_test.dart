import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/services/app_settings_service.dart';
import 'package:jiabu/data/services/update_service.dart';
import 'package:jiabu/data/services/update_transport.dart';
import 'package:jiabu/domain/update.dart';

final class _MemorySettings implements SettingsStorage {
  final Map<String, String> values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

final class _DownloadPlan {
  const _DownloadPlan(this.status, this.data, {this.failAfter, this.start = 0});
  final int status;
  final List<int> data;
  final int? failAfter;
  final int start;
  Stream<List<int>> stream() async* {
    final split = failAfter ?? data.length;
    if (split > 0) {
      yield data.sublist(0, split);
    }
    if (failAfter != null) {
      throw const SocketException('fictional interruption');
    }
    if (split < data.length) {
      yield data.sublist(split);
    }
  }
}

final class _Transport implements UpdateTransport {
  _Transport(this.release, this.plans);
  final ReleaseInfo? release;
  final List<_DownloadPlan> plans;
  final List<int> starts = <int>[];
  int latestCalls = 0;
  @override
  Future<ReleaseInfo?> latest(String channel) async {
    latestCalls++;
    return release;
  }

  @override
  Future<UpdateDownloadResponse> download({
    required int build,
    required int start,
    required UpdateCancellation cancellation,
  }) async {
    starts.add(start);
    final plan = plans.removeAt(0);
    return UpdateDownloadResponse(
      statusCode: plan.status,
      totalBytes: release?.bytes,
      start: plan.start,
      bytes: plan.stream(),
    );
  }
}

ReleaseInfo _release(List<int> bytes, {int build = 2}) => ReleaseInfo(
  build: build,
  version: '1.0.$build',
  channel: 'stable',
  bytes: bytes.length,
  sha256: sha256.convert(bytes).toString(),
  notes: const {'zh-Hans': '虚构', 'en': 'Fictional'},
  securityForce: false,
  minServerApi: 1,
);

void main() {
  late Directory directory;
  late _MemorySettings memory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('jiabu-c7-');
    memory = _MemorySettings();
  });
  tearDown(() => directory.delete(recursive: true));

  UpdateService service(_Transport transport, DateTime Function() now) =>
      UpdateService(
        transport: transport,
        settings: AppSettingsService(memory),
        directory: directory,
        server: 'https://example.invalid/',
        channel: 'stable',
        localBuild: 1,
        now: now,
      );

  test(
    'interruption resumes exactly at part length and verifies hash',
    () async {
      final bytes = List<int>.generate(32, (index) => index);
      final transport = _Transport(_release(bytes), [
        _DownloadPlan(200, bytes, failAfter: 11),
        _DownloadPlan(206, bytes.sublist(11), start: 11),
      ]);
      final subject = service(transport, () => DateTime.utc(2026));
      await expectLater(
        subject.download(
          _release(bytes),
          cancellation: UpdateCancellation(),
          onProgress: (_, _) {},
        ),
        throwsA(isA<SocketException>()),
      );
      final file = await subject.download(
        _release(bytes),
        cancellation: UpdateCancellation(),
        onProgress: (_, _) {},
      );
      expect(transport.starts, [0, 11]);
      expect(await file.readAsBytes(), bytes);
    },
  );

  test('200 ignoring range truncates partial file', () async {
    final bytes = List<int>.generate(20, (index) => index + 4);
    await File('${directory.path}/jiabu-2.apk.part').writeAsBytes([9, 9, 9]);
    final transport = _Transport(_release(bytes), [_DownloadPlan(200, bytes)]);
    final file = await service(transport, DateTime.now).download(
      _release(bytes),
      cancellation: UpdateCancellation(),
      onProgress: (_, _) {},
    );
    expect(transport.starts, [3]);
    expect(await file.readAsBytes(), bytes);
  });

  test('416 and overlong partial both restart from zero', () async {
    final bytes = List<int>.generate(8, (index) => index);
    final part = File('${directory.path}/jiabu-2.apk.part');
    await part.writeAsBytes([1, 2]);
    final transport = _Transport(_release(bytes), [
      const _DownloadPlan(416, []),
      _DownloadPlan(200, bytes),
    ]);
    await service(transport, DateTime.now).download(
      _release(bytes),
      cancellation: UpdateCancellation(),
      onProgress: (_, _) {},
    );
    expect(transport.starts, [2, 0]);
    File('${directory.path}/jiabu-2.apk').deleteSync();
    await part.writeAsBytes(List.filled(9, 1));
    final second = _Transport(_release(bytes), [_DownloadPlan(200, bytes)]);
    await service(second, DateTime.now).download(
      _release(bytes),
      cancellation: UpdateCancellation(),
      onProgress: (_, _) {},
    );
    expect(second.starts, [0]);
  });

  test('check timing and three day dismissal use injected clock', () async {
    var now = DateTime.utc(2026);
    final transport = _Transport(_release([1, 2]), []);
    final subject = service(transport, () => now);
    expect(await subject.check(UpdateCheckReason.opening), isNotNull);
    await subject.dismiss(_release([1, 2]));
    now = now.add(const Duration(hours: 23));
    expect(await subject.check(UpdateCheckReason.resume), isNull);
    expect(transport.latestCalls, 1);
    now = DateTime.utc(2026, 1, 2);
    expect(await subject.check(UpdateCheckReason.resume), isNull);
    expect(transport.latestCalls, 2);
    now = DateTime.utc(2026, 1, 4);
    expect(await subject.check(UpdateCheckReason.resume), isNotNull);
    expect(transport.latestCalls, 3);
    final larger = _Transport(_release([1, 2], build: 3), []);
    expect(
      await service(
        larger,
        () => DateTime.utc(2026, 1, 2),
      ).check(UpdateCheckReason.opening),
      isNotNull,
    );
  });

  test('opening always checks and forced check bypasses dismissal', () async {
    var now = DateTime.utc(2026, 2);
    final transport = _Transport(_release([1, 2]), []);
    final subject = service(transport, () => now);
    final release = await subject.check(UpdateCheckReason.opening);
    if (release == null) fail('opening check did not return the fake release');
    await subject.dismiss(release);
    now = now.add(const Duration(hours: 1));
    expect(await subject.check(UpdateCheckReason.opening), isNull);
    expect(transport.latestCalls, 2);
    expect(await subject.check(UpdateCheckReason.clientTooOld), isNotNull);
    expect(transport.latestCalls, 3);
  });

  test('checksum mismatch deletes partial package', () async {
    final bytes = [1, 2, 3];
    const bad = ReleaseInfo(
      build: 2,
      version: '1.0.2',
      channel: 'stable',
      bytes: 3,
      sha256: '00',
      notes: {'en': 'Fictional'},
      securityForce: false,
      minServerApi: 1,
    );
    final transport = _Transport(bad, [
      _DownloadPlan(200, bytes),
      _DownloadPlan(200, bytes),
    ]);
    await expectLater(
      service(transport, DateTime.now).download(
        bad,
        cancellation: UpdateCancellation(),
        onProgress: (_, _) {},
      ),
      throwsA(isA<UpdateChecksumMismatch>()),
    );
    expect(File('${directory.path}/jiabu-2.apk.part').existsSync(), isFalse);
    await expectLater(
      service(transport, DateTime.now).download(
        bad,
        cancellation: UpdateCancellation(),
        onProgress: (_, _) {},
      ),
      throwsA(isA<UpdateChecksumMismatch>()),
    );
    expect(transport.starts, [0, 0]);
  });
}
