import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/api/dio_api_client.dart';
import 'package:jiabu/data/api/dto/auth_dto.dart';
import 'package:jiabu/data/api/dto/client_logs_dto.dart';
import 'package:jiabu/data/api/dto/meta_dto.dart';
import 'package:jiabu/data/api/dto/problem_dto.dart';
import 'package:jiabu/data/api/dto/spaces_dto.dart';
import 'package:jiabu/data/api/dto/sync_dto.dart';
import 'package:jiabu/data/services/app_settings_service.dart';
import 'package:jiabu/data/services/version_handshake_service.dart';
import 'package:jiabu/data/sync/outbox_processor.dart';
import 'package:jiabu/data/sync/sync_engine.dart';
import 'package:jiabu/domain/required_value.dart';
import 'package:jiabu/domain/sync_state.dart';

import '../support/memory_stores.dart';
import '../support/sync_harness.dart';

class CapturingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Object body = const {
    'server_version': '0.1.0',
    'api_versions': [1],
    'min_client_build': {'stable': 0, 'beta': 0},
    'features': <String>[],
  };
  int status = 200;
  Map<String, List<String>> headers = const {
    Headers.contentTypeHeader: ['application/json'],
  };
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = body;
    if (response is Uint8List) {
      return ResponseBody.fromBytes(response, status, headers: headers);
    }
    return ResponseBody.fromString(jsonEncode(body), status, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> openapi() {
  var directory = Directory.current;
  while (!File('${directory.path}/server/openapi/openapi.json').existsSync()) {
    if (directory.parent.path == directory.path) {
      throw StateError('Repository OpenAPI not found');
    }
    directory = directory.parent;
  }
  final file = File('${directory.path}/server/openapi/openapi.json');
  return (jsonDecode(file.readAsStringSync()) as Map<String, Object?>)
      .cast<String, Object?>();
}

// Capture the old interceptor's escaped async error so regressions fail with
// an assertion / timeout rather than leaving a test runner or heartbeat alive.
Future<T> guardedRequest<T>(
  Future<T> Function() work,
  List<Object> uncaught,
  List<Timer> timers,
) {
  final result = Completer<T>();
  unawaited(
    runZonedGuarded(
      () async {
        try {
          result.complete(await work());
        } on Object catch (error, stack) {
          result.completeError(error, stack);
        }
      },
      (error, stack) => uncaught.add(error),
      zoneSpecification: ZoneSpecification(
        createPeriodicTimer: (self, parent, zone, duration, callback) {
          final timer = parent.createPeriodicTimer(zone, duration, callback);
          timers.add(timer);
          return timer;
        },
      ),
    ),
  );
  return result.future.timeout(const Duration(seconds: 2));
}

void main() {
  test('token_read_failure_rejects_request_without_sensitive_error', () async {
    final adapter = CapturingAdapter();
    final api = DioApiClient(
      server: 'https://example.invalid/',
      clientHeader: 'android/0.1.0+1; channel=stable',
      token: () async => throw StateError('fictional-sensitive-storage-detail'),
      dio: Dio()..httpClientAdapter = adapter,
    );
    final uncaught = <Object>[];
    final timers = <Timer>[];
    try {
      await expectLater(
        guardedRequest(
          () => api.dio.get<Object?>('v1/spaces'),
          uncaught,
          timers,
        ),
        throwsA(
          isA<DioException>()
              .having((error) => error.type, 'type', DioExceptionType.unknown)
              .having(
                (error) => error.error,
                'normalized error',
                isA<ApiError>().having(
                  (error) => error.code,
                  'code',
                  'token_unavailable',
                ),
              )
              .having(
                (error) => error.toString(),
                'safe message',
                isNot(contains('fictional-sensitive-storage-detail')),
              ),
        ),
      );
      expect(uncaught, isEmpty);
      expect(adapter.requests, isEmpty);
    } finally {
      for (final timer in timers) {
        timer.cancel();
      }
      api.dio.close(force: true);
    }
  });

  test('token_read_failure_finishes_round_releases_lease_'
      'and_can_retry', () async {
    final h = await SyncHarness.create();
    final adapter = CapturingAdapter();
    var tokenReads = 0;
    final api = DioApiClient(
      server: 'https://example.invalid/',
      clientHeader: 'android/0.1.0+1; channel=stable',
      token: () async {
        tokenReads++;
        throw StateError('fictional-sensitive-storage-detail');
      },
      dio: Dio()..httpClientAdapter = adapter,
    );
    final engine = SyncEngine(
      store: h.store,
      api: api,
      handshake: VersionHandshakeService(api, channel: 'stable'),
      memberships: h.memberships,
      outbox: OutboxProcessor(h.store, api, h.conflicts),
      pull: h.pull,
    );
    final uncaught = <Object>[];
    final timers = <Timer>[];
    try {
      for (var round = 0; round < 2; round++) {
        await guardedRequest(engine.runRound, uncaught, timers);
        expect(tokenReads, round + 1);
        expect(engine.status, SyncStatus.retryLater);
        final runtime = await h.store.runtime();
        expect(runtime['round_owner'], isNull);
        expect(runtime['round_lease_until'], isNull);
        expect(timers.every((timer) => !timer.isActive), isTrue);
      }
      expect(uncaught, isEmpty);
      expect(adapter.requests.map((request) => request.path), ['v1/meta']);
    } finally {
      for (final timer in timers) {
        timer.cancel();
      }
      api.dio.close(force: true);
      await h.close();
    }
  });

  test('download_accepts_cleaned_bytes_under_uploaded_content_hash', () async {
    final bytes = Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]);
    final adapter = CapturingAdapter()
      ..body = bytes
      ..headers = {
        Headers.contentTypeHeader: ['image/jpeg'],
      };
    final dio = Dio()..httpClientAdapter = adapter;
    final api = DioApiClient(
      server: 'https://example.invalid/',
      clientHeader: 'android/0.1.0+1; channel=beta',
      token: () async => 'fictional-token',
      dio: dio,
    );
    // A deliberately unrelated upload digest must not reject cleaned bytes.
    final uploadHash = List.filled(64, '0').join();
    expect(await api.downloadBlob('s', uploadHash, 'original'), bytes);
    expect(adapter.requests.single.uri.path, '/v1/spaces/s/blobs/$uploadHash');
  });

  test('DTOs roundtrip actual OpenAPI examples without '
      'API codegen', () {
    final paths = requireValue<Map<String, Object?>>(openapi()['paths']);
    Map<String, Object?> objectAt(Map<String, Object?> parent, String key) =>
        requireValue<Map<String, Object?>>(parent[key]);
    Map<String, Object?> example(Map<String, Object?> body) => objectAt(
      objectAt(objectAt(body, 'content'), 'application/json'),
      'example',
    );
    Map<String, Object?> request(String path) => example(
      objectAt(objectAt(objectAt(paths, path), 'post'), 'requestBody'),
    );
    Map<String, Object?> response(String path, String method, String status) =>
        example(
          objectAt(
            objectAt(objectAt(objectAt(paths, path), method), 'responses'),
            status,
          ),
        );
    final login = request('/v1/auth/login');
    expect(LoginRequestDto.fromJson(login).toJson(), login);
    final logged = response('/v1/auth/login', 'post', '200');
    expect(LoginResponseDto.fromJson(logged).toJson(), logged);
    final me = response('/v1/me', 'get', '200');
    expect(UserDto.fromJson(me).toJson(), me);
    final password = request('/v1/me/password');
    expect(ChangePasswordDto.fromJson(password).toJson(), password);
    final meta = response('/v1/meta', 'get', '200');
    expect(MetaDto.fromJson(meta).toJson(), meta);
    final spaces = response('/v1/spaces', 'get', '200');
    expect(SpacesDto.fromJson(spaces).toJson(), spaces);
    final push = request('/v1/sync/push');
    expect(PushRequestDto.fromJson(push).toJson(), push);
    final pushed = response('/v1/sync/push', 'post', '200');
    expect(PushResponseDto.fromJson(pushed).toJson(), pushed);
    final pull = request('/v1/sync/pull');
    expect(PullRequestDto.fromJson(pull).toJson(), pull);
    final pulled = response('/v1/sync/pull', 'post', '200');
    expect(PullResponseDto.fromJson(pulled).toJson(), pulled);
    final logs = request('/v1/client-logs');
    expect(ClientLogsDto.fromJson(logs).toJson(), logs);
    final problem = response(
      '/v1/spaces/{space_id}/blobs/{sha256}',
      'get',
      '404',
    );
    expect(ProblemDto.fromJson(problem).toJson(), problem);
  });

  test('relative_routes_preserve_reverse_proxy_prefix_an'
      'd_request_headers', () async {
    final dio = Dio();
    final adapter = CapturingAdapter();
    dio.httpClientAdapter = adapter;
    final api = DioApiClient(
      server: 'https://example.invalid/proxy/',
      clientHeader: 'android/0.1.0+1; channel=beta',
      token: () async => 'fictional-token',
      dio: dio,
    );
    await api.meta();
    expect(adapter.requests.single.uri.path, '/proxy/v1/meta');
    expect(
      adapter.requests.single.headers.containsKey('Authorization'),
      isFalse,
    );
    adapter.body = {'results': <Object?>[]};
    await api.push([]);
    final request = adapter.requests.last;
    expect(request.path.startsWith('/'), isFalse);
    expect(request.uri.path, '/proxy/v1/sync/push');
    expect(request.headers['Authorization'], 'Bearer fictional-token');
    expect(request.headers['X-Jiabu-Client'], 'android/0.1.0+1; channel=beta');
    expect(request.headers['X-Request-Id'], isNotEmpty);
    expect(request.headers['Idempotency-Key'], isNotEmpty);
  });

  test('problem_json_maps_code_request_id_status_and_ret'
      'ry_header', () async {
    final adapter = CapturingAdapter()
      ..status = 503
      ..body = {'code': 'upload_busy', 'status': 503, 'request_id': 'request'}
      ..headers = {
        'content-type': ['application/problem+json'],
        'retry-after': ['3'],
      };
    final dio = Dio()..httpClientAdapter = adapter;
    final api = DioApiClient(
      server: 'https://example.invalid/',
      clientHeader: 'android/0.1.0+1; channel=beta',
      token: () async => null,
      dio: dio,
    );
    await expectLater(
      api.me(),
      throwsA(
        isA<ApiError>()
            .having((e) => e.code, 'code', 'upload_busy')
            .having((e) => e.status, 'status', 503)
            .having((e) => e.retryAfter, 'retry', 3)
            .having((e) => e.requestId, 'requestId', 'request'),
      ),
    );
  });

  test('meta_cache_one_hour_and_426_forces_refresh', () async {
    final api = FakeApi();
    var clock = DateTime.utc(2026);
    final handshake = VersionHandshakeService(api, now: () => clock);
    expect(await handshake.check(), SyncStatus.idle);
    clock = clock.add(const Duration(minutes: 59));
    await handshake.check();
    expect(api.metaCalls, 1);
    clock = clock.add(const Duration(minutes: 1));
    await handshake.check();
    expect(api.metaCalls, 2);
    api.metaResponse = api.metaResponse.copyWith(
      minClientBuild: const {'beta': 2},
    );
    expect(await handshake.on426(), SyncStatus.clientTooOld);
    expect(api.metaCalls, 3);
  });

  test('old_app_or_server_stops_before_spaces_and_upload', () async {
    final h = await SyncHarness.create();
    addTearDown(h.close);
    h.api.metaResponse = h.api.metaResponse.copyWith(serverVersion: '0.0.9');
    await h.seed('r');
    await h.records.update('s', 'r', {'amount_minor': 120});
    await h.engine.runRound();
    expect(h.engine.status, SyncStatus.serverTooOld);
    expect(h.api.events, isEmpty);
    expect(await h.store.outbox('s'), hasLength(1));
    h.api.metaResponse = h.api.metaResponse.copyWith(
      serverVersion: '0.1.0',
      minClientBuild: const {'beta': 10},
    );
    h.engine.handshake.invalidate();
    await h.engine.runRound();
    expect(h.engine.status, SyncStatus.clientTooOld);
    expect(h.api.batches, isEmpty);
  });

  test('426_interceptor_and_engine_do_not_refresh_meta_twice', () async {
    final h = await SyncHarness.create();
    addTearDown(h.close);
    await h.seed('r');
    await h.records.update('s', 'r', {'amount_minor': 120});
    h.api.onPush = (_) async {
      h.api.metaResponse = h.api.metaResponse.copyWith(
        minClientBuild: const {'beta': 10},
      );
      await h.engine.handshake.on426(); // Simulate Dio's 426 interceptor.
      throw const ApiError('client_too_old', status: 426);
    };
    await h.engine.runRound();
    expect(h.api.metaCalls, 2);
    expect(h.engine.status, SyncStatus.clientTooOld);
    expect((await h.store.outbox('s')).single.state, 'pending');
  });

  test('shared_meta_invalidation_overrides_isolate_memory_cache', () async {
    final settings = AppSettingsService(MemorySettings());
    final api = FakeApi();
    const server = 'https://example.invalid/';
    final handshake = VersionHandshakeService(
      api,
      readCache: () => settings.meta(server),
      writeCache: (cache) => settings.saveMeta(server, cache),
    );
    expect(await handshake.check(), SyncStatus.idle);
    await settings.clearMeta(server); // Another isolate received 426.
    api.metaResponse = api.metaResponse.copyWith(
      minClientBuild: const {'beta': 10},
    );
    expect(await handshake.check(), SyncStatus.clientTooOld);
    expect(api.metaCalls, 2);
  });
}
