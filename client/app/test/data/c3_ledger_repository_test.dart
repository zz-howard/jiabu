import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/api/dto/sync_dto.dart';
import 'package:jiabu/data/repositories/ledger_repository.dart';
import 'package:jiabu/domain/ledger.dart';
import 'package:jiabu/domain/ledger_balance.dart';
import 'package:jiabu/domain/result.dart';

import '../support/sync_harness.dart';

void main() {
  late SyncHarness h;
  late LocalLedgerRepository repo;
  setUp(() async {
    h = await SyncHarness.create();
    repo = LocalLedgerRepository(h.store, h.mutations, h.records, h.conflicts);
    for (final pair in [
      ('a', 'real'),
      ('b', 'real'),
      ('p', 'purpose'),
      ('q', 'purpose'),
    ]) {
      await h.store.putEntity('s', 'account', {
        'id': pair.$1,
        'space_id': 's',
        'kind': pair.$2,
        'name': '虚构${pair.$1}',
        'opening_balance_minor': 10000,
        'opening_on': '2026-01-01',
        'version': 1,
      });
    }
  });
  tearDown(() => h.close());
  test('repository_snapshot_never_reads_other_space', () async {
    await h.seed('same-id');
    await h.store.putEntity('t', 'space', {
      'id': 't',
      'space_id': 't',
      'name': '虚构空间B',
      'currency': 'JPY',
      'modules': {'ledger': 'write'},
    });
    await h.store.putEntity('t', 'account', {
      'id': 'a',
      'space_id': 't',
      'kind': 'real',
      'name': '用户B账户',
      'opening_balance_minor': 999,
    });
    await h.store.putEntity(
      't',
      'record',
      sampleRecord('same-id', spaceId: 't', amount: 999),
    );
    await h.store.putEntity('t', 'entity_event', {
      'id': 1,
      'space_id': 't',
      'entity_kind': 'record',
      'entity_id': 'same-id',
      'kind': 'create',
    });
    final a = await repo.snapshot('s');
    final b = await repo.snapshot('t');
    expect(a.records.single.number('amount_minor'), 100);
    expect(b.records.single.number('amount_minor'), 999);
    expect(a.events, isEmpty);
    expect(b.events, hasLength(1));
    expect(a.accounts.any((row) => row.text('name') == '用户B账户'), isFalse);
    expect(b.currency, 'JPY');
  });
  test('original_image_reads_only_current_space_reference'
      '_and_handles_missing_file', () async {
    final row = sampleRecord('image');
    await h.store.putEntity('s', 'record', {
      ...row,
      'attachments': ['fictional-hash'],
    });
    final file = File('${h.directory.path}/fictional.jpg');
    await file.writeAsBytes([1, 2, 3]);
    await h.store.putBlob('s', 'ledger', 'fictional-hash', file.path, 3);
    expect((await repo.image('s', 'fictional-hash') as Ok<List<int>>).value, [
      1,
      2,
      3,
    ]);
    await file.delete();
    expect(await repo.image('s', 'fictional-hash'), isA<Failure<List<int>>>());
    expect(await repo.image('s', 'not-referenced'), isA<Failure<List<int>>>());
  });
  test('archive_plan_side_effect_is_corrected_by_pull', () async {
    await h.store.putEntity('s', 'account', {
      'id': 'z',
      'space_id': 's',
      'kind': 'purpose',
      'name': '虚构用途',
      'opening_balance_minor': 0,
      'version': 1,
    });
    await h.store.putEntity('s', 'allocation_plan', {
      'account_id': 'z',
      'space_id': 's',
      'amount_minor': 100,
      'day_of_month': 1,
      'enabled': true,
      'version': 1,
    });
    h.api.server['z'] = (await h.store.entity('s', 'account', 'z'))!.data;
    await repo.archiveAccount('s', 'z');
    await h.engine.runRound();
    final plan = (await h.store.entity('s', 'allocation_plan', 'z'))!.data;
    await h.store.transaction(
      () => h.pull.applyPage(
        PullPageDto(
          spaceId: 's',
          cursor: 1,
          hasMore: false,
          changes: [
            ChangeDto(
              entity: 'allocation_plan',
              data: {...plan, 'enabled': false, 'version': 2},
            ),
          ],
        ),
        requestedCursor: 0,
      ),
    );
    expect(
      (await repo.snapshot('s'))
          .find((await repo.snapshot('s')).plans, 'z')!
          .flag('enabled'),
      isFalse,
    );
  });
  test('record_write_and_queue_roll_back_together', () async {
    await expectLater(
      h.store.transaction(() async {
        expect(
          await repo.createRecord('s', {
            'kind': 'expense',
            'amount_minor': 20,
            'occurred_on': '2026-01-01',
            'account_id': 'a',
            'purpose_id': 'p',
          }),
          isA<Ok<String>>(),
        );
        throw StateError('fictional rollback');
      }),
      throwsStateError,
    );
    expect(await h.store.entities('s', 'record'), isEmpty);
    expect(await h.store.outbox('s'), isEmpty);
  });
  test('expense_void_waits_for_refund_void_ack', () async {
    await h.seed('expense');
    final parent = (await h.store.entity('s', 'record', 'expense'))!.data;
    await h.store.putEntity('s', 'record', {
      ...parent,
      'id': 'refund',
      'kind': 'refund',
      'refund_of_id': 'expense',
      'amount_minor': 30,
    });
    h.api.server['refund'] = {
      ...parent,
      'id': 'refund',
      'kind': 'refund',
      'refund_of_id': 'expense',
      'amount_minor': 30,
    };
    expect(
      await repo.recordStatus('s', 'expense', restore: false),
      isA<Failure<String>>(),
    );
    expect(
      await repo.recordStatus('s', 'refund', restore: false),
      isA<Ok<String>>(),
    );
    expect(
      await repo.recordStatus('s', 'expense', restore: false),
      isA<Ok<String>>(),
    );
    final queue = await h.store.outbox('s');
    expect(queue.last.dependsOn, contains('record:refund'));
    await h.engine.runRound();
    expect(
      h.api.batches
          .map((batch) => batch.map((op) => op.args['id']).toList())
          .toList(),
      [
        ['refund'],
        ['expense'],
      ],
    );
    expect(await h.store.outbox('s'), isEmpty);
  });
  test('ordinary_mine_cannot_restore_server_voided_record', () async {
    await h.seed('r');
    await h.store.transaction(
      () => h.conflicts.captureConflict(
        's',
        'record',
        'r',
        sampleRecord('r', amount: 120, version: 2, status: 'voided'),
      ),
    );
    expect(
      await repo.resolve('s', 'record', 'r', 'mine'),
      isA<Failure<void>>(),
    );
    expect(
      (await h.store.entity('s', 'record', 'r'))!.data['status'],
      'voided',
    );
    expect(await h.store.outbox('s'), isEmpty);
    expect(await h.store.conflict('s', 'record', 'r'), isNotNull);
    expect(await repo.resolve('s', 'record', 'r', 'restore'), isA<Ok<void>>());
    expect((await h.store.outbox('s')).map((op) => op.payload['tool']), [
      'restore_record',
      'update_record',
    ]);
  });
  test('captured_conflict_uses_server_balance_until_resolved', () async {
    await h.seed('r');
    await repo.editRecord('s', 'r', {'amount_minor': 700});
    await h.store.transaction(
      () => h.conflicts.captureConflict(
        's',
        'record',
        'r',
        sampleRecord('r', amount: 200, version: 2),
      ),
    );
    final snapshot = await repo.snapshot('s');
    expect(snapshot.mine('record', 'r')!.number('amount_minor'), 700);
    expect((ledgerBalances(snapshot) as Ok<Map<String, int>>).value['a'], 9800);
    expect(await repo.resolve('s', 'record', 'r', 'server'), isA<Ok<void>>());
    expect((await h.store.entity('s', 'record', 'r'))!.syncState, 'synced');
  });
  test(
    'archive_nonzero_rejected_and_archived_plan_hidden_by_account',
    () async {
      expect(await repo.archiveAccount('s', 'p'), isA<Failure<String>>());
      await h.store.putEntity('s', 'account', {
        'id': 'z',
        'space_id': 's',
        'kind': 'purpose',
        'name': '虚构零余额',
        'opening_balance_minor': 0,
        'version': 1,
      });
      await repo.setPlan('s', 'z', {
        'amount_minor': 100,
        'day_of_month': 1,
        'enabled': true,
      });
      expect(await repo.archiveAccount('s', 'z'), isA<Ok<String>>());
      final snapshot = await repo.snapshot('s');
      expect(snapshot.find(snapshot.accounts, 'z')!.archived, isTrue);
      // Plan remains locally enabled until the server side-effect is pulled.
      expect(snapshot.find(snapshot.plans, 'z')!.flag('enabled'), isTrue);
      expect(
        await repo.setPlan('s', 'z', {
          'amount_minor': 100,
          'day_of_month': 1,
          'enabled': true,
        }),
        isA<Failure<String>>(),
      );
    },
  );
  test('watch_reports_failed_state_without_queue_count_change', () async {
    final snapshots = <LedgerSnapshot>[];
    final subscription = repo.watch('s').listen(snapshots.add);
    await repo.createRecord('s', {
      'kind': 'income',
      'amount_minor': 10,
      'occurred_on': '2026-01-01',
      'account_id': 'a',
    });
    final op = (await h.store.outbox('s')).single;
    final failed = repo
        .watch('s')
        .firstWhere(
          (data) => data.pending.any((r) => r.text('state') == 'failed'),
        );
    await h.store.setOutboxState(
      's',
      op.id,
      'failed',
      error: {'code': 'validation_failed'},
    );
    expect((await failed).pending.single.text('error'), 'validation_failed');
    await subscription.cancel();
  });
}
