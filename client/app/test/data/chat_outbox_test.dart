import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/chat/chat_action_transport.dart';
import 'package:jiabu/domain/result.dart';

import '../support/chat_harness.dart';

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
