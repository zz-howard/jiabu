import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/features/catalog/c5_cases.dart';
import 'package:jiabu/shared/chatweave/chat_block_revealer.dart';
import 'package:jiabu/shared/chatweave/jiabu_chat_registry.dart';
import 'package:jiabu/shared/chatweave/jiabu_chatweave_theme.dart';
import 'package:jiabu/shared/chatweave/jiabu_message_view.dart';
import 'package:jiabu/shared/chatweave/jiabu_process_strip.dart';
import 'package:jiabu_design/jiabu_design.dart';

import '../support/c3_harness.dart';

void main() {
  testWidgets('localized process seconds use complete Sans coverage', (
    tester,
  ) async {
    final message = c5Message('process_failed');
    final process = ProcessState()..setExpanded(message.id, true);
    await pumpC3(
      tester,
      child: JiabuProcessStrip(message: message, state: process),
    );
    final seconds = tester.widget<Text>(find.textContaining('0.8 秒'));
    expect(seconds.style?.fontFamily, JiabuType.systemSansFamily);
  });

  testWidgets('component_fill_preserves_text_top_left_jiabu', (tester) async {
    final registry = jiabuChatRegistry(
      recordBuilder: (_, _) => const SizedBox(),
    );
    Message message({required bool ready}) => Message.fromJson({
      'protocolVersion': '0.1',
      'id': 'reply',
      'role': 'assistant',
      'status': 'streaming',
      'rev': 0,
      'createdAt': '2026-10-29T12:00:00Z',
      'conversationId': 'conversation',
      'fallbackText': '上方文字',
      'blocks': [
        c5Block('markdown', id: 'text'),
        {
          ...c5Block('metric'),
          'status': ready ? 'complete' : 'pending',
          if (!ready) 'data': <String, Object?>{},
        },
      ],
    });
    final process = ProcessState();
    Widget frame({required bool ready}) => JiabuChatWeaveTheme(
      child: JiabuMessageView(
        source: MessageView(
          message: message(ready: ready),
          registry: registry,
          processState: process,
        ),
      ),
    );
    await pumpC3(tester, child: frame(ready: false));
    final before = tester.getTopLeft(find.byKey(const ValueKey('text')));
    await pumpC3(tester, child: frame(ready: true));
    expect(tester.getTopLeft(find.byKey(const ValueKey('text'))), before);
    expect(tester.takeException(), isNull);
  });
  testWidgets('process_growth_and_manual_collapse_'
      'preserve_scroll_anchor_jiabu', (tester) async {
    final store = BlockStore();
    final registry = jiabuChatRegistry(
      recordBuilder: (_, _) => const SizedBox(),
    );
    String seconds(String id) =>
        id == 'target' ? '10' : id.substring(1).padLeft(2, '0');
    Message row(String id, {int steps = 0}) => Message.fromJson({
      'protocolVersion': '0.1',
      'id': id,
      'conversationId': 'conversation',
      'role': 'assistant',
      'status': 'streaming',
      'rev': 0,
      'createdAt': '2026-10-29T12:00:${seconds(id)}Z',
      'fallbackText': id,
      'blocks': [
        {
          ...c5Block('markdown'),
          'id': 'text-$id',
          'data': {'text': id == 'target' ? '锚点记录' : '$id\n' * 3},
        },
      ],
      'steps': [
        for (var i = 0; i < steps; i++)
          {'id': 's$i', 'label': '查询 $i', 'state': 'succeeded'},
      ],
    });
    for (var i = 0; i < 20; i++) {
      store.apply(SyncMessage(i == 10 ? row('target', steps: 1) : row('m$i')));
    }
    await pumpC3(
      tester,
      child: JiabuChatWeaveTheme(
        child: ChatWeaveList(
          store: store,
          registry: registry,
          conversationId: 'conversation',
          messageFrameBuilder: (context, message, child) =>
              child is MessageView ? JiabuMessageView(source: child) : child,
        ),
      ),
    );
    final text = find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText() == '锚点记录',
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 200));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      text,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(text);
    store.apply(SyncMessage(row('target', steps: 3)));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(tester.getTopLeft(text).dy, closeTo(before.dy, .5));
    final strip = find.ancestor(
      of: text,
      matching: find.byType(JiabuMessageView),
    );
    final toggle = find
        .descendant(of: strip, matching: find.byType(TextButton))
        .first;
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    final controlBefore = tester.getTopLeft(toggle);
    await tester.tap(toggle);
    await tester.pump();
    await tester.pump();
    expect(tester.getTopLeft(toggle).dy, closeTo(controlBefore.dy, .5));
    expect(find.byType(JiabuProcessStrip), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await store.dispose();
  });
  testWidgets('locked_composer_reveals_recycled_interrupt', (tester) async {
    final store = BlockStore();
    final revealer = ChatBlockRevealer();
    final registry = jiabuChatRegistry(
      recordBuilder: (_, _) => const SizedBox(),
    );
    store.apply(
      SyncMessage(
        Message.fromJson({
          ...c5Message('paused').json,
          'id': 'target',
          'createdAt': '2026-10-29T12:00:00Z',
        }),
      ),
    );
    for (var i = 1; i <= 20; i++) {
      store.apply(
        SyncMessage(
          Message.fromJson({
            ...c5Message('streaming').json,
            'id': 'm$i',
            'createdAt': '2026-10-29T12:00:${i.toString().padLeft(2, '0')}Z',
            'steps': <Object?>[],
            'blocks': [
              {
                ...c5Block('markdown'),
                'data': {'text': '用户A记录 $i\n' * 5},
              },
            ],
          }),
        ),
      );
    }
    await pumpC3(
      tester,
      child: JiabuChatWeaveTheme(
        child: ChatWeaveList(
          store: store,
          registry: registry,
          conversationId: 'conversation',
          messageFrameBuilder: (context, message, child) {
            if (child is! MessageView) return child;
            revealer.register(context, child);
            return JiabuMessageView(source: child);
          },
        ),
      ),
    );
    var completed = false;
    final flight = revealer.reveal('target', 'card').then((_) {
      completed = true;
    });
    for (var i = 0; i < 100 && !completed; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(completed, true);
    await flight;
    // The reveal jumps the scroll; the list lays out on the next frame.
    await tester.pump();
    expect(find.text('用哪张卡付的？'), findsOneWidget);
    expect(tester.getRect(find.text('用哪张卡付的？')).top, greaterThanOrEqualTo(0));
    revealer.dispose();
    await tester.pumpWidget(const SizedBox());
    await store.dispose();
  });

  testWidgets('structured_blocks_are_332_wide_and_horizontal', (tester) async {
    for (final state in [
      'metric',
      'metric_group',
      'dataset',
      'time_series',
      // choice: the question and its pills sit on the page, not on a card
      // (V5, see v5_chat_restore_test).
      'confirmation',
      'form_intent',
    ]) {
      await pumpC3(
        tester,
        child: C5Preview(key: ValueKey(state), state: state),
      );
      final paper = find.byType(PaperCard).first;
      expect(tester.getSize(paper).width, closeTo(332, .5), reason: state);
      expect(
        find.descendant(of: paper, matching: find.byType(Tilt)),
        findsNothing,
        reason: state,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
