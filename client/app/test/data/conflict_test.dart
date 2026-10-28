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
    final current = sampleRecord('r', amount: 90, version: 2);
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
}
