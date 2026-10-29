import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/app/chat_providers.dart';
import 'package:jiabu/app/ledger_providers.dart';
import 'package:jiabu/features/catalog/c3_cases.dart';
import 'package:jiabu/features/catalog/c5_cases.dart';
import 'package:jiabu/features/chat/view/chat_screen.dart';
import 'package:jiabu/shared/chatweave/jiabu_chat_registry.dart';
import 'package:jiabu/shared/chatweave/jiabu_chatweave_theme.dart';
import 'package:jiabu/shared/chatweave/jiabu_message_view.dart';
import 'package:jiabu/shared/ledger/ledger_forms.dart';

import '../support/c3_harness.dart';
import '../support/chat_harness.dart';
import '../support/ledger_fake.dart';

void main() {
  testWidgets('ai_unavailable_exposes_manual_form_entry', (tester) async {
    final h = await ChatHarness.create();
    final ledger = FakeLedgerRepository(c3Snapshot('card_recorded'));
    h.session.blocks.apply(SyncMessage(chatMessage()));
    h.session.blocks.apply(
      ApplyStream(
        StreamEvent.fromJson({
          'protocolVersion': '0.1',
          'messageId': 'reply',
          'type': 'message.activity',
          'activity': {'phase': 'degraded'},
        }),
      ),
    );
    await pumpC3(
      tester,
      repository: ledger,
      sessionSpaceId: 's',
      child: ProviderScope(
        overrides: [
          chatRepositoryProvider.overrideWithValue(
            FixedChatRepository(h.session),
          ),
          currentLedgerSpaceProvider.overrideWith((ref) => Stream.value('s')),
        ],
        child: const ChatScreen(),
      ),
    );
    await pumpDatabaseFrames(tester);
    expect(find.text('AI 暂时不可用'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '手动记一笔'));
    await tester.pumpAndSettle();
    expect(find.byType(RecordForm), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await ledger.changes.close();
    await h.close();
  });
  for (final state in [
    'user_pending',
    'user_failed',
    'user_waiting_ai',
    'user_manual_takeover',
  ]) {
    testWidgets('${state}_keeps_original_and_manual_entry', (tester) async {
      await pumpC3(tester, child: C5Preview(state: state));
      expect(find.text('午饭 68，信用卡，日常餐饮'), findsOneWidget);
      expect(find.text('改为手动填写'), findsOneWidget);
      if (state == 'user_failed') expect(find.text('重试'), findsOneWidget);
    });
  }
  testWidgets('record_card_reference_changed_and_syncing', (tester) async {
    await pumpC3(tester, child: const C5Preview(state: 'record_changed'));
    expect(find.text('后来改过'), findsOneWidget);
    await pumpC3(
      tester,
      child: const C5Preview(key: ValueKey('syncing'), state: 'record_syncing'),
    );
    expect(find.text('记录同步中'), findsOneWidget);
  });
  testWidgets('unknown_jiabu_block_falls_back_without_document_registration', (
    tester,
  ) async {
    await pumpC3(tester, child: const C5Preview(state: 'unknown_fallback'));
    expect(find.textContaining('用户A的示例记录'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('choice_answer_is_not_selected_until_authoritative_state', (
    tester,
  ) async {
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
    final registry = jiabuChatRegistry(
      recordBuilder: (_, _) => const SizedBox(),
    );
    Widget content() => JiabuChatWeaveTheme(
      child: JiabuMessageView(
        source: MessageView(
          message: store.snapshot.messages['reply']!,
          registry: registry,
          processState: ProcessState(),
          interactions: actions,
          composer: composer,
        ),
      ),
    );
    await pumpC3(tester, child: content());
    await tester.tap(find.text('信用卡'));
    await tester.pumpAndSettle();
    expect(find.text('已排队，联网后提交'), findsOneWidget);
    expect(store.snapshot.messages['reply']!.blocks.single.data['state'], {
      'status': 'open',
    });
    store.apply(SyncMessage(c5Message('choice_resolved')));
    await pumpC3(tester, child: content());
    expect(find.textContaining('你的回答：信用卡'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await composer.dispose();
    await actions.dispose();
    await store.dispose();
  });
}
