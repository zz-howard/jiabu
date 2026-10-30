import 'package:chatweave_core/chatweave_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/domain/chat.dart';
import 'package:jiabu/domain/result.dart';

import '../support/chat_harness.dart';

void main() {
  late ChatHarness h;
  setUp(() async {
    h = await ChatHarness.create();
  });
  tearDown(() async {
    await h.close();
  });
  test('degraded_machine_state_controls_ai_unavailable', () {
    h.session.blocks.apply(SyncMessage(chatMessage()));
    expect(h.session.aiUnavailable, false);
    h.session.blocks.apply(
      ApplyStream(
        StreamEvent.fromJson({
          'protocolVersion': '0.1',
          'type': 'message.activity',
          'messageId': 'reply',
          'activity': {'phase': 'degraded'},
        }),
      ),
    );
    expect(h.session.aiUnavailable, true);
  });
  test('uploaded_message_cannot_switch_to_manual_while_offline', () async {
    await h.h.store.updateChatClientState(
      's',
      'user',
      (_) => {'assistantId': 'reply'},
    );
    final result = await h.session.takeOver('user');
    expect(
      result,
      isA<Failure<Map<String, Object?>>>().having(
        (failure) => failure.code,
        'code',
        'chat_online_required',
      ),
    );
    expect(h.api.writes, isEmpty);
    expect((await h.h.store.chatClientState('s', 'user'))['manual'], isNull);
  });
  test('manual_form_cancel_does_not_restore_ai_and_can_reopen', () async {
    expect(await h.session.send('午饭 68', []), isA<Ok<void>>());
    final user = (await h.h.store.outbox('s')).single.id;
    expect(await h.session.takeOver(user), isA<Ok<Map<String, Object?>>>());
    final again = await h.session.takeOver(user);
    expect((again as Ok<Map<String, Object?>>).value, isEmpty);
    expect(await h.h.store.outbox('s'), isEmpty);
    expect(await h.h.store.entity('s', 'chat_entry', user), isNotNull);
  });
  test(
    'answered_message_is_complete_even_before_reply_link_is_pulled',
    () async {
      // The streamed reply message has no replyTo; the link only exists in the
      // send response (assistantId) until the next pull writes reply_to_id.
      await h.h.store.putChatEntry('s', {
        'id': 'user',
        'member_id': 'm',
        'conversation_id': 'conversation',
        'role': 'user',
        'created_at': '2026-10-29T12:00:00Z',
        'message_json': {
          'protocolVersion': '0.1',
          'id': 'user',
          'conversationId': 'conversation',
          'role': 'user',
          'status': 'complete',
          'rev': 1,
          'createdAt': '2026-10-29T12:00:00Z',
          'fallbackText': '哈喽',
          'blocks': <Object?>[],
          'metadata': {
            'input': {'text': '哈喽', 'images': <String>[]},
          },
        },
        'fallback_text': '哈喽',
        'stream_status': 'complete',
        'rev': 1,
      }, authoritative: true);
      await h.h.store.updateChatClientState(
        's',
        'user',
        (_) => {'assistantId': 'reply'},
      );
      await h.persistence.saveFinal(
        chatMessage(status: 'complete', rev: 1, seq: 3, text: '哈喽！'),
      );
      await h.session.sync();
      for (var i = 0; i < 50 && h.session.delivery['user'] == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(h.session.delivery['user'], ChatDelivery.complete);
      final row = await h.h.store.chatEntry('s', 'reply');
      expect(row?['reply_to_id'], isNull);
    },
  );
  test('reply_to_id_survives_a_later_streamed_checkpoint', () async {
    await h.h.store.putChatEntry('s', {
      ...chatRow(chatMessage(status: 'complete', rev: 1, seq: 3)),
      'reply_to_id': 'user',
    }, authoritative: false);
    await h.persistence.saveFinal(
      chatMessage(status: 'complete', rev: 1, seq: 4, text: '哈喽！'),
    );
    expect((await h.h.store.chatEntry('s', 'reply'))?['reply_to_id'], 'user');
  });
  test('stop_offline_and_leaving_page_never_enqueue_stop', () async {
    final result = await h.session.stop('reply');
    expect(result, isA<Failure<void>>());
    await h.session.disconnect();
    expect(h.api.writes, isEmpty);
    expect(await h.h.store.outbox('s'), isEmpty);
  });
  test('send_and_user_entry_rollback_together', () async {
    await expectLater(
      h.h.store.transaction(() async {
        expect(await h.session.send('用户A', []), isA<Ok<void>>());
        throw StateError('synthetic_rollback');
      }),
      throwsStateError,
    );
    expect(await h.h.store.outbox('s'), isEmpty);
    expect(await h.h.store.entities('s', 'chat_entry'), isEmpty);
  });
}
