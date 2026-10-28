import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/api/dto/problem_dto.dart';
import 'package:jiabu/data/api/dto/spaces_dto.dart';
import 'package:jiabu/data/api/dto/sync_dto.dart';
import 'package:jiabu/domain/entity_ref.dart';
import 'package:jiabu/domain/outbox_operation.dart';
import 'package:jiabu/domain/required_value.dart';

import '../support/sync_harness.dart';

void main() {
  late SyncHarness h;
  setUp(() async {
    h = await SyncHarness.create();
  });
  tearDown(() async {
    await h.close();
  });

  test('same_record_three_edits_use_three_batches', () async {
    await h.seed('r');
    for (final amount in [110, 120, 130]) {
      await h.records.update('s', 'r', {'amount_minor': amount});
    }
    expect(
      (await h.store.outbox('s')).every(
        (op) =>
            !requireValue<Map<String, Object?>>(op.payload['args'])
                .containsKey('expected_version'),
      ),
      isTrue,
    );
    await h.engine.runRound();
    expect(h.api.batches.map((batch) => batch.length), [1, 1, 1]);
    expect(
      h.api.batches.map((batch) => batch.single.args['expected_version']),
      [1, 2, 3],
    );
    expect(h.api.server['r']?['amount_minor'], 130);
    expect((await h.store.entity('s', 'record', 'r'))?.baseVersion, 4);
    expect(await h.store.outbox('s'), isEmpty);
  });

  test('expected_version_is_bound_after_predecessor_ack', () async {
    await h.seed('r', version: 7);
    await h.records.update('s', 'r', {'amount_minor': 110});
    await h.records.update('s', 'r', {'amount_minor': 120});
    await h.engine.runRound();
    expect(h.api.batches.map((b) => b.single.args['expected_version']), [7, 8]);
  });

  test('upload_in_flight_edit_keeps_latest_content', () async {
    await h.seed('r');
    await h.records.update('s', 'r', {'amount_minor': 110});
    h.api.onPush = (ops) async {
      if (h.api.batches.length == 1) {
        await h.records.update('s', 'r', {'amount_minor': 120});
        final response = h.api.apply(ops);
        // Force a second request to inspect the first acknowledgement's state.
        h.api.onPush = (next) async {
          final row = await h.store.entity('s', 'record', 'r');
          expect(row?.data['amount_minor'], 120);
          expect(row?.baseVersion, 2);
          expect(row?.syncState, 'pending');
          return h.api.apply(next);
        };
        return response;
      }
      return h.api.apply(ops);
    };
    await h.engine.runRound();
    expect(h.api.server['r']?['amount_minor'], 120);
  });

  test('refund_waits_for_expense_ack', () async {
    await h.records.create(
      's',
      {...sampleRecord('expense')}..remove('version'),
    );
    await h.records.create(
      's',
      {
        ...sampleRecord('refund'),
        'kind': 'refund',
        'refund_of_id': 'expense',
        'amount_minor': 30,
      }..remove('version'),
    );
    h.api.onPush = (ops) async {
      if (ops.any((op) => op.args['id'] == 'refund')) {
        expect(h.api.server.containsKey('expense'), isTrue);
      }
      return h.api.apply(ops);
    };
    await h.engine.runRound();
    expect(h.api.batches.map((b) => b.single.args['id']), [
      'expense',
      'refund',
    ]);
  });

  test('blob_precedes_referencing_record', () async {
    final file = await File('${h.directory.path}/photo.jpg')
        .writeAsBytes([1, 2]);
    await h.store.putBlob('s', 'ledger', 'hash', file.path, 2);
    await h.store.enqueue(
      OutboxOperation(
        id: 'blob',
        spaceId: 's',
        joinEpoch: 1,
        kind: 'blob',
        payload: {'module': 'ledger', 'sha256': 'hash', 'path': file.path},
        entityIds: {EntityRef.blob('ledger', 'hash')},
        dependsOn: {},
        requestId: 'req',
        createdAt: 0,
      ),
    );
    await h.records.create(
      's',
      {
        ...sampleRecord('r'),
        'attachments': ['hash'],
      }..remove('version'),
    );
    await h.engine.runRound();
    expect(
      h.api.events.indexOf('blob'),
      lessThan(h.api.events.indexOf('create_record')),
    );
    expect((await h.store.blobs('s')).single['uploaded'], 1);
    expect(await h.store.outbox('s'), isEmpty);
  });

  test('unrelated_ops_continue_past_blocked_or_failed', () async {
    for (final id in ['r', 'other']) {
      await h.seed(id);
      await h.records.update('s', id, {'amount_minor': 130});
    }
    final first = (await h.store.outbox('s')).first;
    await h.store.setOutboxState('s', first.id, 'failed');
    await h.records.update('s', 'r', {'amount_minor': 140});
    await h.engine.runRound();
    expect(h.api.batches.single.single.args['id'], 'other');
    expect(await h.store.outbox('s'), hasLength(2));
  });

  test('pending_pull_skips_content_and_base_version', () async {
    await h.seed('r');
    await h.records.update('s', 'r', {'amount_minor': 140});
    await h.store.transaction(
      () => h.pull.applyPage(
        PullPageDto(
          spaceId: 's',
          cursor: 4,
          hasMore: false,
          changes: [
            ChangeDto(
              entity: 'record',
              data: sampleRecord('r', amount: 999, version: 8),
            ),
          ],
        ),
        requestedCursor: 0,
      ),
    );
    final row = await h.store.entity('s', 'record', 'r');
    expect(row?.data['amount_minor'], 140);
    expect(row?.baseVersion, 1);
    expect(await h.store.cursor('s'), 4);
  });

  for (final status in [
    'rejected',
    'space_unavailable',
    'membership_changed',
    'not_processed',
  ]) {
    test('push_result_$status', () async {
      await h.seed('r');
      await h.records.update('s', 'r', {'amount_minor': 140});
      h.api.onPush = (ops) async => PushResponseDto(
        results: [
          PushResultDto(
            opId: ops.single.opId,
            status: status,
            problem: status == 'rejected'
                ? const ProblemDto(code: 'parent_voided', status: 422)
                : null,
          ),
        ],
      );
      await h.engine.runRound();
      expect(
        (await h.store.outbox('s')).single.state,
        status == 'rejected' ? 'failed' : 'pending',
      );
      expect(h.api.batches, hasLength(1));
    });
  }

  test('rejected_429_is_retryable_and_honors_retry_after', () async {
    await h.seed('r');
    await h.records.update('s', 'r', {'amount_minor': 140});
    h.api.onPush = (ops) async => PushResponseDto(
      results: [
        PushResultDto(
          opId: ops.single.opId,
          status: 'rejected',
          problem: const ProblemDto(
            code: 'rate_limited',
            status: 429,
            retryAfter: 60,
          ),
        ),
      ],
    );
    await h.engine.runRound();
    expect((await h.store.outbox('s')).single.state, 'pending');
    await h.engine.runRound();
    expect(h.api.batches, hasLength(1));
    h.clock = h.clock.add(const Duration(seconds: 60));
    h.api.onPush = null;
    await h.engine.runRound();
    expect(await h.store.outbox('s'), isEmpty);
  });

  test('null_op_id_422_matches_only_ordered_rejection', () async {
    await h.seed('r');
    await h.records.update('s', 'r', {'amount_minor': 140});
    h.api.onPush = (_) async => const PushResponseDto(
      results: [
        PushResultDto(
          status: 'rejected',
          problem: ProblemDto(code: 'validation_failed', status: 422),
        ),
      ],
    );
    await h.engine.runRound();
    expect((await h.store.outbox('s')).single.state, 'failed');
  });

  test('not_processed_resumes_next_round_without_replayi'
      'ng_success', () async {
    for (final id in ['r', 'x']) {
      await h.seed(id);
      await h.records.update('s', id, {'amount_minor': 140});
    }
    h.api.onPush = (ops) async => PushResponseDto(
      results: [
        ...h.api.apply([ops.first]).results,
        PushResultDto(opId: ops.last.opId, status: 'not_processed'),
      ],
    );
    await h.engine.runRound();
    expect((await h.store.outbox('s')).single.entityIds, {'record:x'});
    h.api.onPush = null;
    await h.engine.runRound();
    expect(h.api.batches.last.single.args['id'], 'x');
    expect(h.api.server['r']?['version'], 2);
  });

  test('retry_replays_identical_operation', () async {
    await h.seed('r');
    await h.records.update('s', 'r', {'amount_minor': 140});
    h.api.onPush = (_) async => throw const ApiError('network');
    await h.engine.runRound();
    final first = h.api.batches.single.single.toJson();
    // Stress the persistence boundary independently of the normal pending-pull
    // skip: an already leased operation's wire identity must remain frozen.
    final local = await h.store.entity('s', 'record', 'r');
    await h.store.putEntity(
      's',
      'record',
      local!.data,
      state: 'pending',
      baseVersion: 99,
    );
    h.clock = h.clock.add(const Duration(minutes: 1));
    h.api.onPush = null;
    await h.engine.runRound();
    expect(h.api.batches.last.single.toJson(), first);
  });

  test('whole_batch_rolls_back_when_a_later_result_is_invalid', () async {
    for (final id in ['r', 'x']) {
      await h.seed(id);
      await h.records.update('s', id, {'amount_minor': 140});
    }
    h.api.onPush = (ops) async => PushResponseDto(
      results: [
        ...h.api.apply([ops.first]).results,
        PushResultDto(
          opId: ops.last.opId,
          status: 'ok',
          result: const {'version': 2},
        ),
      ],
    );
    await h.engine.runRound();
    expect(await h.store.outbox('s'), hasLength(2));
    expect((await h.store.entity('s', 'record', 'r'))?.baseVersion, 1);
  });

  test('batch_caps_at_fifty_items', () async {
    for (var i = 0; i < 51; i++) {
      await h.seed('r$i');
      await h.records.update('s', 'r$i', {'amount_minor': 140});
    }
    await h.engine.runRound();
    expect(h.api.batches.map((b) => b.length), [50, 1]);
  });

  test('batch_caps_full_utf8_envelope_after_version_binding', () async {
    for (final id in ['r', 'x', 'y']) {
      await h.seed(id);
      await h.records.update('s', id, {
        'note': List.filled(240000, '字').join(),
      });
    }
    await h.engine.runRound();
    expect(h.api.batches, hasLength(2));
    for (final batch in h.api.batches) {
      expect(
        utf8.encode(jsonEncode(PushRequestDto(ops: batch).toJson())).length,
        lessThanOrEqualTo(2097152),
      );
    }
  });

  test('single_oversize_is_failed_and_does_not_spin', () async {
    await h.seed('r');
    await h.records.update('s', 'r', {'note': List.filled(750000, '字').join()});
    await h.engine.runRound();
    expect(h.api.batches, isEmpty);
    expect((await h.store.outbox('s')).single.state, 'failed');
  });

  test('rejoin_purges_then_pulls_from_zero', () async {
    await h.seed('r');
    await h.records.update('s', 'r', {'amount_minor': 140});
    await h.store.setCursor('s', 90);
    await h.store.putConflict(
      's',
      'record',
      'conflicted',
      {'id': 'conflicted'},
      1,
      'active',
      0,
    );
    final file = await File('${h.directory.path}/old.jpg').writeAsBytes([1]);
    await h.store.putBlob('s', 'ledger', 'hash', file.path, 1);
    h.api.spaceResponse = SpacesDto(spaces: [sampleSpace(epoch: 2)]);
    await h.engine.runRound();
    expect(h.api.batches, isEmpty);
    expect(await h.store.outbox('s'), isEmpty);
    expect(await h.store.entity('s', 'record', 'r'), isNull);
    expect(await h.store.conflict('s', 'record', 'conflicted'), isNull);
    expect(await h.store.blobs('s'), isEmpty);
    expect(file.existsSync(), isFalse);
    expect(h.api.pulls.single.spaces['s'], 0);
  });

  test('late_push_and_blob_cannot_repopulate_space', () async {
    await h.seed('r');
    await h.records.update('s', 'r', {'amount_minor': 140});
    final gate = Completer<PushResponseDto>();
    final entered = Completer<void>();
    h.api.onPush = (ops) {
      entered.complete();
      return gate.future;
    };
    final running = h.engine.runRound();
    await entered.future;
    await h.memberships.reconcile(SpacesDto(spaces: [sampleSpace(epoch: 2)]));
    gate.complete(h.api.apply(h.api.batches.single));
    await running;
    expect(await h.store.entity('s', 'record', 'r'), isNull);
    expect(await h.store.outbox('s'), isEmpty);
  });

  test('switch_a_b_a_discards_original_a_response', () async {
    await h.seed('r');
    await h.records.update('s', 'r', {'amount_minor': 140});
    final gate = Completer<PushResponseDto>();
    final entered = Completer<void>();
    h.api.onPush = (ops) {
      entered.complete();
      return gate.future;
    };
    final running = h.engine.runRound();
    await entered.future;
    await h.store.activate(authenticated: false);
    await h.store.activate(authenticated: true);
    gate.complete(h.api.apply(h.api.batches.single));
    await running;
    expect((await h.store.entity('s', 'record', 'r'))?.baseVersion, 1);
    expect(await h.store.outbox('s'), hasLength(1));
  });

  test('late_pull_cannot_restore_purged_rows_or_cursor', () async {
    final gate = Completer<PullResponseDto>();
    final entered = Completer<void>();
    h.api.onPull = (request) {
      entered.complete();
      return gate.future;
    };
    final running = h.engine.runRound();
    await entered.future;
    await h.memberships.reconcile(SpacesDto(spaces: [sampleSpace(epoch: 2)]));
    gate.complete(
      PullResponseDto(
        spaces: [
          PullPageDto(
            spaceId: 's',
            cursor: 99,
            hasMore: false,
            changes: [ChangeDto(entity: 'record', data: sampleRecord('r'))],
          ),
        ],
        unavailable: const [],
      ),
    );
    await running;
    expect(await h.store.cursor('s'), 0);
    expect(await h.store.entity('s', 'record', 'r'), isNull);
  });

  test('pull_pages_until_end_empty_page_preserves_cursor'
      '_current_space_first', () async {
    await h.memberships.reconcile(
      SpacesDto(
        spaces: [
          sampleSpace(id: 'x'),
          sampleSpace(),
        ],
      ),
    );
    h.api.spaceResponse = SpacesDto(
      spaces: [
        sampleSpace(id: 'x'),
        sampleSpace(),
      ],
    );
    h.api.onPull = (request) async {
      final entry = request.spaces.entries.single;
      final first = entry.value == 0;
      return PullResponseDto(
        spaces: [
          PullPageDto(
            spaceId: entry.key,
            cursor: first ? 7 : entry.value,
            hasMore: first,
            changes: first
                ? [
                    ChangeDto(
                      entity: 'record',
                      data: sampleRecord('r', spaceId: entry.key),
                    ),
                  ]
                : const [],
          ),
        ],
        unavailable: const [],
      );
    };
    await h.engine.runRound();
    expect(h.api.pulls.first.spaces.keys.single, 's');
    expect(h.api.pulls.map((p) => p.spaces.values.single), [0, 7, 0, 7]);
    expect(await h.store.cursor('s'), 7);
  });

  test('chat_kinds_remain_queued_for_c5', () async {
    for (final kind in ['chat_send', 'chat_action', 'chat_retry']) {
      await h.store.enqueue(
        OutboxOperation(
          id: kind,
          spaceId: 's',
          joinEpoch: 1,
          kind: kind,
          payload: const {},
          entityIds: {'chat:$kind'},
          dependsOn: {},
          requestId: 'req',
          createdAt: 0,
        ),
      );
    }
    await h.engine.runRound();
    expect(await h.store.outbox('s'), hasLength(3));
    expect(h.api.batches, isEmpty);
  });
}
