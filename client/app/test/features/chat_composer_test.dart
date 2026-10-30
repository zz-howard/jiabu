import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/chat/chat_action_transport.dart';
import 'package:jiabu/data/chat/chatweave_store.dart';
import 'package:jiabu/features/catalog/c5_cases.dart';
import 'package:jiabu/features/chat/widgets/chat_composer.dart';
import 'package:jiabu/shared/chatweave/jiabu_chatweave_theme.dart';

import '../support/c3_harness.dart';
import '../support/chat_harness.dart';
import '../support/sync_harness.dart';

void main() {
  group('other input widget', () {
    late SyncHarness h;
    late JiabuChatWeaveStore persistence;
    BlockStore? blocks;
    InteractionController? actions;
    InterruptComposerController? composer;

    setUp(() async {
      h = await SyncHarness.create();
      persistence = JiabuChatWeaveStore(
        h.store,
        (await h.store.fence('s'))!,
        'm',
      );
    });
    tearDown(() async {
      final currentComposer = composer;
      final currentActions = actions;
      final currentBlocks = blocks;
      if (currentComposer != null) {
        await currentComposer.dispose();
      }
      if (currentActions != null) {
        await currentActions.dispose();
      }
      if (currentBlocks != null) {
        await currentBlocks.dispose();
      }
      await persistence.dispose();
      await h.close();
    });

    testWidgets('other_input_enqueues_action_without_user_entry', (
      tester,
    ) async {
      blocks = BlockStore()..apply(SyncMessage(c5Message('paused')));
      actions = InteractionController(
        store: blocks!,
        persistence: persistence,
        nextId: () => 'stable-action',
        transport: JiabuActionTransport(h.store, persistence.fence),
      );
      composer = InterruptComposerController(
        store: blocks!,
        interactions: actions!,
        conversationId: 'conversation',
      );
      var regularSends = 0;
      await pumpC3(
        tester,
        settle: false,
        child: JiabuChatWeaveTheme(
          child: JiabuChatComposer(
            composer: composer!,
            draft: '保留的草稿',
            onDraft: (_) {},
            onSend: (_) async {
              regularSends++;
              return true;
            },
            onAttach: () {},
          ),
        ),
      );
      expect(composer!.state.mode, ComposerMode.locked);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('chat-input')))
            .enabled,
        false,
      );
      composer!.beginOtherInput();
      await tester.pump();
      expect(find.textContaining('回答：'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('chat-input')))
            .enabled,
        true,
      );
      composer!.cancelOtherInput();
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('chat-input')))
            .controller!
            .text,
        '保留的草稿',
      );
      composer!.beginOtherInput();
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('chat-input')), '用信用卡');
      await tester.tap(find.byKey(const ValueKey('chat-send')));
      await pumpUntil(
        tester,
        () =>
            actions!.stateFor('reply', 'card').phase == InteractionPhase.queued,
        description: 'other-input action reaches the queued state',
      );
      final queue = (await tester.runAsync(() => h.store.outbox('s')))!;
      expect(queue, hasLength(1));
      expect(queue.single.kind, 'chat_action');
      expect(queue.single.payload['payload'], {'freeText': '用信用卡'});
      expect(
        await tester.runAsync(() => h.store.entities('s', 'chat_entry')),
        isEmpty,
      );
      expect(regularSends, 0);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
  group('round send/stop button', () {
    late BlockStore store;
    late InteractionController actions;
    late InterruptComposerController composer;
    setUp(() {
      store = BlockStore();
      actions = InteractionController(
        store: store,
        persistence: CatalogChatStore(),
        nextId: () => 'action',
        transport: CatalogQueuedAction(),
      );
      composer = InterruptComposerController(
        store: store,
        interactions: actions,
        conversationId: 'conversation',
      );
    });
    tearDown(() async {
      await composer.dispose();
      await actions.dispose();
      await store.dispose();
    });
    Future<void> pumpComposer(
      WidgetTester tester, {
      bool stopActive = false,
      bool stopRequested = false,
      int photos = 0,
      void Function(String)? onSent,
      VoidCallback? onStop,
    }) => pumpC3(
      tester,
      settle: false,
      child: JiabuChatWeaveTheme(
        child: JiabuChatComposer(
          composer: composer,
          draft: '',
          onDraft: (_) {},
          onSend: (text) async {
            onSent?.call(text);
            return true;
          },
          onAttach: () {},
          photoCount: photos,
          stopActive: stopActive,
          stopRequested: stopRequested,
          onStop: onStop ?? () {},
        ),
      ),
    );
    testWidgets('empty_field_send_is_disabled_and_typing_enables_it', (
      tester,
    ) async {
      final sent = <String>[];
      await pumpComposer(tester, onSent: sent.add);
      final send = find.byKey(const ValueKey('chat-send'));
      expect(send, findsOneWidget);
      expect(tester.getSize(send), const Size(48, 48));
      await tester.tap(send);
      await tester.pump();
      expect(sent, isEmpty);
      await tester.enterText(find.byKey(const ValueKey('chat-input')), '午饭 68');
      await tester.pump();
      await tester.tap(send);
      await tester.pump();
      expect(sent, ['午饭 68']);
      // Same row as the field; attach actions are at least 48 dp.
      final row = tester
          .getRect(find.byKey(const ValueKey('chat-input')))
          .center
          .dy;
      expect((tester.getCenter(send).dy - row).abs() < 30, isTrue);
      expect(find.text('发送'), findsNothing);
    });
    testWidgets('processing_turns_send_into_stop_and_typing_flips_back', (
      tester,
    ) async {
      var stops = 0;
      await pumpComposer(tester, stopActive: true, onStop: () => stops++);
      expect(find.byKey(const ValueKey('chat-send')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('chat-stop')));
      expect(stops, 1);
      await tester.enterText(find.byKey(const ValueKey('chat-input')), '再记一笔');
      await tester.pump();
      expect(find.byKey(const ValueKey('chat-stop')), findsNothing);
      expect(find.byKey(const ValueKey('chat-send')), findsOneWidget);
    });
    testWidgets('stop_is_inert_while_stopping', (tester) async {
      var stops = 0;
      await pumpComposer(
        tester,
        stopActive: true,
        stopRequested: true,
        onStop: () => stops++,
      );
      await tester.tap(find.byKey(const ValueKey('chat-stop')));
      expect(stops, 0);
    });
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
    )..beginOtherInput();
    store.apply(SyncMessage(c5Message('choice_resolved')));
    expect(composer.state.mode, ComposerMode.free);
    expect(composer.state.closedReason, 'answered_elsewhere');
    await composer.dispose();
    await actions.dispose();
    await store.dispose();
  });
}
