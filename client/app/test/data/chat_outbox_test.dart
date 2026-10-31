import 'dart:io';

import 'package:chatweave_core/chatweave_core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/chat/chat_action_transport.dart';
import 'package:jiabu/data/chat/chat_capabilities.dart';
import 'package:jiabu/data/db/database.dart';
import 'package:jiabu/data/sync/outbox_processor.dart';
import 'package:jiabu/domain/outbox_operation.dart';
import 'package:jiabu/domain/result.dart';

import '../support/chat_harness.dart';
import '../support/sync_harness.dart';

void main() {
  late ChatHarness h;
  setUp(() async {
    h = await ChatHarness.create(offline: false);
  });
  tearDown(() async {
    await h.close();
  });
  for (final kind in ['chat_send', 'chat_action', 'chat_retry']) {
    test('${kind}_uploads_and_saves_result_before_ack', () async {
      await h.enqueue(kind, 'op');
      await h.processor.drain(await h.owner());
      expect(h.api.writes, hasLength(1));
      expect(h.api.writes.single.capabilities, isNull);
      expect(await h.h.store.outbox('s'), isEmpty);
      final state = await h.h.store.chatClientState(
        's',
        kind == 'chat_send'
            ? 'op'
            : kind == 'chat_action'
            ? 'reply'
            : 'user',
      );
      expect(state, isNotEmpty);
    });
    test('${kind}_permanent_failure_is_retained', () async {
      h.api.failure = const ApiError('invalid', status: 422);
      await h.enqueue(kind, 'op');
      await h.processor.drain(await h.owner());
      expect((await h.h.store.outbox('s')).single.state, 'failed');
    });
    test('${kind}_late_ack_cannot_cross_fence', () async {
      await h.enqueue(kind, 'op');
      h.api.beforeReply = () async {
        await h.h.store.activate(authenticated: true);
      };
      await h.processor.drain(await h.owner());
      expect(await h.h.store.outbox('s'), hasLength(1));
    });
  }
  test('epoch_change_before_dispatch_sends_no_request', () async {
    await h.enqueue('chat_send', 'op');
    final owner = await h.owner();
    final leased = await h.processor.selectAndLeaseBatch(owner);
    final space = (await h.h.store.entity('s', 'space', 's'))!;
    await h.h.store.putEntity('s', 'space', {...space.data, 'join_epoch': 2});
    await h.processor.uploadLeasedChat(owner, leased.single);
    expect(h.api.writes, isEmpty);
  });
  test('offline_action_replays_identical_id_and_payload', () async {
    final transport = JiabuActionTransport(
      h.h.store,
      (await h.h.store.fence('s'))!,
    );
    final request = h.action('stable-action');
    await transport.submit(request);
    h.api.failure = const ApiError('network');
    final owner = await h.owner();
    await h.processor.drain(owner);
    final original = (await h.h.store.outbox('s')).single;
    await transport.submit(request);
    expect(await h.h.store.outbox('s'), hasLength(1));
    expect((await h.h.store.outbox('s')).single.payload, original.payload);
    await h.h.store.setOutboxState('s', original.id, 'pending');
    h.api.failure = null;
    await h.processor.drain(owner);
    final receipt = await transport.submit(request);
    expect(receipt.queued, isFalse);
    expect(h.api.writes.map((write) => write.id), [
      'stable-action',
      'stable-action',
    ]);
    expect(h.api.writes.first.payload, h.api.writes.last.payload);
  });
  test('chat_send_waits_for_blob_receipt', () async {
    await h.h.store.putBlob('s', 'chat', 'hash', '/fictional/missing', 3);
    await h.enqueue('chat_send', 'op', depends: {'blob:chat:hash'});
    final owner = await h.owner();
    await h.processor.drain(owner);
    expect(h.api.writes, isEmpty);
    await h.h.store.uploadedBlob('s', 'chat', 'hash', 1);
    await h.processor.drain(owner);
    expect(h.api.writes, hasLength(1));
  });
  test('send_freezes_capabilities_in_outbox_and_strips_the_envelope', () async {
    final expected = chatCapabilitiesHeader(h.session.caps);
    expect(await h.session.send('用户A', const []), isA<Ok<void>>());
    final stored = (await h.h.store.outbox('s')).single;
    expect(stored.payload[chatCapabilitiesEnvelopeKey], expected);

    await h.processor.drain(await h.owner());

    final write = h.api.writes.single;
    expect(write.capabilities, expected);
    expect(write.payload, {
      'id': stored.id,
      'text': '用户A',
      'images': <String>[],
    });
    expect(write.payload, isNot(contains(chatCapabilitiesEnvelopeKey)));
  });
  test('retry_freezes_capabilities_and_sends_an_empty_json_body', () async {
    h.session.blocks.apply(
      SyncMessage(chatMessage(status: 'interrupted', rev: 1, seq: 1)),
    );
    final expected = chatCapabilitiesHeader(h.session.caps);
    expect(await h.session.retry('reply'), isA<Ok<void>>());
    final stored = (await h.h.store.outbox('s')).single;
    expect(stored.kind, 'chat_retry');
    expect(stored.payload[chatCapabilitiesEnvelopeKey], expected);

    await h.processor.drain(await h.owner());

    final write = h.api.writes.single;
    expect(write.endpoint, 'messages/reply/retry');
    expect(write.capabilities, expected);
    expect(write.payload, isEmpty);
  });
  test('durable_snapshot_is_not_recomputed_before_later_upload', () async {
    const frozen = 'v=0.1; blocks=markdown:1; features=stream.resume';
    await h.h.store.enqueue(
      OutboxOperation(
        id: 'offline-message',
        spaceId: 's',
        joinEpoch: 1,
        kind: 'chat_send',
        payload: {
          'id': 'offline-message',
          'text': '用户A',
          'images': <String>[],
          chatCapabilitiesEnvelopeKey: frozen,
        },
        entityIds: const {'chat_entry:offline-message'},
        dependsOn: const {},
        requestId: 'offline-request',
        createdAt: h.h.clock.microsecondsSinceEpoch,
      ),
    );
    // Reading from SQLite reconstructs the operation as it would after restart.
    final reloaded = (await h.h.store.outbox('s')).single;
    expect(reloaded.payload[chatCapabilitiesEnvelopeKey], frozen);

    await h.processor.drain(await h.owner());

    expect(h.api.writes.single.capabilities, frozen);
    expect(
      h.api.writes.single.payload,
      isNot(contains(chatCapabilitiesEnvelopeKey)),
    );
  });
  test('durable_snapshot_survives_a_real_database_close_and_reopen', () async {
    final directory = await Directory.systemTemp.createTemp(
      'jiabu-chat-capabilities-',
    );
    final file = File('${directory.path}/client.sqlite');
    const frozen = 'v=0.1; blocks=markdown:1; features=stream.resume';
    final first = await SyncHarness.create(
      database: JiabuDatabase(NativeDatabase(file)),
      directory: directory,
    );
    await first.store.enqueue(
      OutboxOperation(
        id: 'offline-message',
        spaceId: 's',
        joinEpoch: 1,
        kind: 'chat_send',
        payload: const {
          'id': 'offline-message',
          'text': '用户A',
          'images': <String>[],
          chatCapabilitiesEnvelopeKey: frozen,
        },
        entityIds: const {'chat_entry:offline-message'},
        dependsOn: const {},
        requestId: 'offline-request',
        createdAt: first.clock.microsecondsSinceEpoch,
      ),
    );
    await first.db.close();

    SyncHarness? reopened;
    try {
      reopened = await SyncHarness.create(
        database: JiabuDatabase(NativeDatabase(file)),
        directory: directory,
      );
      final api = FakeChatApi()..offline = false;
      final processor = OutboxProcessor(
        reopened.store,
        reopened.api,
        reopened.conflicts,
        chatApi: api,
        now: () => reopened!.clock,
      );
      const owner = 'restart-round';
      await reopened.store.acquireRound(
        owner,
        reopened.clock.millisecondsSinceEpoch,
        reopened.clock.add(const Duration(minutes: 12)).millisecondsSinceEpoch,
      );
      await processor.drain(owner);

      expect(api.writes.single.capabilities, frozen);
      expect(api.writes.single.id, 'offline-message');
      expect(api.writes.single.requestId, 'offline-request');
      expect(
        api.writes.single.payload,
        isNot(contains(chatCapabilitiesEnvelopeKey)),
      );
    } finally {
      if (reopened != null) {
        await reopened.close();
      } else if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    }
  });
  test('failed_upload_keeps_the_frozen_snapshot_for_retry', () async {
    final expected = chatCapabilitiesHeader(h.session.caps);
    expect(await h.session.send('用户A', const []), isA<Ok<void>>());
    h.api.failure = const ApiError('network');

    await h.processor.drain(await h.owner());

    expect(h.api.writes.single.capabilities, expected);
    final retained = (await h.h.store.outbox('s')).single;
    expect(retained.state, 'pending');
    expect(retained.payload[chatCapabilitiesEnvelopeKey], expected);

    h.api.failure = null;
    h.h.clock = h.h.clock.add(const Duration(minutes: 1));
    await h.processor.drain(await h.owner());

    expect(h.api.writes, hasLength(2));
    expect(h.api.writes.map((write) => write.capabilities), [
      expected,
      expected,
    ]);
    expect(h.api.writes.map((write) => write.id).toSet(), {retained.id});
    expect(h.api.writes.map((write) => write.requestId).toSet(), {
      retained.requestId,
    });
    for (final write in h.api.writes) {
      expect(write.payload, isNot(contains(chatCapabilitiesEnvelopeKey)));
    }
  });
  test('chat_results_are_per_item_and_same_entity_is_serialized', () async {
    await h.enqueue('chat_send', 'one');
    await h.enqueue('chat_action', 'two');
    h.api.beforeReply = () async {
      if (h.api.writes.length == 2) {
        throw const ApiError('invalid', status: 422);
      }
    };
    await h.processor.drain(await h.owner());
    final remaining = await h.h.store.outbox('s');
    expect(remaining.single.id, 'two');
    expect(remaining.single.state, 'failed');
  });
  test('manual_takeover_prevents_later_ai_duplicate', () async {
    expect(await h.session.send('午饭 68', const []), isA<Ok<void>>());
    final id = (await h.h.store.outbox('s')).single.id;
    expect(await h.session.takeOver(id), isA<Ok<Map<String, Object?>>>());
    await h.processor.drain(await h.owner());
    expect(h.api.writes, isEmpty);
    expect((await h.h.store.chatClientState('s', id))['manual'], true);
  });
}
