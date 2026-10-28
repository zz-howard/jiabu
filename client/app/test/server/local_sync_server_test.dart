@Tags(<String>['server'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/api/dio_api_client.dart';
import 'package:jiabu/data/api/dto/auth_dto.dart';
import 'package:jiabu/data/api/dto/meta_dto.dart';
import 'package:jiabu/data/api/dto/spaces_dto.dart';
import 'package:jiabu/data/api/dto/sync_dto.dart';
import 'package:jiabu/data/db/database_manager.dart';
import 'package:jiabu/data/repositories/auth_repository.dart';
import 'package:jiabu/data/repositories/ledger_repository.dart';
import 'package:jiabu/data/repositories/local_mutations_repository.dart';
import 'package:jiabu/data/repositories/records_repository.dart';
import 'package:jiabu/data/services/app_settings_service.dart';
import 'package:jiabu/data/services/blob_cache_service.dart';
import 'package:jiabu/data/services/media_service.dart';
import 'package:jiabu/data/services/version_handshake_service.dart';
import 'package:jiabu/data/sync/conflict_service.dart';
import 'package:jiabu/data/sync/membership_reconciler.dart';
import 'package:jiabu/data/sync/outbox_processor.dart';
import 'package:jiabu/data/sync/pull_applier.dart';
import 'package:jiabu/data/sync/sync_engine.dart';
import 'package:jiabu/domain/ledger_balance.dart';
import 'package:jiabu/domain/required_value.dart';
import 'package:jiabu/domain/result.dart';
import 'package:uuid/uuid.dart';

import '../fixtures/jpeg_fixture.dart';
import '../support/ledger_fixture.dart';
import '../support/memory_stores.dart';
import '../support/sync_harness.dart';

String env(String key) =>
    Platform.environment[key] ??
    (throw StateError('Run tool/server-it.sh; missing $key'));
String uuid() => const Uuid().v7();

class JpegCodecStub implements ImageCompressorPort {
  @override
  Future<Uint8List> jpeg(
    Uint8List bytes, {
    required int quality,
    required int minWidth,
    required int minHeight,
    required bool correctOrientation,
  }) async => bytes;
}

class UnusedPickerStub implements ImagePickerPort {
  @override
  Future<List<Uint8List>> pick({required bool camera}) async => [];
}

class RecordedRealApi extends FakeApi {
  RecordedRealApi(this.real);
  final DioApiClient real;
  @override
  Future<MetaDto> meta() => real.meta();
  @override
  Future<SpacesDto> spaces() => real.spaces();
  @override
  Future<PushResponseDto> push(List<PushOpDto> ops) async {
    batches.add(ops);
    events.addAll(ops.map((op) => '${op.tool}:${op.args['id']}'));
    return await real.push(ops);
  }

  @override
  Future<PullResponseDto> pull(PullRequestDto request) async {
    pulls.add(request);
    return await real.pull(request);
  }

  @override
  Future<void> uploadBlob({
    required String spaceId,
    required int joinEpoch,
    required String module,
    required String hash,
    required Uint8List bytes,
    required String opId,
    required String requestId,
  }) async {
    expect(
      containsGpsIfd(bytes),
      isFalse,
      reason: 'Client must clean GPS before the real server receives it',
    );
    await real.uploadBlob(
      spaceId: spaceId,
      joinEpoch: joinEpoch,
      module: module,
      hash: hash,
      bytes: bytes,
      opId: opId,
      requestId: requestId,
    );
    events.add('blob:$hash');
  }
}

class ServerFixture {
  static String? cachedTokenA;
  static String? cachedTokenB;
  bool hasDatabase = false;
  late DioApiClient a;
  late DioApiClient b;
  late String tokenA;
  late String tokenB;
  late String space;
  late String account;
  late String purpose;
  late SyncHarness h;
  late RecordedRealApi observed;

  DioApiClient client(String server, String? token) => DioApiClient(
    server: server,
    clientHeader: 'android/0.1.0+1; channel=beta',
    token: () async => token,
  );

  Future<Map<String, Object?>> post(
    DioApiClient client,
    String path,
    Map<String, Object?> args, {
    String method = 'POST',
    int epoch = 1,
  }) async {
    final response = await client.dio.request<Object?>(
      path,
      data: args,
      options: Options(
        method: method,
        headers: {'Idempotency-Key': uuid(), 'X-Jiabu-Join-Epoch': epoch},
      ),
    );
    return response.data == null
        ? {}
        : requireValue<Map<String, Object?>>(response.data)
              .cast<String, Object?>();
  }

  Future<Map<String, Object?>> tool(
    DioApiClient client,
    String name,
    Map<String, Object?> args,
  ) => post(client, 'v1/spaces/$space/tools/$name', args);

  Future<void> start() async {
    final anonymous = client(env('JIABU_IT_URL'), null);
    // Reuse the two bootstrap sessions across cases: successful logins also
    // consume the real server's 5/minute login budget.
    tokenA = cachedTokenA ??= (await anonymous.login(
      LoginRequestDto(
        username: env('JIABU_IT_USER_A'),
        password: env('JIABU_IT_PASSWORD_A'),
      ),
    )).token;
    tokenB = cachedTokenB ??= (await anonymous.login(
      LoginRequestDto(
        username: env('JIABU_IT_USER_B'),
        password: env('JIABU_IT_PASSWORD_B'),
      ),
    )).token;
    a = client(env('JIABU_IT_URL'), tokenA);
    b = client(env('JIABU_IT_URL'), tokenB);
    space = uuid();
    await post(a, 'v1/spaces', {
      'id': space,
      'name': 'Fictional C2 family',
      'accent_color': 'pine',
      'currency': 'CNY',
      'timezone': 'Asia/Shanghai',
    });
    await inviteAgain();
    account = uuid();
    purpose = uuid();
    await tool(a, 'create_account', {
      'id': account,
      'kind': 'real',
      'name': 'Fictional bank',
      'opening_on': '2026-01-01',
    });
    await tool(a, 'create_account', {
      'id': purpose,
      'kind': 'purpose',
      'name': 'Fictional food',
      'opening_on': '2026-01-01',
    });
    observed = RecordedRealApi(b);
    h = await SyncHarness.create(api: observed, newId: uuid);
    hasDatabase = true;
    // SyncHarness's initial fake catalogue is not used for writes; replace it
    // with the actual membership before the first offline operation.
    await h.memberships.reconcile(await b.spaces());
    await h.engine.runRound();
    observed.batches.clear();
    observed.events.clear();
    observed.pulls.clear();
  }

  Future<void> inviteAgain() async {
    final invitation = await post(a, 'v1/spaces/$space/invitations', {
      'username': env('JIABU_IT_USER_B'),
    });
    await post(b, 'v1/me/invitations/${invitation['id']}/accept', {});
  }

  Map<String, Object?> expense(
    String id, {
    int amount = 100,
    List<String> images = const [],
  }) => {
    'id': id,
    'kind': 'expense',
    'amount_minor': amount,
    'occurred_on': '2026-01-01',
    'account_id': account,
    'purpose_id': purpose,
    'attachments': images,
  };
  Future<Map<String, Object?>> serverRecord(String id) =>
      tool(a, 'get_record', {'id': id});
  Future<void> close() async {
    if (hasDatabase) {
      await h.close();
    }
  }
}

void main() {
  late ServerFixture f;
  HttpOverrides? previousHttpOverrides;
  setUpAll(() {
    previousHttpOverrides = HttpOverrides.current;
    // AutomatedTestWidgetsFlutterBinding otherwise returns fake HTTP 400s.
    HttpOverrides.global = null;
  });
  tearDownAll(() async {
    final fixture = ServerFixture();
    final a = ServerFixture.cachedTokenA;
    final b = ServerFixture.cachedTokenB;
    if (a != null) {
      await fixture.client(env('JIABU_IT_URL'), a).logout();
    }
    if (b != null) {
      await fixture.client(env('JIABU_IT_URL'), b).logout();
    }
    HttpOverrides.global = previousHttpOverrides;
  });
  setUp(() async {
    f = ServerFixture();
    await f.start();
  });
  tearDown(() async {
    await f.close();
  });

  LocalLedgerRepository ledger() => LocalLedgerRepository(
    f.h.store,
    f.h.mutations,
    f.h.records,
    f.h.conflicts,
    api: f.b,
  );

  Map<String, int> balancesOf(Map<String, Object?> response) {
    final rows = (response['balances']! as List<Object?>)
        .cast<Map<String, Object?>>();
    return {
      for (final row in rows)
        requireValue<String>(row['account_id']): requireValue<int>(
          row['balance_minor'],
        ),
    };
  }

  Future<Map<String, String>> writeSharedFixture({
    bool allocation = true,
  }) async {
    final fixture = readLedgerFixture();
    final ids = <String, String>{};
    for (final value in fixture['accounts']! as List<Object?>) {
      final account = Map<String, Object?>.from(value! as Map<String, Object?>);
      final logical = account['id']! as String;
      final id = uuid();
      ids[logical] = id;
      await f.tool(f.a, 'create_account', {...account, 'id': id});
    }
    for (final value in fixture['operations']! as List<Object?>) {
      final record = Map<String, Object?>.from(value! as Map<String, Object?>);
      final logical = record.remove('id')! as String;
      final status = record.remove('status');
      final id = uuid();
      ids[logical] = id;
      for (final key in [
        'account_id',
        'to_account_id',
        'purpose_id',
        'to_purpose_id',
        'refund_of_id',
      ]) {
        if (record[key] case final String logicalId) {
          record[key] = ids[logicalId];
        }
      }
      await f.tool(f.a, 'create_record', {'id': id, ...record});
      if (status == 'voided') {
        await f.tool(f.a, 'void_record', {'id': id, 'expected_version': 1});
      }
    }
    if (allocation) {
      final today = DateTime.parse(env('JIABU_IT_SPACE_DATE_SHANGHAI'));
      // First_run(day=1) is strictly next month. The continuously enabled edit
      // to today's day runs this month's allocation through the REAL tool.
      final first = await f.tool(f.a, 'set_allocation_plan', {
        'account_id': ids['purpose-a'],
        'amount_minor': 4000,
        'day_of_month': 1,
        'enabled': true,
      });
      await f.tool(f.a, 'set_allocation_plan', {
        'account_id': ids['purpose-a'],
        'expected_version': first['version'],
        'amount_minor': 4000,
        'day_of_month': today.day,
        'enabled': true,
      });
    }
    return ids;
  }

  Future<void> compareServerAndLocal(
    Map<String, String> ids,
    Map<String, Object?> expected,
  ) async {
    await f.h.engine.runRound();
    final server = await f.tool(f.a, 'query_balance', {});
    final local = ledgerBalances(await ledger().snapshot(f.space));
    expect(local, isA<Ok<Map<String, int>>>());
    final remote = balancesOf(server);
    for (final entry in expected.entries) {
      expect(
        remote[ids[entry.key]],
        entry.value,
        reason: 'server ${entry.key}',
      );
      expect(
        (local as Ok<Map<String, int>>).value[ids[entry.key]],
        entry.value,
        reason: 'client ${entry.key}',
      );
    }
  }

  test('c3_server_shared_fixture_matches_client_balances', () async {
    final ids = await writeSharedFixture();
    await compareServerAndLocal(
      ids,
      readLedgerFixture()['expected']! as Map<String, Object?>,
    );
  });

  test('c3_server_cny_and_jpy_spaces_keep_minor_units_separate', () async {
    final jpy = uuid();
    await f.post(f.b, 'v1/spaces', {
      'id': jpy,
      'name': '虚构JPY空间',
      'accent_color': 'indigo',
      'currency': 'JPY',
      'timezone': 'UTC',
    });
    final account = uuid();
    await f.post(f.b, 'v1/spaces/$jpy/tools/create_account', {
      'id': account,
      'kind': 'real',
      'name': '虚构日元账户',
      'opening_balance_minor': 123,
      'opening_on': env('JIABU_IT_SPACE_DATE_UTC'),
    });
    final remote = await f.post(f.b, 'v1/spaces/$jpy/tools/query_balance', {});
    expect(remote['currency'], 'JPY');
    expect((remote['balances']! as List<Object?>).single, {
      'account_id': account,
      'balance_minor': 123,
    });
    final memberships = await f.b.spaces();
    await f.h.memberships.reconcile(memberships);
    await f.h.engine.runRound();
    final snapshot = await ledger().snapshot(jpy);
    expect(snapshot.currency, 'JPY');
    expect(
      (ledgerBalances(snapshot) as Ok<Map<String, int>>).value[account],
      123,
    );
    expect((await f.tool(f.a, 'query_balance', {}))['currency'], 'CNY');
    expect(
      (await ledger().snapshot(f.space)).accounts
          .any((row) => row.id == account),
      isFalse,
    );
  });

  test('c3_server_zero_setup_offline_then_uploads_all_tools', () async {
    final space = uuid();
    await f.post(f.b, 'v1/spaces', {
      'id': space,
      'name': '虚构从零建账',
      'accent_color': 'pine',
      'currency': 'CNY',
      'timezone': 'Asia/Shanghai',
    });
    // Prepare membership online, then all content writes stay offline in C2.
    await f.h.memberships.reconcile(await f.b.spaces());
    final local = LocalLedgerRepository(
      f.h.store,
      f.h.mutations,
      f.h.records,
      f.h.conflicts,
      api: f.b,
    );
    for (final spec in [
      ('用户A银行卡', 'real', 10000),
      ('用户B银行卡', 'real', 0),
      ('虚构日常', 'purpose', 5000),
      ('虚构备用', 'purpose', 2000),
    ]) {
      expect(
        await local.createAccount(space, {
          'kind': spec.$2,
          'name': spec.$1,
          'opening_balance_minor': spec.$3,
          'opening_on': '2026-10-01',
        }),
        isA<Ok<String>>(),
      );
    }
    final snapshot = await local.snapshot(space);
    expect(snapshot.records, isEmpty);
    final accounts = snapshot.accounts;
    String id(String name) =>
        accounts.singleWhere((row) => row.text('name') == name).id;
    final a = id('用户A银行卡');
    final b = id('用户B银行卡');
    final p = id('虚构日常');
    final q = id('虚构备用');
    expect(
      await local.setPlan(space, p, {
        'amount_minor': 1000,
        'day_of_month': 1,
        'enabled': true,
      }),
      isA<Ok<String>>(),
    );
    for (final values in [
      {
        'kind': 'expense',
        'amount_minor': 100,
        'account_id': a,
        'purpose_id': p,
      },
      {'kind': 'income', 'amount_minor': 500, 'account_id': a},
      {
        'kind': 'transfer',
        'amount_minor': 200,
        'account_id': a,
        'to_account_id': b,
      },
      {
        'kind': 'reallocation',
        'amount_minor': 300,
        'purpose_id': q,
        'to_purpose_id': p,
      },
    ]) {
      expect(
        await local.createRecord(space, {
          'occurred_on': '2026-10-02',
          ...values,
        }),
        isA<Ok<String>>(),
      );
    }
    expect((await f.h.store.outbox(space)).length, 9);
    final before = (ledgerBalances(
      await local.snapshot(space),
    ) as Ok<Map<String, int>>).value;
    expect(before, {a: 10200, b: 200, p: 5200, q: 1700});
    // The same B membership and API own both offline writes and upload.
    await f.h.engine.runRound();
    expect(await f.h.store.outbox(space), isEmpty);
    final remote = await f.post(
      f.b,
      'v1/spaces/$space/tools/query_balance',
      {},
    );
    expect(balancesOf(remote), before);
  });

  test(
    'c3_server_rejected_refund_void_transfer_and_archive_are_preserved',
    () async {
      final parent = await f.tool(f.a, 'create_record', f.expense(uuid()));
      await f.tool(f.a, 'create_record', {
        'id': uuid(),
        'kind': 'refund',
        'amount_minor': 60,
        'occurred_on': '2026-10-01',
        'refund_of_id': parent['id'],
      });
      await f.h.engine.runRound();
      // Bypass the form to verify C2 preserves each server rejection.
      final otherParent = await f.tool(f.a, 'create_record', f.expense(uuid()));
      await f.tool(f.a, 'create_record', {
        'id': uuid(),
        'kind': 'refund',
        'amount_minor': 1,
        'occurred_on': '2026-10-01',
        'refund_of_id': otherParent['id'],
      });
      final transferAccount = uuid();
      final archiveAccount = uuid();
      for (final id in [transferAccount, archiveAccount]) {
        await f.tool(f.a, 'create_account', {
          'id': id,
          'kind': 'real',
          'name': id == transferAccount ? '虚构转账账户' : '虚构归档账户',
          'opening_balance_minor': 100,
          'opening_on': '2026-10-01',
        });
      }
      await f.h.engine.runRound();
      final attempts = <(String, Map<String, Object?>, String, String)>[
        (
          'create_record',
          {
            'id': uuid(),
            'kind': 'refund',
            'amount_minor': 41,
            'occurred_on': '2026-10-01',
            'refund_of_id': parent['id'],
            'account_id': f.account,
            'purpose_id': f.purpose,
          },
          'record',
          'refund_exceeds_original',
        ),
        ('void_record', {'id': otherParent['id']}, 'record', 'has_refunds'),
        (
          'create_record',
          {
            'id': uuid(),
            'kind': 'transfer',
            'amount_minor': 1,
            'occurred_on': '2026-10-01',
            'account_id': transferAccount,
            'to_account_id': transferAccount,
          },
          'record',
          'validation_failed',
        ),
        (
          'archive_account',
          {'id': archiveAccount},
          'account',
          'balance_not_zero',
        ),
      ];
      for (final attempt in attempts) {
        final id = attempt.$2['id']! as String;
        final old = await f.h.store.entity(f.space, attempt.$3, id);
        expect(
          await f.h.mutations.enqueueTool(
            spaceId: f.space,
            tool: attempt.$1,
            args: attempt.$2,
            entityKind: attempt.$3,
            entityId: id,
            optimistic:
                old?.data ??
                {
                  ...attempt.$2,
                  'space_id': f.space,
                  'status': 'active',
                  'version': 0,
                },
          ),
          isA<Ok<String>>(),
        );
      }
      await f.h.engine.runRound();
      final failed = (await f.h.store.outbox(f.space))
          .where((op) => op.state == 'failed')
          .toList();
      expect(failed.length, 4);
      expect(
        failed.map((op) => op.lastError?['code']),
        containsAll([
          'refund_exceeds_original',
          'has_refunds',
          'balance_not_zero',
        ]),
      );
    },
  );

  test(
    'c3_server_continuing_plan_allocates_today_once_and_can_be_undone',
    () async {
      final ids = await writeSharedFixture();
      await compareServerAndLocal(
        ids,
        readLedgerFixture()['expected']! as Map<String, Object?>,
      );
      final search = await f.tool(f.a, 'search_records', {
        'filters': {
          'purpose_id': ids['purpose-a'],
          'kinds': ['allocation'],
        },
      });
      final allocation =
          (search['records']! as List<Object?>).single! as Map<String, Object?>;
      expect(allocation['amount_minor'], 4000);
      await f.tool(f.a, 'void_record', {
        'id': allocation['id'],
        'expected_version': allocation['version'],
      });
      await compareServerAndLocal(
        ids,
        readLedgerFixture()['expected_before_allocation']!
            as Map<String, Object?>,
      );
      await f.tool(f.a, 'restore_record', {
        'id': allocation['id'],
        'expected_version': (allocation['version']! as int) + 1,
      });
      await compareServerAndLocal(
        ids,
        readLedgerFixture()['expected']! as Map<String, Object?>,
      );
    },
  );

  test('server_offline_three_records_blob_and_refund_order', () async {
    final expense = uuid();
    final refund = uuid();
    final income = uuid();
    final media = MediaService(
      store: f.h.store,
      directory: f.h.directory,
      picker: UnusedPickerStub(),
      compressor: JpegCodecStub(),
      now: () => f.h.clock,
    );
    final imported = await media.importImage(
      f.space,
      'ledger',
      testJpeg(gps: true),
    );
    expect(imported, isA<Ok<String>>());
    final hash = (imported as Ok<String>).value;
    await f.h.records.create(f.space, f.expense(expense, images: [hash]));
    await f.h.records.create(f.space, {
      ...f.expense(refund, amount: 20),
      'kind': 'refund',
      'refund_of_id': expense,
    });
    await f.h.records.create(f.space, {
      'id': income,
      'kind': 'income',
      'amount_minor': 30,
      'occurred_on': '2026-01-01',
      'account_id': f.account,
    });
    expect(f.observed.batches, isEmpty);
    await f.h.engine.runRound();
    expect(await f.h.store.outbox(f.space), isEmpty);
    expect(
      f.observed.events.indexOf('blob:$hash'),
      lessThan(f.observed.events.indexOf('create_record:$expense')),
    );
    expect(
      f.observed.events.indexOf('create_record:$expense'),
      lessThan(f.observed.events.indexOf('create_record:$refund')),
    );
    final expenseBatch = f.observed.batches.indexWhere(
      (batch) => batch.any((op) => op.args['id'] == expense),
    );
    final refundBatch = f.observed.batches.indexWhere(
      (batch) => batch.any((op) => op.args['id'] == refund),
    );
    expect(
      expenseBatch,
      lessThan(refundBatch),
      reason: 'Refund must wait for an acknowledged expense batch',
    );
    for (final id in [expense, refund, income]) {
      expect((await f.serverRecord(id))['version'], 1);
    }
    expect(await f.b.downloadBlob(f.space, hash, 'original'), isNotEmpty);
  });

  test('server_three_offline_edits_use_three_requests_an'
      'd_increment_versions', () async {
    final id = uuid();
    final original = await f.tool(f.b, 'create_record', f.expense(id));
    await f.h.store.putEntity(f.space, 'record', original);
    for (final amount in [110, 120, 130]) {
      await f.h.records.update(f.space, id, {'amount_minor': amount});
    }
    await f.h.engine.runRound();
    expect(f.observed.batches.map((b) => b.length), [1, 1, 1]);
    expect(f.observed.batches.map((b) => b.single.args['expected_version']), [
      1,
      2,
      3,
    ]);
    final server = await f.serverRecord(id);
    expect(server['amount_minor'], 130);
    expect(server['version'], 4);
  });

  test('server_conflict_server_mine_and_explicit_restore_paths', () async {
    final id = uuid();
    final original = await f.tool(f.b, 'create_record', f.expense(id));
    await f.h.store.putEntity(f.space, 'record', original);
    await f.h.records.update(f.space, id, {'amount_minor': 150});
    await f.tool(f.a, 'update_record', {
      'id': id,
      'expected_version': 1,
      'changes': {'amount_minor': 120},
    });
    await f.h.engine.runRound();
    expect(
      (await f.h.store.entity(f.space, 'record', id))?.syncState,
      'conflict',
    );
    await f.h.conflicts.resolveWithServer(f.space, 'record', id);
    expect(
      (await f.h.store.entity(f.space, 'record', id))?.data['amount_minor'],
      120,
    );
    await f.h.records.update(f.space, id, {'amount_minor': 140});
    await f.tool(f.a, 'update_record', {
      'id': id,
      'expected_version': 2,
      'changes': {'amount_minor': 130},
    });
    await f.h.engine.runRound();
    await f.h.conflicts.resolveWithMine(f.space, 'record', id);
    await f.h.engine.runRound();
    expect((await f.serverRecord(id))['amount_minor'], 140);
    await f.h.records.update(f.space, id, {'amount_minor': 160});
    await f.tool(f.a, 'void_record', {'id': id, 'expected_version': 4});
    await f.h.engine.runRound();
    expect(
      await f.h.conflicts.resolveWithMine(f.space, 'record', id),
      isA<Failure<void>>(),
    );
    await f.h.conflicts.restoreAndApplyMine(f.space, id);
    await f.h.engine.runRound();
    final restored = await f.serverRecord(id);
    expect(restored['status'], 'active');
    expect(restored['amount_minor'], 160);
    expect(restored['version'], 7);
  });

  test('server_rejoin_clears_old_queue_and_refills_from_zero', () async {
    final id = uuid();
    final original = await f.tool(f.b, 'create_record', f.expense(id));
    await f.h.store.putEntity(f.space, 'record', original);
    await f.h.records.update(f.space, id, {'amount_minor': 155});
    final queuedId = uuid();
    await f.h.records.create(f.space, f.expense(queuedId));
    await f.h.store.putConflict(
      f.space,
      'record',
      'old-conflict',
      {'id': 'old-conflict'},
      1,
      'active',
      0,
    );
    final image = await File('${f.h.directory.path}/old.jpg')
        .writeAsBytes(testJpeg());
    await f.h.store.putBlob(
      f.space,
      'ledger',
      'old-hash',
      image.path,
      await image.length(),
    );
    final before = (await f.b.spaces()).spaces.singleWhere(
      (space) => space.id == f.space,
    );
    await f.post(
      f.a,
      'v1/spaces/${f.space}/members/${before.memberId}',
      {},
      method: 'DELETE',
    );
    await f.inviteAgain();
    final after = (await f.b.spaces()).spaces.singleWhere(
      (space) => space.id == f.space,
    );
    expect(after.joinEpoch, greaterThan(before.joinEpoch));
    await f.h.engine.runRound();
    expect(await f.h.store.outbox(f.space), isEmpty);
    expect(await f.h.store.blobs(f.space), isEmpty);
    expect(image.existsSync(), isFalse);
    expect(await f.h.store.conflict(f.space, 'record', 'old-conflict'), isNull);
    expect(
      f.observed.pulls
          .firstWhere((p) => p.spaces.containsKey(f.space))
          .spaces[f.space],
      0,
    );
    expect(
      (await f.h.store.entity(f.space, 'record', id))?.data['amount_minor'],
      100,
    );
    expect(await f.h.store.entity(f.space, 'record', queuedId), isNull);
    expect(f.observed.batches, isEmpty);
  });

  test('server_address_switch_counts_preserves_and_resum'
      'es_partition', () async {
    final directory = await Directory.systemTemp.createTemp(
      'jiabu-server-partitions-',
    );
    final manager = DatabaseManager(directory);
    final sessions = MemorySessions();
    final auth = LocalAuthRepository(
      databases: manager,
      settings: AppSettingsService(MemorySettings()),
      sessions: sessions,
      apiFactory: (server, partition) => DioApiClient(
        server: server,
        clientHeader: 'android/0.1.0+1; channel=beta',
        token: () async =>
            partition == null ? null : await sessions.read(partition),
      ),
    );
    addTearDown(() async {
      await manager.close();
      await directory.delete(recursive: true);
    });
    expect(
      await auth.login(
        env('JIABU_IT_URL'),
        env('JIABU_IT_USER_B'),
        env('JIABU_IT_PASSWORD_B'),
      ),
      isA<Ok<AuthSession>>(),
    );
    final first = auth.handle!;
    await first.store.setSpaceIds([f.space]);
    final membership = (await f.b.spaces()).spaces.singleWhere(
      (space) => space.id == f.space,
    );
    await first.store.putEntity(f.space, 'space', membership.toJson());
    final records = RecordsRepository(
      first.store,
      LocalMutationsRepository(first.store),
    );
    final id = uuid();
    await records.create(f.space, f.expense(id));
    expect(await auth.pendingCount(), 1);
    await auth.logout();
    await auth.login(
      env('JIABU_IT_URL_B'),
      env('JIABU_IT_USER_B'),
      env('JIABU_IT_PASSWORD_B'),
    );
    expect(auth.handle?.partition.prefix, isNot(first.partition.prefix));
    expect(await auth.pendingCount(), 0);
    expect(await first.store.outbox(f.space), hasLength(1));
    await auth.logout();
    await auth.login(
      env('JIABU_IT_URL'),
      env('JIABU_IT_USER_B'),
      env('JIABU_IT_PASSWORD_B'),
    );
    expect(auth.handle?.partition.prefix, first.partition.prefix);
    expect(await auth.pendingCount(), 1);
    final real = auth.apiFactory(env('JIABU_IT_URL'), auth.current?.partition);
    final conflicts = ConflictService(first.store);
    final engine = SyncEngine(
      store: first.store,
      api: real,
      handshake: VersionHandshakeService(real),
      memberships: MembershipReconciler(
        first.store,
        BlobCacheService(first.store, first.blobs),
      ),
      outbox: OutboxProcessor(first.store, real, conflicts),
      pull: PullApplier(first.store),
    );
    await engine.runRound();
    expect(await auth.pendingCount(), 0);
    expect((await f.serverRecord(id))['version'], 1);
  });
}
