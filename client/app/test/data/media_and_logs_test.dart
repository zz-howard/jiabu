import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:jiabu/data/services/crash_reporter_service.dart';
import 'package:jiabu/data/services/device_context_service.dart';
import 'package:jiabu/data/services/file_log_sink_service.dart';
import 'package:jiabu/data/services/jpeg_sanitizer_service.dart';
import 'package:jiabu/data/services/log_redactor_service.dart';
import 'package:jiabu/data/services/media_service.dart';
import 'package:jiabu/domain/required_value.dart';
import 'package:jiabu/domain/result.dart';
import 'package:logging/logging.dart';

import '../fixtures/jpeg_fixture.dart';
import '../support/sync_harness.dart';

class FakePicker implements ImagePickerPort {
  List<Uint8List> images = [];
  @override
  Future<List<Uint8List>> pick({required bool camera}) async => images;
}

class FakeCompressor implements ImageCompressorPort {
  final calls = <(int, int, int, bool)>[];
  Future<Uint8List> Function(Uint8List)? beforeReturn;
  @override
  Future<Uint8List> jpeg(
    Uint8List bytes, {
    required int quality,
    required int minWidth,
    required int minHeight,
    required bool correctOrientation,
  }) async {
    calls.add((quality, minWidth, minHeight, correctOrientation));
    return beforeReturn == null ? bytes : await beforeReturn!(bytes);
  }
}

Future<LogRecord> safeRecord(Level level, SafeLogEvent event) async {
  final logger = Logger.detached('fixture');
  final record = logger.onRecord.first;
  logger.log(level, event);
  return await record;
}

