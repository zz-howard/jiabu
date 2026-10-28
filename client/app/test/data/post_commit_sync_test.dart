import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/app/runtime.dart';
import 'package:jiabu/data/api/dto/problem_dto.dart';
import 'package:jiabu/data/api/dto/sync_dto.dart';
import 'package:jiabu/data/db/daos/local_store.dart';
import 'package:jiabu/data/db/database_manager.dart';
import 'package:jiabu/data/repositories/auth_repository.dart';
import 'package:jiabu/data/services/app_settings_service.dart';
import 'package:jiabu/data/sync/sync_triggers.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/domain/sync_state.dart';

import '../support/memory_stores.dart';
import '../support/sync_harness.dart';
import 'api_contract_test.dart' show CapturingAdapter;
import 'runtime_channel_test.dart' show loadTestDevice;

// Preserve Timer's Zone semantics even though the test controls the clock.
class ZoneTimer implements Timer {
  ZoneTimer(this.duration, void Function() action)
    : zone = Zone.current,
      action = Zone.current.bindCallbackGuarded(action);
  final Duration duration;
  final Zone zone;
  final void Function() action;
  bool _active = true;

  void fire() {
    if (_active) {
      _active = false;
      action();
    }
  }

  @override
  bool get isActive => _active;
  @override
  int get tick => _active ? 0 : 1;
  @override
  void cancel() => _active = false;
}

class SyncRuntimeAdapter extends CapturingAdapter {
  final api = FakeApi();
  final pushZones = <Zone>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    body = switch (options.path) {
      'v1/meta' => (await api.meta()).toJson(),
      'v1/auth/login' => {
        'token': 'fictional-token',
        'session_kind': 'full',
        'user': {'id': 'u', 'username': 'fictional', 'locale': 'en'},
      },
      'v1/me' => {'id': 'u', 'username': 'fictional', 'locale': 'en'},
      'v1/spaces' => (await api.spaces()).toJson(),
      'v1/sync/push' => await push(options),
      'v1/sync/pull' => (await api.pull(
        PullRequestDto.fromJson(options.data! as Map<String, Object?>),
      )).toJson(),
      _ => throw StateError('unexpected_test_route'),
    };
    return await super.fetch(options, requestStream, cancelFuture);
  }

  Future<Map<String, Object?>> push(RequestOptions options) async {
    pushZones.add(Zone.current);
    return (await api.push(
      PushRequestDto.fromJson(options.data! as Map<String, Object?>).ops,
    )).toJson();
  }
}

class TriggerFixture {
  TriggerFixture(this.runtime, this.directory, this.adapter);
  final AppRuntime runtime;
  final Directory directory;
  final SyncRuntimeAdapter adapter;
  final timers = <ZoneTimer>[];
  final scheduleZones = <Zone>[];
  late final SyncTriggers triggers;
  LocalStore get store => runtime.engine!.store;

  static Future<TriggerFixture> create() async {
    final directory = await Directory.systemTemp.createTemp('jiabu-trigger-');
    final adapter = SyncRuntimeAdapter();
    final runtime = AppRuntime(
      databases: DatabaseManager(directory),
      settings: AppSettingsService(MemorySettings()),
      sessions: MemorySessions(),
      device: await loadTestDevice('stable'),
      // Supply controlled platform triggers below, retaining runtime wiring.
      background: true,
      createDio: () => Dio()..httpClientAdapter = adapter,
    );
    final f = TriggerFixture(runtime, directory, adapter);
    addTearDown(f.close);
    expect(
      await runtime.auth.login(
        'https://example.invalid/',
        'fictional',
        'fictional-password',
      ),
      isA<Ok<AuthSession>>(),
    );
    await runtime.sessionWork;
    final engine = runtime.engine!;
    await engine.memberships.reconcile(adapter.api.spaceResponse);
    f.triggers = SyncTriggers(
      engine,
      engine.api,
      f.store,
      observeLifecycle: false,
      connectivity: const Stream<List<ConnectivityResult>>.empty(),
      scheduleTask: () async => f.scheduleZones.add(Zone.current),
      timer: (duration, action) {
        final timer = ZoneTimer(duration, action);
        f.timers.add(timer);
        return timer;
      },
    );
    return f;
  }

