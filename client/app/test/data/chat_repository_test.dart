import 'package:chatweave_core/chatweave_core.dart';
import 'package:flutter_test/flutter_test.dart';
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
