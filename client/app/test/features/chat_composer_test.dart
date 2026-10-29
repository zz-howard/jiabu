import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/chat/chat_action_transport.dart';
import 'package:jiabu/features/catalog/c5_cases.dart';
import 'package:jiabu/features/chat/widgets/chat_composer.dart';
import 'package:jiabu/shared/chatweave/jiabu_chatweave_theme.dart';

import '../support/c3_harness.dart';
import '../support/chat_harness.dart';

void main() {
  testWidgets('other_input_enqueues_action_without_user_entry', (tester) async {
    final h = await ChatHarness.create();
    final blocks = BlockStore()..apply(SyncMessage(c5Message('paused')));
    final actions = InteractionController(
      store: blocks,
      persistence: h.persistence,
      nextId: () => 'stable-action',
      transport: JiabuActionTransport(h.h.store, (await h.h.store.fence('s'))!),
    );
    final composer = InterruptComposerController(
      store: blocks,
      interactions: actions,
      conversationId: 'conversation',
    );
    addTearDown(() async {
      await composer.dispose();
      await actions.dispose();
      await blocks.dispose();
      await h.close();
    });
    var regularSends = 0;
    await pumpC3(
      tester,
      child: JiabuChatWeaveTheme(
        child: JiabuChatComposer(
          composer: composer,
          draft: '保留的草稿',
          onDraft: (_) {},
          onSend: (_) async {
            regularSends++;
            return true;
          },
          onPhoto: () {},
          onGallery: () {},
        ),
      ),
    );
    expect(composer.state.mode, ComposerMode.locked);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('chat-input')))
          .enabled,
      false,
    );
    composer.beginOtherInput();
    await tester.pump();
    expect(find.textContaining('回答：'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('chat-input')))
          .enabled,
      true,
    );
    composer.cancelOtherInput();
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('chat-input')))
          .controller!
          .text,
      '保留的草稿',
    );
    composer.beginOtherInput();
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('chat-input')), '用信用卡');
    await tester.tap(find.text('发送'));
    await pumpDatabaseFrames(tester);
    final queue = await h.h.store.outbox('s');
    expect(queue, hasLength(1));
    expect(queue.single.kind, 'chat_action');
    expect(queue.single.payload['payload'], {'freeText': '用信用卡'});
    expect(await h.h.store.entities('s', 'chat_entry'), isEmpty);
    expect(regularSends, 0);
  });
  test('queued_action_keeps_authoritative_block_open', () async {
    final h = await ChatHarness.create();
    final blocks = BlockStore()..apply(SyncMessage(c5Message('paused')));
    final actions = InteractionController(
      store: blocks,
      persistence: h.persistence,
      nextId: () => 'stable-action',
      transport: JiabuActionTransport(h.h.store, (await h.h.store.fence('s'))!),
    );
    await actions.submit('reply', 'card', {
      'selected': ['credit'],
    });
    expect(blocks.snapshot.messages['reply']!.blocks.single.data['state'], {
      'status': 'open',
    });
    expect(actions.stateFor('reply', 'card').phase, InteractionPhase.queued);
    await actions.dispose();
    await blocks.dispose();
    await h.close();
  });
  test('composer_reconciles_other_device_close_and_preserves_draft', () async {
    final store = BlockStore()..apply(SyncMessage(c5Message('paused')));
    final actions = InteractionController(
      store: store,
      persistence: CatalogChatStore(),
      nextId: () => 'action',
      transport: CatalogQueuedAction(),
    );
    final composer = InterruptComposerController(
      store: store,
      interactions: actions,
      conversationId: 'conversation',
    );
    composer.beginOtherInput();
    store.apply(SyncMessage(c5Message('choice_resolved')));
    expect(composer.state.mode, ComposerMode.free);
    expect(composer.state.closedReason, 'answered_elsewhere');
    await composer.dispose();
    await actions.dispose();
    await store.dispose();
  });
}