void main() {
  test('reimported_blob_preserves_waiting_record_edit_order', () async {
    final h = await SyncHarness.create();
    addTearDown(h.close);
    final input = testJpeg(gps: true);
    final hash = sha256
        .convert(JpegSanitizerService().sanitize(input))
        .toString();
    await h.records.create('s', {
      ...sampleRecord('r'),
      'attachments': [hash],
    });
    await h.records.update('s', 'r', {'note': 'fictional later edit'});
    await h.engine.runRound();
    expect(h.api.batches, isEmpty);
    final service = MediaService(
      store: h.store,
      directory: h.directory,
      picker: FakePicker(),
      compressor: FakeCompressor(),
    );
    expect(await service.importImage('s', 'ledger', input), isA<Ok<String>>());
    await h.engine.runRound();
    expect(h.api.events.where((event) => event != 'spaces'), [
      'blob',
      'create_record',
      'update_record',
    ]);
    expect(h.api.server['r']?['note'], 'fictional later edit');
    expect(await h.store.outbox('s'), isEmpty);
  });

  test('dio_exception_url_headers_and_string_are_redacted', () async {
    final directory = await Directory.systemTemp.createTemp('jiabu-dio-log-');
    addTearDown(() => directory.delete(recursive: true));
    final sink = FileLogSink(directory)..attach();
    addTearDown(sink.close);
    final exception = DioException(
      requestOptions: RequestOptions(
        path: 'https://example.invalid/private?password=fictional-password',
        headers: const {'Authorization': 'Bearer fictional-bearer-secret'},
      ),
      message:
          'https://example.invalid/private?password=fictional-password '
          'Authorization: Bearer fictional-bearer-secret '
          'token=jiabu_pat_fictional',
      error: StateError('fictional original note'),
    );
    Logger('transport').severe(exception.toString(), exception);
    Logger('transport').severe(const SafeLogEvent('sync_failed'), exception);
    final persisted = await sink.pending();
    expect(persisted, hasLength(2));
    final disk = await File('${directory.path}/client.0.jsonl').readAsString();
    final api = FakeApi();
    await CrashReporterService(sink).uploadPrevious(
      api,
      const DeviceContext(
        appVersion: '0.1.0',
        build: 1,
        model: 'fictional',
        osVersion: 'test',
      ),
      stillActive: () async => true,
    );
    for (final output in [disk, jsonEncode(api.logs.single.toJson())]) {
      for (final secret in [
        'example.invalid',
        'Authorization',
        'fictional-password',
        'fictional-bearer-secret',
        'jiabu_pat_',
        'fictional original note',
      ]) {
        expect(output, isNot(contains(secret)));
      }
    }
  });

  test('media_removes_gps_exif_xmp_and_tail_before_hash_'
      'and_enqueue', () async {
    final h = await SyncHarness.create();
    addTearDown(h.close);
    final compressor = FakeCompressor();
    final service = MediaService(
      store: h.store,
      directory: h.directory,
      picker: FakePicker(),
      compressor: compressor,
    );
    final input = testJpeg(gps: true);
    expect(containsGpsIfd(input), isTrue);
    final result = await service.importImage('s', 'ledger', input);
    expect(result, isA<Ok<String>>());
    final hash = (result as Ok<String>).value;
    final blob = (await h.store.blobs('s')).single;
    final file = File(requireValue<String>(blob['path']));
    final clean = await file.readAsBytes();
    expect(containsGpsIfd(clean), isFalse);
    expect(latin1.decode(clean), isNot(contains('Exif')));
    expect(latin1.decode(clean), isNot(contains('fictional-xmp')));
    expect(latin1.decode(clean), isNot(contains('fictional-tail')));
    expect(image.decodeJpg(clean), isNotNull);
    expect(sha256.convert(clean).toString(), hash);
    expect(compressor.calls.first.$4, isTrue);
    expect(compressor.calls.last.$1, 90);
    expect((await h.store.outbox('s')).single.entityIds, {'blob:ledger:$hash'});
  });

  test('media_uses_oriented_dimensions_and_bounds_long_side', () async {
    final h = await SyncHarness.create();
    addTearDown(h.close);
    final compressor = FakeCompressor();
    compressor.beforeReturn = (bytes) async => compressor.calls.length == 1
        ? testJpeg(width: 8192, height: 8)
        : testJpeg(width: 4096, height: 4);
    final service = MediaService(
      store: h.store,
      directory: h.directory,
      picker: FakePicker(),
      compressor: compressor,
    );
    expect(
      await service.importImage('s', 'ledger', testJpeg(gps: true)),
      isA<Ok<String>>(),
    );
    expect(compressor.calls.last, (90, 4096, 4, false));
  });

  test('late_media_completion_is_discarded_after_partiti'
      'on_generation_change', () async {
    final h = await SyncHarness.create();
    addTearDown(h.close);
    final entered = Completer<void>();
    final gate = Completer<Uint8List>();
    final compressor = FakeCompressor()
      ..beforeReturn = (_) {
        if (!entered.isCompleted) {
          entered.complete();
        }
        return gate.future;
      };
    final service = MediaService(
      store: h.store,
      directory: h.directory,
      picker: FakePicker(),
      compressor: compressor,
    );
    final pending = service.importImage('s', 'ledger', testJpeg());
    await entered.future;
    await h.store.activate(authenticated: false);
    gate.complete(testJpeg());
    expect(await pending, isA<Failure<String>>());
    expect(await h.store.blobs('s'), isEmpty);
    expect(await h.store.outbox('s'), isEmpty);
  });

  test('malformed_jpeg_is_rejected_without_database_side_effects', () async {
    final h = await SyncHarness.create();
    addTearDown(h.close);
    final service = MediaService(
      store: h.store,
      directory: h.directory,
      picker: FakePicker(),
      compressor: FakeCompressor(),
    );
    expect(
      await service.importImage(
        's',
        'ledger',
        Uint8List.fromList([0xff, 0xd8, 0xff]),
      ),
      isA<Failure<String>>(),
    );
    expect(await h.store.blobs('s'), isEmpty);
    expect(await h.store.outbox('s'), isEmpty);
    expect(
      () => JpegSanitizerService().sanitize(
        Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
      ),
      throwsFormatException,
    );
  });

  test('logs_never_contain_tokens_passwords_pat_or_origi'
      'nal_notes', () async {
    final directory = await Directory.systemTemp.createTemp('jiabu-logs-');
    addTearDown(() => directory.delete(recursive: true));
    final sink = FileLogSink(directory);
    final secrets = [
      'fictional-bearer-secret',
      'fictional-password',
      'jiabu_pat_fictional',
      'fictional original note',
    ];
    final record = LogRecord(
      Level.SEVERE,
      jsonEncode({
        'Authorization': secrets[0],
        'nested': {
          'password': secrets[1],
          'pat': secrets[2],
          'note': secrets[3],
        },
      }),
      'unsafe',
      StateError(secrets.join(' ')),
      StackTrace.fromString(
        '${secrets.join(' ')}\n#0 '
        'package:jiabu/app/runtime.dart:1:1',
      ),
    );
    final entry = LogRedactorService().redact(record);
    await sink.append(entry);
    final serialized = jsonEncode(
      (await sink.pending()).map((entry) => entry.toJson()).toList(),
    );
    final onDisk = await File('${directory.path}/client.0.jsonl')
        .readAsString();
    for (final secret in secrets) {
      expect(serialized, isNot(contains(secret)));
      expect(onDisk, isNot(contains(secret)));
    }
    final api = FakeApi();
    await CrashReporterService(sink).uploadPrevious(
      api,
      const DeviceContext(
        appVersion: '0.1.0',
        build: 1,
        model: 'fictional',
        osVersion: 'test',
      ),
      stillActive: () async => true,
    );
    for (final secret in secrets) {
      expect(jsonEncode(api.logs.single.toJson()), isNot(contains(secret)));
    }
    expect(await sink.pending(), isEmpty);
    await sink.close();
  });

  test('file_log_sink_rotates_five_bounded_files_and_kee'
      'ps_new_records', () async {
    final directory = await Directory.systemTemp.createTemp('jiabu-logs-');
    addTearDown(() => directory.delete(recursive: true));
    final sink = FileLogSink(directory, maxBytes: 400);
    for (var i = 0; i < 20; i++) {
      await sink.append(
        LogRedactorService().redact(
          await safeRecord(Level.INFO, const SafeLogEvent('startup')),
        ),
      );
    }
    final files = await directory
        .list()
        .where((entry) => entry.path.endsWith('.jsonl'))
        .toList();
    expect(files, hasLength(5));
    for (final file in files.cast<File>()) {
      expect(await file.length(), lessThanOrEqualTo(400));
    }
    final snapshot = await sink.pending();
    await sink.append(
      LogRedactorService().redact(
        await safeRecord(Level.SEVERE, const SafeLogEvent('uncaught_error')),
      ),
    );
    await sink.acknowledge(snapshot);
    expect((await sink.pending()).single.message, 'uncaught_error');
    await sink.close();
  });

  test('flutter_and_platform_crash_hooks_write_only_reda'
      'cted_events', () async {
    final directory = await Directory.systemTemp.createTemp('jiabu-crashes-');
    final sink = FileLogSink(directory)..attach();
    final flutterHandler = FlutterError.onError;
    final platformHandler = PlatformDispatcher.instance.onError;
    try {
      CrashReporterService(sink).install();
      FlutterError.onError?.call(
        FlutterErrorDetails(exception: StateError('fictional secret note')),
      );
      expect(
        PlatformDispatcher.instance.onError?.call(
          StateError('jiabu_pat_fictional'),
          StackTrace.current,
        ),
        isTrue,
      );
      final entries = await sink.pending();
      expect(
        entries.map((entry) => entry.message),
        containsAll(['flutter_error', 'uncaught_error']),
      );
      final json = jsonEncode(entries.map((entry) => entry.toJson()).toList());
      expect(json, isNot(contains('fictional secret note')));
      expect(json, isNot(contains('jiabu_pat_')));
    } finally {
      FlutterError.onError = flutterHandler;
      PlatformDispatcher.instance.onError = platformHandler;
      await sink.close();
      await directory.delete(recursive: true);
    }
  });
}
