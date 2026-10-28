import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/api/dto/problem_dto.dart';
import 'package:jiabu/data/api/dto/sync_dto.dart';
import 'package:jiabu/domain/entity_ref.dart';
import 'package:jiabu/domain/outbox_operation.dart';
import 'package:jiabu/domain/required_value.dart';
import 'package:jiabu/domain/result.dart';

import '../support/sync_harness.dart';

void main() {
  late SyncHarness h;
  setUp(() async {
    h = await SyncHarness.create();
    await h.seed('r');
  });
  tearDown(() async {
    await h.close();
  });

  Future<void> conflict({bool voided = false, bool refund = false}) async {
    for (final amount in [110, 120, 150]) {
      await h.records.update('s', 'r', {'amount_minor': amount});
    }
    if (refund) {
      await h.records.create(
        's',
        {
          ...sampleRecord('refund'),
          'kind': 'refund',
          'refund_of_id': 'r',
          'amount_minor': 20,
        }..remove('version'),
      );
    }
    final current = sampleRecord(
      'r',
      amount: 90,
      version: 2,
      status: voided ? 'voided' : 'active',
    );
    h.api.server['r'] = current;
    h.api.onPush = (ops) async => PushResponseDto(
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
    await h.engine.runRound();
    h.api.onPush = null;
  }

  Future<void> editExistingRefund({bool restore = false}) async {
    final refund = {
      ...sampleRecord(
        'refund',
        amount: restore ? 150 : 20,
        status: restore ? 'voided' : 'active',
      ),
      'kind': 'refund',
      'refund_of_id': 'r',
    };
    await h.store.putEntity('s', 'record', refund);
    h.api.server['refund'] = refund;
    // Another device advances R's version while this device is offline.
    h.api.server['r'] = sampleRecord('r', version: 2);
    expect(
      await h.records.update('s', 'r', {'amount_minor': 200}),
      isA<Ok<String>>(),
    );
    if (restore) {
      expect(
        await h.mutations.enqueueTool(
          spaceId: 's',
          tool: 'restore_record',
          args: {'id': 'refund'},
          entityKind: 'record',
          entityId: 'refund',
          optimistic: {...refund, 'status': 'active'},
        ),
        isA<Ok<String>>(),
      );
    } else {
      expect(
        await h.records.update('s', 'refund', {'amount_minor': 150}),
        isA<Ok<String>>(),
      );
    }
    h.api.onPush = (ops) async => PushResponseDto(
      results: [
        for (final op in ops)
          if (op.args['id'] == 'r' && op.args['expected_version'] == 1)
            PushResultDto(
              opId: op.opId,
              status: 'conflict',
              problem: ProblemDto(
                code: 'version_conflict',
                status: 409,
                current: h.api.server['r'],
              ),
            )
          else if (op.args['id'] == 'refund' &&
              requireValue<int>(h.api.server['r']?['amount_minor']) < 150)
            PushResultDto(
              opId: op.opId,
              status: 'rejected',
              problem: const ProblemDto(
                code: 'refund_exceeds_original',
                status: 422,
              ),
            )
          else
            h.api.apply([op]).results.single,
      ],
    );
  }

  test('refund_update_waits_while_parent_expense_in_conflict', () async {
    await editExistingRefund();
    await h.engine.runRound();
    expect((await h.store.entity('s', 'record', 'r'))?.syncState, 'conflict');
    final waiting = (await h.store.outbox('s')).single;
    expect(waiting.entityIds, {'record:refund'});
    expect(waiting.state, 'blocked');
    expect(waiting.attempts, 0);
    expect(waiting.lastError, isNull);
    await h.engine.runRound();
    expect(h.api.batches.expand((batch) => batch).map((op) => op.args['id']), [
      'r',
    ]);
    expect((await h.store.outbox('s')).single.state, 'blocked');
  });

  test('refund_update_continues_after_parent_conflict_resolved', () async {
    await editExistingRefund();
    await h.engine.runRound();
    expect(
      await h.conflicts.resolveWithMine('s', 'record', 'r'),
      isA<Ok<void>>(),
    );
    await h.engine.runRound();
    expect(h.api.batches.map((batch) => batch.map((op) => op.args['id'])), [
      ['r'],
      ['r'],
      ['refund'],
    ]);
    expect(h.api.server['r']?['amount_minor'], 200);
    expect(h.api.server['refund']?['amount_minor'], 150);
    expect(
      (await h.store.entity('s', 'record', 'refund'))?.syncState,
      'synced',
    );
    expect(await h.store.outbox('s'), isEmpty);
  });

  test('refund_restore_waits_for_parent_conflict_resolution', () async {
    await editExistingRefund(restore: true);
    await h.engine.runRound();
    final waiting = (await h.store.outbox('s')).single;
    expect(waiting.payload['tool'], 'restore_record');
    expect(waiting.state, 'blocked');
    expect(waiting.attempts, 0);
    expect(h.api.server['refund']?['status'], 'voided');
    expect(
      await h.conflicts.resolveWithMine('s', 'record', 'r'),
      isA<Ok<void>>(),
    );
    await h.engine.runRound();
    expect(h.api.batches.map((batch) => batch.map((op) => op.args['id'])), [
      ['r'],
      ['r'],
      ['refund'],
    ]);
    expect(h.api.batches.last.single.tool, 'restore_record');
    expect(h.api.server['refund']?['status'], 'active');
    expect(
      (await h.store.entity('s', 'record', 'refund'))?.syncState,
      'synced',
    );
    expect(await h.store.outbox('s'), isEmpty);
  });

  test('pending_to_conflict_folds_all_edits_and_blocks_d'
      'ependencies', () async {
    await conflict(refund: true);
    final row = await h.store.entity('s', 'record', 'r');
    final saved = await h.store.conflict('s', 'record', 'r');
    expect(row?.syncState, 'conflict');
    expect(row?.data['amount_minor'], 90);
    expect(row?.baseVersion, 2);
    expect(
      (jsonDecode(requireValue<String>(saved!['mine_json']))
          as Map<String, Object?>)['amount_minor'],
      150,
    );
    expect((await h.store.outbox('s')).single.state, 'blocked');
    expect(h.api.batches, hasLength(1));
  });

  test('conflict_to_synced_use_server_unblocks_refund', () async {
    await conflict(refund: true);
    expect(
      await h.conflicts.resolveWithServer('s', 'record', 'r'),
      isA<Ok<void>>(),
    );
    expect((await h.store.entity('s', 'record', 'r'))?.syncState, 'synced');
    expect(
      (await h.store.entity('s', 'record', 'r'))?.data['amount_minor'],
      90,
    );
    expect(await h.store.conflict('s', 'record', 'r'), isNull);
    expect((await h.store.outbox('s')).single.state, 'pending');
  });

  test('conflict_to_pending_use_mine_then_synced', () async {
    await conflict();
    expect(
      await h.conflicts.resolveWithMine('s', 'record', 'r'),
      isA<Ok<void>>(),
    );
    expect(
      (await h.store.entity('s', 'record', 'r'))?.data['amount_minor'],
      150,
    );
    expect((await h.store.entity('s', 'record', 'r'))?.syncState, 'pending');
    final queued = (await h.store.outbox('s')).single;
    expect(
      requireValue<Map<String, Object?>>(queued.payload['args'])
          .containsKey('expected_version'),
      isFalse,
    );
    await h.engine.runRound();
    expect(h.api.batches.last.single.args['expected_version'], 2);
    expect((await h.store.entity('s', 'record', 'r'))?.syncState, 'synced');
    expect(h.api.server['r']?['amount_minor'], 150);
  });

  test('voided_acknowledge_keeps_server_void_and_unblocks_refund', () async {
    await conflict(voided: true, refund: true);
    await h.conflicts.acknowledgeVoided('s', 'record', 'r');
    expect(
      (await h.store.entity('s', 'record', 'r'))?.data['status'],
      'voided',
    );
    expect((await h.store.entity('s', 'record', 'r'))?.syncState, 'synced');
    expect((await h.store.outbox('s')).single.state, 'pending');
  });

  test('voided_mine_requires_explicit_restore', () async {
    await conflict(voided: true);
    expect(
      await h.conflicts.resolveWithMine('s', 'record', 'r'),
      isA<Failure<void>>(),
    );
    expect((await h.store.entity('s', 'record', 'r'))?.syncState, 'conflict');
    expect(await h.store.outbox('s'), isEmpty);
  });

  test('restore_then_update_use_successive_server_versions', () async {
    await conflict(voided: true);
    await h.conflicts.restoreAndApplyMine('s', 'r');
    expect((await h.store.outbox('s')).map((op) => op.payload['tool']), [
      'restore_record',
      'update_record',
    ]);
    h.api.onPush = (ops) async {
      if (ops.single.tool == 'update_record') {
        expect(
          (await h.store.entity('s', 'record', 'r'))?.data['amount_minor'],
          150,
        );
        expect((await h.store.entity('s', 'record', 'r'))?.baseVersion, 3);
      }
      return h.api.apply(ops);
    };
    await h.engine.runRound();
    expect(h.api.batches.skip(1).map((batch) => batch.single.tool), [
      'restore_record',
      'update_record',
    ]);
    expect(
      h.api.batches
          .skip(1)
          .map((batch) => batch.single.args['expected_version']),
      [2, 3],
    );
    expect(h.api.server['r']?['status'], 'active');
    expect(h.api.server['r']?['amount_minor'], 150);
  });

  test('conflict_pull_advances_server_version_but_preserves_mine', () async {
    await conflict();
    await h.store.transaction(
      () => h.pull.applyPage(
        PullPageDto(
          spaceId: 's',
          cursor: 7,
          hasMore: false,
          changes: [
            ChangeDto(
              entity: 'record',
              data: sampleRecord('r', amount: 70, version: 5),
            ),
          ],
        ),
        requestedCursor: 0,
      ),
    );
    final saved = await h.store.conflict('s', 'record', 'r');
    expect(saved?['server_version'], 5);
    expect(
      (jsonDecode(requireValue<String>(saved!['mine_json']))
          as Map<String, Object?>)['amount_minor'],
      150,
    );
    expect(
      (await h.store.entity('s', 'record', 'r'))?.data['amount_minor'],
      70,
    );
    await h.conflicts.resolveWithMine('s', 'record', 'r');
    await h.engine.runRound();
    expect(h.api.batches.last.single.args['expected_version'], 5);
  });

  test('resolving_mine_can_conflict_again_without_silent'
      '_overwrite', () async {
    await conflict();
    await h.conflicts.resolveWithMine('s', 'record', 'r');
    h.api.onPush = (ops) async => PushResponseDto(
      results: [
        PushResultDto(
          opId: ops.single.opId,
          status: 'conflict',
          problem: ProblemDto(
            code: 'version_conflict',
            status: 409,
            current: sampleRecord('r', amount: 65, version: 8),
          ),
        ),
      ],
    );
    await h.engine.runRound();
    expect((await h.store.entity('s', 'record', 'r'))?.syncState, 'conflict');
    expect((await h.store.conflict('s', 'record', 'r'))?['server_version'], 8);
    expect(
      (await h.store.entity('s', 'record', 'r'))?.data['amount_minor'],
      65,
    );
  });

  test('conflict_captures_edit_made_during_request', () async {
    await h.records.update('s', 'r', {'amount_minor': 110});
    h.api.onPush = (ops) async {
      await h.records.update('s', 'r', {'amount_minor': 170});
      return PushResponseDto(
        results: [
          PushResultDto(
            opId: ops.single.opId,
            status: 'conflict',
            problem: ProblemDto(
              code: 'version_conflict',
              status: 409,
              current: sampleRecord('r', version: 2),
            ),
          ),
        ],
      );
    };
    await h.engine.runRound();
    final saved = await h.store.conflict('s', 'record', 'r');
    expect(
      (jsonDecode(requireValue<String>(saved!['mine_json']))
          as Map<String, Object?>)['amount_minor'],
      170,
    );
    expect(await h.store.outbox('s'), isEmpty);
  });

  test('restoring_mine_keeps_refund_behind_restore_and_update', () async {
    await conflict(voided: true, refund: true);
    await h.conflicts.restoreAndApplyMine('s', 'r');
    expect((await h.store.outbox('s')).map((op) => op.payload['tool']), [
      'restore_record',
      'update_record',
      'create_record',
    ]);
    await h.engine.runRound();
    expect(h.api.batches.skip(1).map((b) => b.single.tool), [
      'restore_record',
      'update_record',
      'create_record',
    ]);
  });

  test('resolve_mine_keeps_required_blob_ahead_of_resolution', () async {
    await h.records.update('s', 'r', {'amount_minor': 110});
    h.api.onPush = (ops) async {
      // These writes happen while the original R request is in flight.
      await h.records.create(
        's',
        {
          ...sampleRecord('refund'),
          'kind': 'refund',
          'refund_of_id': 'r',
          'amount_minor': 20,
        }..remove('version'),
      );
      // Later edits need not repeat the refund's dependency on R.
      await h.records.update('s', 'refund', {'note': 'later refund edit'});
      final file = await File('${h.directory.path}/b.jpg').writeAsBytes([1, 2]);
      await h.store.putBlob('s', 'ledger', 'b', file.path, 2);
      await h.store.enqueue(
        OutboxOperation(
          id: 'blob-b',
          spaceId: 's',
          joinEpoch: 1,
          kind: 'blob',
          payload: {'module': 'ledger', 'sha256': 'b', 'path': file.path},
          entityIds: {EntityRef.blob('ledger', 'b')},
          dependsOn: {},
          requestId: 'blob-request',
          createdAt: h.clock.microsecondsSinceEpoch,
        ),
      );
      await h.records.update('s', 'r', {
        'attachments': ['b'],
      });
      final current = sampleRecord('r', version: 2);
      h.api.server['r'] = current;
      return PushResponseDto(
        results: [
          PushResultDto(
            opId: ops.single.opId,
            status: 'conflict',
            problem: ProblemDto(
              code: 'version_conflict',
              status: 409,
              current: current,
            ),
          ),
        ],
      );
    };
    h.api.onBlob = () async => throw const ApiError('network');
    await h.engine.runRound();
    expect(h.api.events.where((event) => event == 'blob'), hasLength(1));
    final originalRefunds = (await h.store.outbox('s'))
        .where((op) => op.entityIds.contains('record:refund'))
        .toList();
    expect(originalRefunds, hasLength(2));
    expect(
      await h.conflicts.resolveWithMine('s', 'record', 'r'),
      isA<Ok<void>>(),
    );
    final queue = await h.store.outbox('s');
    expect(queue.map((op) => op.kind == 'blob' ? 'blob' : op.payload['tool']), [
      'blob',
      'update_record',
      'create_record',
      'update_record',
    ]);
    final movedRefunds = queue.skip(2).toList();
    for (var index = 0; index < originalRefunds.length; index++) {
      expect(movedRefunds[index].id, originalRefunds[index].id);
      expect(movedRefunds[index].requestId, originalRefunds[index].requestId);
      expect(movedRefunds[index].payload, originalRefunds[index].payload);
    }
    h.clock = h.clock.add(const Duration(minutes: 1));
    h.api.onPush = null;
    h.api.onBlob = null;
    await h.engine.runRound();
    expect(await h.store.outbox('s'), isEmpty);
    expect((await h.store.blobs('s')).single['uploaded'], 1);
    expect(h.api.batches.skip(1).map((batch) => batch.single.args['id']), [
      'r',
      'refund',
      'refund',
    ]);
    expect(h.api.server['r']?['attachments'], ['b']);
  });

  test('resolve_mine_preserves_void_intent_after_version_conflict', () async {
    const reason = 'user';
    expect(
      await h.mutations.enqueueTool(
        spaceId: 's',
        tool: 'void_record',
        args: {'id': 'r'},
        entityKind: 'record',
        entityId: 'r',
        optimistic: {
          ...sampleRecord('r'),
          'status': 'voided',
          'void_reason': reason,
        },
      ),
      isA<Ok<String>>(),
    );
    // Only the version differs: this resolution needs no field update.
    final current = sampleRecord('r', version: 2);
    h.api.server['r'] = current;
    h.api.onPush = (ops) async => PushResponseDto(
      results: [
        PushResultDto(
          opId: ops.single.opId,
          status: 'conflict',
          problem: ProblemDto(
            code: 'version_conflict',
            status: 409,
            current: current,
          ),
        ),
      ],
    );
    await h.engine.runRound();
    final saved = await h.store.conflict('s', 'record', 'r');
    final mine = jsonDecode(
      requireValue<String>(saved!['mine_json']),
    ) as Map<String, Object?>;
    expect(mine['status'], 'voided');
    expect(mine['void_reason'], reason);
    expect(
      await h.conflicts.resolveWithMine('s', 'record', 'r'),
      isA<Ok<void>>(),
    );
    final resolution = (await h.store.outbox('s')).single;
    expect(resolution.payload['tool'], 'void_record');
    // The current strict server schema only accepts id / expected_version.
    expect(resolution.payload['args'], {'id': 'r'});
    expect(
      (await h.store.entity('s', 'record', 'r'))?.data['void_reason'],
      reason,
    );
    h.api.onPush = null;
    await h.engine.runRound();
    expect(h.api.batches.last.single.args['expected_version'], 2);
    expect(h.api.server['r']?['status'], 'voided');
    final row = await h.store.entity('s', 'record', 'r');
    expect(row?.data['status'], 'voided');
    expect(row?.data['void_reason'], reason);
    expect(row?.syncState, 'synced');
    expect(await h.store.outbox('s'), isEmpty);
  });

  test('resolve_mine_update_then_void_keeps_field_edits', () async {
    await h.records.update('s', 'r', {
      'amount_minor': 175,
      'note': 'my edited note',
    });
    final local = (await h.store.entity('s', 'record', 'r'))!;
    await h.mutations.enqueueTool(
      spaceId: 's',
      tool: 'void_record',
      args: {'id': 'r'},
      entityKind: 'record',
      entityId: 'r',
      optimistic: {...local.data, 'status': 'voided', 'void_reason': 'user'},
    );
    final current = {
      ...sampleRecord('r', amount: 90, version: 2),
      'note': 'other device',
    };
    h.api.server['r'] = current;
    await h.store.transaction(
      () => h.conflicts.captureConflict('s', 'record', 'r', current),
    );
    await h.conflicts.resolveWithMine('s', 'record', 'r');
    final queue = await h.store.outbox('s');
    expect(queue.map((op) => op.payload['tool']), [
      'update_record',
      'void_record',
    ]);
    expect(queue.first.payload['args'], {
      'id': 'r',
      'changes': {'amount_minor': 175, 'note': 'my edited note'},
    });
    expect(queue.last.payload['args'], {'id': 'r'});
    h.api.onPush = (ops) async {
      expect(ops, hasLength(1));
      if (ops.single.tool == 'update_record') {
        expect(h.api.server['r']?['status'], 'active');
      } else {
        // The update must have been acknowledged before void is sent.
        expect(h.api.server['r']?['amount_minor'], 175);
        expect(h.api.server['r']?['note'], 'my edited note');
      }
      return h.api.apply(ops);
    };
    await h.engine.runRound();
    expect(
      h.api.batches.map((batch) => batch.single.args['expected_version']),
      [2, 3],
    );
    expect(h.api.server['r']?['amount_minor'], 175);
    expect(h.api.server['r']?['note'], 'my edited note');
    expect(h.api.server['r']?['status'], 'voided');
    expect((await h.store.entity('s', 'record', 'r'))?.syncState, 'synced');
    expect(await h.store.outbox('s'), isEmpty);
  });

  test('resolve_mine_waits_for_new_tag_dependency', () async {
    await h.records.update('s', 'r', {'amount_minor': 150});
    final current = sampleRecord('r', amount: 90, version: 2);
    h.api.server['r'] = current;
    h.api.onPush = (ops) async {
      if (ops.single.tool == 'create_tag') {
        throw const ApiError('network');
      }
      // The new tag and the reference both appear while R is in flight.
      await h.mutations.enqueueTool(
        spaceId: 's',
        tool: 'create_tag',
        args: {'id': 't', 'name': 'New tag'},
        entityKind: 'tag',
        entityId: 't',
        optimistic: {
          'id': 't',
          'name': 'New tag',
          'deleted_at': null,
          'version': 0,
        },
      );
      await h.records.update('s', 'r', {
        'tag_ids': ['t'],
      });
      return PushResponseDto(
        results: [
          PushResultDto(
            opId: ops.single.opId,
            status: 'conflict',
            problem: ProblemDto(
              code: 'version_conflict',
              status: 409,
              current: current,
            ),
          ),
        ],
      );
    };
    await h.engine.runRound();
    await h.conflicts.resolveWithMine('s', 'record', 'r');
    final queue = await h.store.outbox('s');
    expect(queue.map((op) => op.payload['tool']), [
      'create_tag',
      'update_record',
    ]);
    expect(queue.last.dependsOn, contains('tag:t'));
    expect(
      h.api.batches.skip(1).expand((batch) => batch).map((op) => op.tool),
      ['create_tag'],
    );
    await h.engine.runRound();
    expect(h.api.batches, hasLength(2));
    h.clock = h.clock.add(const Duration(minutes: 1));
    h.api.onPush = null;
    await h.engine.runRound();
    expect(h.api.batches.skip(2).map((batch) => batch.single.tool), [
      'create_tag',
      'update_record',
    ]);
    expect(h.api.server['r']?['tag_ids'], ['t']);
    expect(await h.store.outbox('s'), isEmpty);
  });

  test('resolve_mine_tag_delete_is_not_rename', () async {
    final current = {
      'id': 't',
      'name': 'Server tag',
      'deleted_at': null,
      'version': 2,
    };
    await h.store.putEntity('s', 'tag', {
      ...current,
      'name': 'My old tag',
      'deleted_at': '2026-01-01T00:00:00Z',
    });
    h.api.server['t'] = current;
    await h.store.transaction(
      () => h.conflicts.captureConflict('s', 'tag', 't', current),
    );
    await h.conflicts.resolveWithMine('s', 'tag', 't');
    final op = (await h.store.outbox('s')).single;
    expect(op.payload, {
      'tool': 'delete_tag',
      'args': {'id': 't'},
    });
    await h.engine.runRound();
    expect(h.api.batches.single.single.args['expected_version'], 2);
    expect(h.api.server['t']?['deleted_at'], isNotNull);
    expect(h.api.server['t']?['name'], 'Server tag');
  });

  test('resolve_mine_account_archive_is_preserved', () async {
    final current = {
      'id': 'a',
      'kind': 'purpose',
      'name': 'Server account',
      'is_reserve': false,
      'opening_balance_minor': 0,
      'opening_on': '2026-01-01',
      'sort_key': 0,
      'archived_at': null,
      'version': 2,
    };
    await h.store.putEntity('s', 'account', {
      ...current,
      'name': 'My account',
      'is_reserve': true,
      'archived_at': '2026-01-01T00:00:00Z',
    });
    h.api.server['a'] = current;
    await h.store.transaction(
      () => h.conflicts.captureConflict('s', 'account', 'a', current),
    );
    await h.conflicts.resolveWithMine('s', 'account', 'a');
    final queue = await h.store.outbox('s');
    expect(queue.map((op) => op.payload['tool']), [
      'update_account',
      'archive_account',
    ]);
    expect(queue.first.payload['args'], {
      'id': 'a',
      'name': 'My account',
      'is_reserve': true,
    });
    await h.engine.runRound();
    expect(
      h.api.batches.map((batch) => batch.single.args['expected_version']),
      [2, 3],
    );
    expect(h.api.server['a']?['name'], 'My account');
    expect(h.api.server['a']?['is_reserve'], true);
    expect(h.api.server['a']?['archived_at'], isNotNull);
    expect(await h.store.outbox('s'), isEmpty);
  });

  test('deferral_keeps_shared_reference_order', () async {
    await conflict();
    await h.store.putEntity('s', 'tag', {
      'id': 't',
      'name': 'Tag',
      'version': 1,
    });
    h.api.server['t'] = {'id': 't', 'name': 'Tag', 'version': 1};
    await h.records.create(
      's',
      {
        ...sampleRecord('f'),
        'kind': 'refund',
        'refund_of_id': 'r',
        'tag_ids': ['t'],
      }..remove('version'),
    );
    await h.mutations.enqueueTool(
      spaceId: 's',
      tool: 'delete_tag',
      args: {'id': 't'},
      entityKind: 'tag',
      entityId: 't',
      optimistic: {
        'id': 't',
        'name': 'Tag',
        'version': 1,
        'deleted_at': '2026-01-01T00:00:00Z',
      },
    );
    final originals = await h.store.outbox('s');
    await h.conflicts.resolveWithMine('s', 'record', 'r');
    final queue = await h.store.outbox('s');
    expect(queue.map((op) => op.payload['tool']), [
      'update_record',
      'create_record',
      'delete_tag',
    ]);
    for (var index = 0; index < originals.length; index++) {
      expect(queue[index + 1].id, originals[index].id);
      expect(queue[index + 1].requestId, originals[index].requestId);
      expect(queue[index + 1].payload, originals[index].payload);
    }
    h.api.onPush = (ops) async {
      if (ops.single.tool == 'create_record') {
        expect(h.api.server['t']?['deleted_at'], isNull);
      }
      return h.api.apply(ops);
    };
    await h.engine.runRound();
    expect(h.api.batches.skip(1).map((batch) => batch.single.tool), [
      'update_record',
      'create_record',
      'delete_tag',
    ]);
    expect(await h.store.outbox('s'), isEmpty);
  });

  test('resolve_mine_equal_fields_needs_no_operation', () async {
    await h.store.transaction(
      () => h.conflicts.captureConflict(
        's',
        'record',
        'r',
        sampleRecord('r', version: 2),
      ),
    );
    expect(
      await h.conflicts.resolveWithMine('s', 'record', 'r'),
      isA<Ok<void>>(),
    );
    expect(await h.store.outbox('s'), isEmpty);
    expect((await h.store.entity('s', 'record', 'r'))?.data['version'], 2);
    expect((await h.store.entity('s', 'record', 'r'))?.syncState, 'synced');
  });

  test('resolve_mine_archive_only_needs_no_update', () async {
    final current = {
      'id': 'a',
      'name': 'Account',
      'archived_at': null,
      'version': 2,
    };
    await h.store.putEntity('s', 'account', {
      ...current,
      'archived_at': '2026-01-01T00:00:00Z',
    });
    await h.store.transaction(
      () => h.conflicts.captureConflict('s', 'account', 'a', current),
    );
    await h.conflicts.resolveWithMine('s', 'account', 'a');
    expect((await h.store.outbox('s')).single.payload, {
      'tool': 'archive_account',
      'args': {'id': 'a'},
    });
  });

  test('resolve_mine_record_rebuilds_all_changed_reference_'
      'dependencies', () async {
    final current = {
      ...sampleRecord('r', version: 2),
      'attachments': ['retained'],
    };
    await h.store.putEntity('s', 'record', {
      ...current,
      'account_id': 'new-account',
      'to_account_id': 'new-destination',
      'purpose_id': 'new-purpose',
      'to_purpose_id': 'new-to-purpose',
      'tag_ids': ['t'],
      'attachments': ['retained', 'new-blob'],
    });
    await h.store.transaction(
      () => h.conflicts.captureConflict('s', 'record', 'r', current),
    );
    await h.conflicts.resolveWithMine('s', 'record', 'r');
    expect((await h.store.outbox('s')).single.dependsOn, {
      'account:new-account',
      'account:new-destination',
      'account:new-purpose',
      'account:new-to-purpose',
      'tag:t',
      EntityRef.blob('ledger', 'new-blob'),
    });
  });

  for (final enabled in [false, true]) {
    test('resolve_mine_allocation_plan_enabled_$enabled', () async {
      final current = {
        'account_id': 'p',
        'amount_minor': 100,
        'day_of_month': 10,
        'enabled': !enabled,
        'version': 2,
      };
      await h.store.putEntity('s', 'allocation_plan', {
        ...current,
        'enabled': enabled,
      });
      h.api.server['p'] = current;
      await h.store.transaction(
        () => h.conflicts.captureConflict('s', 'allocation_plan', 'p', current),
      );
      await h.conflicts.resolveWithMine('s', 'allocation_plan', 'p');
      final op = (await h.store.outbox('s')).single;
      expect(op.payload, {
        'tool': 'set_allocation_plan',
        'args': {
          'account_id': 'p',
          'amount_minor': 100,
          'day_of_month': 10,
          'enabled': enabled,
        },
      });
      expect(op.dependsOn, {'account:p'});
      await h.engine.runRound();
      expect(h.api.server['p']?['enabled'], enabled);
      expect(h.api.batches.single.single.args['expected_version'], 2);
    });
  }

  for (final (kind, field, code) in [
    ('account', 'archived_at', 'unarchive_not_supported'),
    ('tag', 'deleted_at', 'restore_tag_not_supported'),
    ('subject', 'archived_at', 'unsupported_conflict_resolution'),
    ('document', 'status', 'unsupported_conflict_resolution'),
  ]) {
    test('resolve_mine_unsupported_transition_preserves_'
        '${kind}_conflict', () async {
      final current = {
        'id': 'unsupported',
        'name': 'Server',
        'title': 'Server',
        field: field == 'status' ? 'voided' : '2026-01-01T00:00:00Z',
        'version': 2,
      };
      await h.store.putEntity('s', kind, {
        ...current,
        field: field == 'status' ? 'active' : null,
      });
      await h.store.transaction(
        () => h.conflicts.captureConflict('s', kind, 'unsupported', current),
      );
      final result = await h.conflicts.resolveWithMine(
        's',
        kind,
        'unsupported',
      );
      expect(result, isA<Failure<void>>());
      expect((result as Failure<void>).code, code);
      expect(await h.store.conflict('s', kind, 'unsupported'), isNotNull);
      expect(
        (await h.store.entity('s', kind, 'unsupported'))?.syncState,
        'conflict',
      );
      expect(await h.store.outbox('s'), isEmpty);
    });
  }
}
