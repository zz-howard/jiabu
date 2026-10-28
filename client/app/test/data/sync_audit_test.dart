import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/api/dto/sync_dto.dart';
import 'package:jiabu/domain/entity_ref.dart';
import 'package:jiabu/domain/outbox_operation.dart';
import 'package:jiabu/domain/sync_state.dart';

import '../support/sync_harness.dart';

class UnreadableFile implements File {
  UnreadableFile(this.delegate);
  final File delegate;

  @override
  String get path => delegate.path;

  @override
  bool existsSync() => delegate.existsSync();

  @override
  Future<Uint8List> readAsBytes() async =>
      throw const FileSystemException('fictional read failure');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
        dependsOn: const {},
        requestId: 'req',
        createdAt: 0,
      ),
    );
    return file;
  }

  test('missing_blob_metadata_blocks_reference_but_not_unrelated', () async {
    await h.records.create('s', {
      ...sampleRecord('dependent'),
      'attachments': ['hash'],
    });
    await h.records.create('s', {
      ...sampleRecord('independent'),
      'account_id': 'other-account',
      'purpose_id': 'other-purpose',
    });
    await h.engine.runRound();
    expect(h.api.batches.single.single.args['id'], 'independent');
    final waiting = (await h.store.outbox('s')).single;
    expect(waiting.entityIds, {'record:dependent'});
    expect(waiting.state, 'pending');
    expect(waiting.attempts, 0);
  });

  test('queued_blob_receipt_survives_retention_until_reference_ack', () async {
    await queueBlob();
    await h.engine.runRound();
    final uploadedAt = h.clock;
    await h.records.create('s', {
      ...sampleRecord('r'),
      'attachments': ['hash'],
    });
    final op = (await h.store.outbox('s')).single;
    await h.store.setOutboxState('s', op.id, 'failed');
    h.clock = uploadedAt.add(const Duration(days: 31));
    await h.cache.expireUploaded(h.clock);
    expect((await h.store.blobs('s')).single['uploaded'], 1);
    await h.mutations.retryFailed('s', op.id);
    await h.engine.runRound();
    expect(h.api.batches.single.single.args['id'], 'r');
    expect(await h.store.outbox('s'), isEmpty);
    expect(await h.store.blobs('s'), isEmpty);
  });

  test('blob_read_failure_releases_lease_and_backs_off', () async {
    final file = await queueBlob();
    await IOOverrides.runZoned(() async {
      await h.engine.runRound();
      final op = (await h.store.outbox('s')).single;
      expect(op.state, 'pending');
      expect(op.leaseUntil, isNull);
      expect(op.lastError?['code'], 'local_blob_unreadable');
      expect(op.retryAt, greaterThan(h.clock.millisecondsSinceEpoch));
      expect(op.attempts, 1);
      await h.engine.runRound();
      expect((await h.store.outbox('s')).single.attempts, 1);
    }, createFile: (_) => UnreadableFile(file));
    h.clock = h.clock.add(const Duration(seconds: 1));
    await h.engine.runRound();
    expect(h.api.events.where((event) => event == 'blob'), hasLength(1));
    expect(await h.store.outbox('s'), isEmpty);
  });

  test('failed_predecessor_waits_for_user_retry', () async {
    await h.seed('r');
    await h.records.update('s', 'r', {'amount_minor': 110});
    final first = (await h.store.outbox('s')).single;
    await h.store.setOutboxState('s', first.id, 'failed');
    await h.records.update('s', 'r', {'amount_minor': 120});
    await h.engine.runRound();
    expect(h.api.batches, isEmpty);
    await h.mutations.retryFailed('s', first.id);
    await h.engine.runRound();
    expect(h.api.batches, hasLength(2));
    expect(h.api.server['r']?['amount_minor'], 120);
  });

  test('retained_server_attachment_needs_no_local_receipt', () async {
    final record = {
      ...sampleRecord('r'),
      'attachments': ['server-hash'],
    };
    await h.store.putEntity('s', 'record', record);
    h.api.server['r'] = record;
    await h.records.update('s', 'r', {
      'amount_minor': 110,
      'attachments': ['server-hash'],
    });
    expect((await h.store.outbox('s')).single.dependsOn, isEmpty);
    await h.engine.runRound();
    expect(await h.store.outbox('s'), isEmpty);
    expect(h.api.server['r']?['attachments'], ['server-hash']);
  });

  test('conflict_retained_server_attachment_needs_no_local_receipt', () async {
    final record = {
      ...sampleRecord('r'),
      'attachments': ['server-hash'],
    };
    await h.store.putEntity('s', 'record', record);
    h.api.server['r'] = record;
    await h.records.update('s', 'r', {'amount_minor': 110});
    await h.store.transaction(() async {
      await h.conflicts.captureConflict('s', 'record', 'r', record);
    });
    await h.conflicts.resolveWithMine('s', 'record', 'r');
    expect((await h.store.outbox('s')).single.dependsOn, isEmpty);
    await h.engine.runRound();
    expect(await h.store.outbox('s'), isEmpty);
    expect(h.api.server['r']?['amount_minor'], 110);
  });

  for (final field in [
    'account_id',
    'to_account_id',
    'purpose_id',
    'to_purpose_id',
    'tag_ids',
  ]) {
    test('record_update_waits_for_new_reference_$field', () async {
      final tag = field == 'tag_ids';
      final kind = tag ? 'tag' : 'account';
      await h.mutations.enqueueTool(
        spaceId: 's',
        tool: 'create_$kind',
        args: const {'id': 'new-reference'},
        entityKind: kind,
        entityId: 'new-reference',
        optimistic: const {'id': 'new-reference', 'version': 0},
      );
      final first = (await h.store.outbox('s')).single;
      await h.store.setOutboxState('s', first.id, 'failed');
      await h.seed('r');
      await h.records.update('s', 'r', {
        field: tag ? ['new-reference'] : 'new-reference',
      });
      await h.engine.runRound();
      expect(h.api.batches, isEmpty);
      await h.mutations.retryFailed('s', first.id);
      await h.engine.runRound();
      expect(h.api.batches, hasLength(2));
      expect(h.api.batches.last.single.tool, 'update_record');
    });
  }

  for (final kind in ['tool', 'blob']) {
    for (final status in [401, 426, 429, 503]) {
      test('${kind}_http_${status}_preserves_operation_for_retry', () async {
        if (kind == 'blob') {
          await queueBlob();
        } else {
          await h.seed('r');
          await h.records.update('s', 'r', {'amount_minor': 110});
        }
        final original = (await h.store.outbox('s')).single;
        final code = switch (status) {
          401 => 'unauthenticated',
          426 => 'client_too_old',
          429 => 'rate_limited',
          _ => 'upload_busy',
        };
        final error = ApiError(code, status: status, retryAfter: 3);
        h.api.onPush = (_) async => throw error;
        h.api.onBlob = () async => throw error;
        await h.engine.runRound();
        final queued = (await h.store.outbox('s')).single;
        expect(queued.id, original.id);
        expect(queued.requestId, original.requestId);
        expect(queued.state, 'pending');
        expect(queued.leaseUntil, isNull);
        if (status == 401) {
          expect(h.engine.status, SyncStatus.loginRequired);
          expect((await h.store.runtime())['authenticated'], 0);
        } else if (status == 426) {
          expect(h.engine.status, SyncStatus.clientTooOld);
          expect((await h.store.runtime())['write_allowed'], 0);
        } else {
          expect(
            queued.retryAt,
            h.clock.add(const Duration(seconds: 3)).millisecondsSinceEpoch,
          );
          await h.engine.runRound();
          expect((await h.store.outbox('s')).single.attempts, 1);
          h.clock = h.clock.add(const Duration(seconds: 3));
          h.api.onPush = null;
          h.api.onBlob = null;
          await h.engine.runRound();
          expect(await h.store.outbox('s'), isEmpty);
        }
      });
    }
  }

  test('pull_checkpoint_cannot_roll_back_chat_sequence', () async {
    await h.store.putEntity('s', 'chat_entry', {
      'id': 'message',
      'rev': 0,
      'last_seq': 20,
      'fallback_text': 'newer fictional text',
    });
    await h.pull.applyPage(
      const PullPageDto(
        spaceId: 's',
        cursor: 1,
        hasMore: false,
        changes: [
          ChangeDto(
            entity: 'chat_entry',
            data: {
              'id': 'message',
              'rev': 0,
              'last_seq': 10,
              'fallback_text': 'older fictional text',
            },
          ),
        ],
      ),
      requestedCursor: 0,
    );
    expect(
      (await h.store.entity('s', 'chat_entry', 'message'))?.data['last_seq'],
      20,
    );
    expect(await h.store.cursor('s'), 1);
  });

  for (final (rev, sequence) in [(0, 20), (0, 21), (1, 10)]) {
    test('pull_chat_accepts_rev_${rev}_sequence_$sequence', () async {
      await h.store.putEntity('s', 'chat_entry', {
        'id': 'message',
        'rev': 0,
        'last_seq': 20,
        'fallback_text': 'fictional local text',
      }, state: 'pending');
      await h.pull.applyPage(
        PullPageDto(
          spaceId: 's',
          cursor: 1,
          hasMore: false,
          changes: [
            ChangeDto(
              entity: 'chat_entry',
              data: {
                'id': 'message',
                'rev': rev,
                'last_seq': sequence,
                'fallback_text': 'fictional server text',
              },
            ),
          ],
        ),
        requestedCursor: 0,
      );
      final row = await h.store.entity('s', 'chat_entry', 'message');
      expect(row?.data['fallback_text'], 'fictional server text');
      expect(row?.data['last_seq'], sequence);
    });
  }
}
