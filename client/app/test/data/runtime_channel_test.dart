import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/app/runtime.dart';
import 'package:jiabu/data/db/database_manager.dart';
import 'package:jiabu/data/repositories/auth_repository.dart';
import 'package:jiabu/data/services/app_settings_service.dart';
import 'package:jiabu/data/services/device_context_service.dart';
import 'package:jiabu/data/sync/background_sync.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/domain/sync_state.dart';

import '../support/memory_stores.dart';
import '../support/sync_harness.dart';
import 'api_contract_test.dart' show CapturingAdapter;

class RuntimeAdapter extends CapturingAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    body = switch (options.path) {
      'v1/meta' => {
        'server_version': '0.1.0',
        'api_versions': [1],
        'min_client_build': {'stable': 2, 'beta': 0},
        'features': <String>[],
      },
      'v1/auth/login' => {
        'token': 'fictional-token',
        'session_kind': 'full',
        'user': {'id': 'u', 'username': 'fictional', 'locale': 'en'},
      },
      'v1/me' => {'id': 'u', 'username': 'fictional', 'locale': 'en'},
      'v1/spaces' => FakeApi().spaceResponse.toJson(),
      'v1/sync/push' => {'results': <Object?>[]},
      'v1/sync/pull' => {'spaces': <Object?>[], 'unavailable': <String>[]},
      _ => throw StateError('unexpected_test_route'),
    };
    return super.fetch(options, requestStream, cancelFuture);
  }
}

Future<DeviceContext> loadTestDevice(String channel) async => DeviceContext(
  appVersion: '0.1.0',
  build: 1,
  model: 'fictional',
  osVersion: 'test',
  channel: channel,
);

void main() {
  test('stable_entry_background_handshake_and_client_header_'
      'are_stable', () async {
    final directory = await Directory.systemTemp.createTemp('jiabu-channel-');
    final databases = DatabaseManager(directory);
    final storage = MemorySettings()..values['client_channel'] = 'beta';
    final sessions = MemorySessions();
    final adapter = RuntimeAdapter();
    Dio createDio() => Dio()..httpClientAdapter = adapter;
    final foreground = await AppRuntime.create(
      channel: 'stable', // The same argument used by main_prod -> bootstrap.
      databases: databases,
      settings: AppSettingsService(storage),
      sessions: sessions,
      loadDevice: loadTestDevice,
      createDio: createDio,
    );
    AppRuntime? background;
    try {
      await foreground.api('https://example.invalid/', null).meta();
      final worker = await AppRuntime.create(
        background: true, // The same call used by backgroundDispatcher.
        databases: databases,
        settings: AppSettingsService(storage),
        sessions: sessions,
        loadDevice: loadTestDevice,
        createDio: createDio,
      );
      background = worker;
      expect(worker.device.channel, 'stable');
      expect(worker.device.clientHeader, foreground.device.clientHeader);
      expect(
        await worker.auth.login(
          'https://example.invalid/',
          'fictional',
          'fictional-password',
        ),
        isA<Ok<AuthSession>>(),
      );
      await worker.sessionWork;
      final engine = worker.engine!;
      await engine.memberships.reconcile(FakeApi().spaceResponse);
      await engine.store.putEntity('s', 'record', sampleRecord('r'));
      await worker.records!.update('s', 'r', {'amount_minor': 120});
      await engine.store.setWriteAllowed(allowed: false);
      expect(
        await runBackgroundOutbox(
          auth: worker.auth,
          prepare: () => worker.sessionWork,
          engine: () => worker.engine,
        ),
        isFalse,
      );
      expect(worker.engine?.handshake.channel, 'stable');
      expect(worker.engine?.status, SyncStatus.clientTooOld);
      expect((await engine.store.runtime())['write_allowed'], 0);
      expect(await engine.store.outbox('s'), hasLength(1));
      expect(
        adapter.requests.where((request) => request.path == 'v1/meta'),
        hasLength(2),
      );
      expect(
        adapter.requests.every(
          (request) =>
              request.headers['X-Jiabu-Client'] ==
              foreground.device.clientHeader,
        ),
        isTrue,
      );
      expect(
        adapter.requests.any((request) => request.path == 'v1/sync/push'),
        isFalse,
      );
    } finally {
      await background?.close();
      await foreground.close();
      await directory.delete(recursive: true);
    }
  });

  for (final savedChannel in <String?>[null, 'invalid', 'beta']) {
    test('background_channel_from_settings_'
        '${savedChannel ?? 'missing'}', () async {
      final directory = await Directory.systemTemp.createTemp('jiabu-channel-');
      final storage = MemorySettings();
      if (savedChannel != null) {
        storage.values['client_channel'] = savedChannel;
      }
      final runtime = await AppRuntime.create(
        background: true,
        databases: DatabaseManager(directory),
        settings: AppSettingsService(storage),
        sessions: MemorySessions(),
        loadDevice: loadTestDevice,
      );
      try {
        final expected = savedChannel == 'beta' ? 'beta' : 'stable';
        expect(runtime.device.channel, expected);
        expect(runtime.device.clientHeader, contains('channel=$expected'));
      } finally {
        await runtime.close();
        await directory.delete(recursive: true);
      }
    });
  }
}
