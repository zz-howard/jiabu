import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/api/dto/spaces_dto.dart';
import 'package:jiabu/domain/entity_ref.dart';
import 'package:jiabu/domain/outbox_operation.dart';
import 'package:jiabu/domain/result.dart';

import '../support/sync_harness.dart';

void main() {
  late SyncHarness h;
  setUp(() async {
    h = await SyncHarness.create();
  });
  tearDown(() async {
    await h.close();
  });

  Future<File> queueBlob() async {
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
    return file;
  }

  test('late_blob_ack_cannot_recreate_purged_cache_metadata', () async {
    final file = await queueBlob();
    final entered = Completer<void>();
    final gate = Completer<void>();
    h.api.onBlob = () {
      entered.complete();
      return gate.future;
    };
    final running = h.engine.runRound();
    await entered.future;
    await h.memberships.reconcile(SpacesDto(spaces: [sampleSpace(epoch: 2)]));
    gate.complete();
    await running;
    expect(await h.store.blobs('s'), isEmpty);
    expect(await h.store.outbox('s'), isEmpty);
    expect(file.existsSync(), isFalse);
  });

  test('upload_busy_retries_after_header_without_failed_state', () async {
    await queueBlob();
    h.api.onBlob = () async =>
        throw const ApiError('upload_busy', status: 503, retryAfter: 3);
    await h.engine.runRound();
    expect((await h.store.outbox('s')).single.state, 'pending');
    h.api.onBlob = null;
    await h.engine.runRound();
    expect(h.api.events.where((e) => e == 'blob'), hasLength(1));
    h.clock = h.clock.add(const Duration(seconds: 3));
    await h.engine.runRound();
    expect(await h.store.outbox('s'), isEmpty);
  });

  test('blocked_dependency_waits_until_all_conflicts_are'
      '_resolved', () async {
    await h.seed('r');
    await h.seed('x');
    for (final id in ['r', 'x']) {
      await h.store.putConflict(
        's',
        'record',
        id,
        sampleRecord(id),
        1,
        'active',
        0,
      );
      await h.store.putEntity(
        's',
        'record',
        sampleRecord(id),
        state: 'conflict',
      );
    }
    await h.store.enqueue(
      const OutboxOperation(
        id: 'dependent',
        spaceId: 's',
        joinEpoch: 1,
        kind: 'tool',
        payload: {
          'tool': 'create_record',
          'args': {'id': 'dependent'},
        },
        entityIds: {'record:dependent'},
        dependsOn: {'record:r', 'record:x'},
        requestId: 'req',
        createdAt: 0,
      ),
    );
    await h.store.setOutboxState('s', 'dependent', 'blocked');
    await h.conflicts.resolveWithServer('s', 'record', 'r');
    expect((await h.store.outbox('s')).single.state, 'blocked');
    await h.conflicts.resolveWithServer('s', 'record', 'x');
    expect((await h.store.outbox('s')).single.state, 'pending');
  });

  test('removed_space_purges_all_business_kinds_and_othe'
      'r_space_survives', () async {
    await h.seed('r');
    final kinds = [
      'space_member',
      'account',
      'allocation_plan',
      'tag',
      'subject',
      'document',
      'entity_event',
      'conversation',
      'chat_entry',
    ];
    for (final kind in kinds) {
      await h.store.putEntity('s', kind, {
        if (kind == 'allocation_plan')
          'account_id': 'a'
        else
          'id': kind == 'entity_event' ? 1 : 'one',
      });
    }
    await h.store.putEntity(
      'other',
      'record',
      sampleRecord('r', spaceId: 'other'),
    );
    await h.memberships.reconcile(const SpacesDto(spaces: []));
    for (final kind in ['space', ...kinds, 'record', 'space_member_grant']) {
      expect(await h.store.entities('s', kind), isEmpty, reason: kind);
    }
    expect(await h.store.entity('other', 'record', 'r'), isNotNull);
  });

  test('module_loss_clears_only_lost_module_and_resets_cursor', () async {
    await h.seed('r');
    await h.records.update('s', 'r', {'amount_minor': 123});
    await h.store.putEntity('s', 'document', {'id': 'doc', 'version': 1});
    await h.store.setCursor('s', 80);
    await h.memberships.reconcile(
      SpacesDto(
        spaces: [
          sampleSpace(modules: const {'ledger': 'none', 'documents': 'write'}),
        ],
      ),
    );
    expect(await h.store.entities('s', 'record'), isEmpty);
    expect(await h.store.outbox('s'), isEmpty);
    expect(await h.store.entity('s', 'document', 'doc'), isNotNull);
    expect(await h.store.cursor('s'), 0);
    expect(
      await h.records.create('s', sampleRecord('new')),
      isA<Failure<String>>(),
    );
  });

  test('module_regain_resets_cursor_and_fences_late_pull', () async {
    await h.seed('r');
    await h.memberships.reconcile(
      SpacesDto(
        spaces: [
          sampleSpace(modules: const {'ledger': 'none', 'documents': 'write'}),
        ],
      ),
    );
    await h.store.setCursor('s', 80);
    final before = await h.store.fence('s');
    // sampleSpace() defaults to write on both modules.
    await h.memberships.reconcile(SpacesDto(spaces: [sampleSpace()]));
    expect(await h.store.cursor('s'), 0);
    expect(await h.store.accepts(before!), isFalse);
  });

  test('unchanged_module_levels_keep_cursor', () async {
    await h.seed('r');
    await h.memberships.reconcile(SpacesDto(spaces: [sampleSpace()]));
    await h.store.setCursor('s', 80);
    await h.memberships.reconcile(SpacesDto(spaces: [sampleSpace()]));
    expect(await h.store.cursor('s'), 80);
  });

  test('old_client_data_layer_refuses_new_outbox_entries', () async {
    await h.seed('r');
    await h.store.setWriteAllowed(allowed: false);
    expect(
      await h.records.update('s', 'r', {'amount_minor': 123}),
      isA<Failure<String>>(),
    );
    expect(await h.store.outbox('s'), isEmpty);
    expect(
      (await h.store.entity('s', 'record', 'r'))?.data['amount_minor'],
      100,
    );
  });

  test('unuploaded_blob_metadata_prevents_reference_upload', () async {
    final file = await File('${h.directory.path}/unuploaded.jpg')
        .writeAsBytes([1]);
    await h.store.putBlob('s', 'ledger', 'hash', file.path, 1);
    await h.records.create(
      's',
      {
        ...sampleRecord('r'),
        'attachments': ['hash'],
      }..remove('version'),
    );
    await h.engine.runRound();
    expect(h.api.batches, isEmpty);
    await h.store.uploadedBlob(
      's',
      'ledger',
      'hash',
      h.clock.millisecondsSinceEpoch,
    );
    await h.engine.runRound();
    expect(h.api.batches, hasLength(1));
  });

  test('local_request_fence_rejects_epoch_change', () async {
    final captured = await h.store.fence('s');
    await h.memberships.reconcile(SpacesDto(spaces: [sampleSpace(epoch: 2)]));
    expect(await h.store.accepts(captured!), isFalse);
  });

  test('money_minor_units_are_positive_integers_before_l'
      'ocal_write', () async {
    expect(
      await h.records.create('s', {...sampleRecord('r'), 'amount_minor': 1.5}),
      isA<Failure<String>>(),
    );
    expect(await h.store.entities('s', 'record'), isEmpty);
    expect(await h.store.outbox('s'), isEmpty);
    await h.seed('r');
    expect(
      await h.records.update('s', 'r', {'amount_minor': 1.5}),
      isA<Failure<String>>(),
    );
    expect(
      (await h.store.entity('s', 'record', 'r'))?.data['amount_minor'],
      100,
    );
  });

  test('local_request_fence_rejects_a_b_a_generation', () async {
    final captured = await h.store.fence('s');
    await h.store.activate(authenticated: false);
    await h.store.activate(authenticated: true);
    expect(await h.store.accepts(captured!), isFalse);
  });

  test('late_spaces_response_does_not_remove_rejoined_space', () async {
    final gate = Completer<SpacesDto>();
    final entered = Completer<void>();
    h.api.onSpaces = () {
      entered.complete();
      return gate.future;
    };
    final running = h.engine.runRound();
    await entered.future;
    await h.memberships.reconcile(SpacesDto(spaces: [sampleSpace(epoch: 2)]));
    await h.store.putEntity('s', 'record', sampleRecord('new'));
    gate.complete(const SpacesDto(spaces: []));
    await running;
    expect((await h.store.entity('s', 'space', 's'))?.data['join_epoch'], 2);
    expect(await h.store.entity('s', 'record', 'new'), isNotNull);
  });
}