  Future<void> waitForRoundEnd() async {
    // Wait for the round's final database work before closing its connection.
    // The caller first awaits an upload or a pull, so the round has started.
    while ((await store.runtime())['round_owner'] != null) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> uploadFromTimer() async {
    expect(timers.where((timer) => timer.isActive), hasLength(1));
    expect(timers.last.duration, const Duration(seconds: 1));
    timers.last.fire();
    await store.watchOutboxCount('s').firstWhere((count) => count == 0);
    await waitForRoundEnd();
    expect(runtime.engine!.status, SyncStatus.idle);
  }

  Future<void> close() async {
    await triggers.dispose();
    await waitForRoundEnd();
    await runtime.close();
    await directory.delete(recursive: true);
  }
}

void main() {
  for (final write in ['create', 'update']) {
    test('records_${write}_debounce_leaves_outer_transaction_zone', () async {
      final f = await TriggerFixture.create();
      final callerZone = Zone.current;
      Zone? transactionZone;
      await f.store.putEntity('s', 'record', sampleRecord('r'));
      f.adapter.api.server['r'] = sampleRecord('r');
      f.runtime.triggers = f.triggers;
      await f.store.transaction(() async {
        transactionZone = Zone.current;
        final result = write == 'create'
            ? await f.runtime.records!.create('s', sampleRecord('new'))
            : await f.runtime.records!.update('s', 'r', {'amount_minor': 125});
        expect(result, isA<Ok<String>>());
        // The nested repository transaction must not dispatch yet.
        expect(f.timers, isEmpty);
        expect(f.scheduleZones, isEmpty);
      });
      expect(f.timers, hasLength(1));
      expect(f.timers.single.zone, same(callerZone));
      expect(f.timers.single.zone, isNot(same(transactionZone)));
      expect(f.scheduleZones, [callerZone]);
      // Delay the first outbox subscription until after the write. Its first
      // result is already 1, so it cannot replace and accidentally fix a timer.
      await f.triggers.start();
      await f.uploadFromTimer();
      expect(f.adapter.api.batches.single.single.tool, '${write}_record');
      expect(f.adapter.pushZones.single, same(callerZone));
      expect(
        f.adapter.api.server[write == 'create' ? 'new' : 'r']?['amount_minor'],
        write == 'create' ? 100 : 125,
      );
    });
  }

  test('rolled_back_record_write_does_not_schedule_sync', () async {
    final f = await TriggerFixture.create();
    f.runtime.triggers = f.triggers;
    await expectLater(
      f.store.transaction(() async {
        expect(
          await f.runtime.records!.create('s', sampleRecord('r')),
          isA<Ok<String>>(),
        );
        throw StateError('rollback');
      }),
      throwsStateError,
    );
    expect(await f.store.outbox('s'), isEmpty);
    expect(f.timers, isEmpty);
    expect(f.scheduleZones, isEmpty);
  });

  test('nested_writes_notify_once_and_discard_rolled_back_savepoint', () async {
    final f = await TriggerFixture.create();
    f.runtime.triggers = f.triggers;
    await f.store.transaction(() async {
      expect(
        await f.runtime.records!.create('s', sampleRecord('kept')),
        isA<Ok<String>>(),
      );
      await expectLater(
        f.store.transaction(() async {
          await f.runtime.records!.create('s', sampleRecord('discarded'));
          throw StateError('rollback_savepoint');
        }),
        throwsStateError,
      );
      expect(
        await f.runtime.records!.update('s', 'kept', {'amount_minor': 125}),
        isA<Ok<String>>(),
      );
      expect(f.timers, isEmpty);
    });
    expect(f.timers, hasLength(1));
    expect(f.scheduleZones, hasLength(1));
    expect(await f.store.entity('s', 'record', 'discarded'), isNull);
    expect(await f.store.outbox('s'), hasLength(2));
    await f.uploadFromTimer();
    expect(f.adapter.api.server['kept']?['amount_minor'], 125);
    expect(f.adapter.api.server.containsKey('discarded'), isFalse);
  });

  for (final resolution in ['server', 'mine_noop']) {
    test(
      '${resolution}_resolution_automatically_uploads_unblocked_refund',
      () async {
        final f = await TriggerFixture.create();
        final current = sampleRecord('r', version: 2);
        await f.store.putEntity('s', 'record', sampleRecord('r'));
        f.adapter.api.server['r'] = current;
        // Only the version differs: "mine" must rebuild zero operations.
        await f.runtime.records!.update('s', 'r', {'amount_minor': 100});
        await f.runtime.records!.create('s', {
          ...sampleRecord('refund', amount: 20),
          'kind': 'refund',
          'refund_of_id': 'r',
        });
        f.adapter.api.onPush = (ops) async => PushResponseDto(
          results: [
            for (final op in ops)
              PushResultDto(
                opId: op.opId,
                status: 'conflict',
                problem: ProblemDto(
                  code: 'version_conflict',
                  status: 409,
                  current: current,
                ),
              ),
          ],
        );
        // Finish all earlier work before resolving. No timer or external event
        // remains available to rescue the blocked refund.
        await f.triggers.foreground();
        f.adapter.api.onPush = null;
        expect(f.adapter.api.batches, hasLength(1));
        final blocked = (await f.store.outbox('s')).single;
        expect(blocked.entityIds, {'record:refund'});
        expect(blocked.state, 'blocked');
        expect((await f.store.runtime())['round_owner'], isNull);
        await f.triggers.start();
        f.runtime.triggers = f.triggers;
        final scheduledBefore = f.scheduleZones.length;
        final callerZone = Zone.current;
        await expectLater(
          f.store.transaction(() async {
            expect(
              await f.runtime.conflicts!.resolveWithServer('s', 'record', 'r'),
              isA<Ok<void>>(),
            );
            throw StateError('rollback_resolution');
          }),
          throwsStateError,
        );
        expect(await f.store.conflict('s', 'record', 'r'), isNotNull);
        expect((await f.store.outbox('s')).single.state, 'blocked');
        expect(f.timers, isEmpty);
        expect(f.scheduleZones, hasLength(scheduledBefore));
        await f.store.transaction(() async {
          expect(
            resolution == 'server'
                ? await f.runtime.conflicts!.resolveWithServer(
                    's',
                    'record',
                    'r',
                  )
                : await f.runtime.conflicts!.resolveWithMine(
                    's',
                    'record',
                    'r',
                  ),
            isA<Ok<void>>(),
          );
          expect(f.timers, isEmpty);
          expect(f.scheduleZones, hasLength(scheduledBefore));
        });
        final pending = (await f.store.outbox('s')).single;
        expect(pending.id, blocked.id);
        expect(pending.state, 'pending');
        expect(f.scheduleZones, hasLength(scheduledBefore + 1));
        expect(f.scheduleZones.last, same(callerZone));
        expect(f.timers.single.zone, same(callerZone));
        // No runRound / foreground / network change after resolving.
        await f.uploadFromTimer();
        expect(f.adapter.api.batches.map((batch) => batch.single.args['id']), [
          'r',
          'refund',
        ]);
        expect(f.adapter.api.server['refund']?['amount_minor'], 20);
        expect(
          (await f.store.entity('s', 'record', 'refund'))?.syncState,
          'synced',
        );
      },
    );
  }
}
