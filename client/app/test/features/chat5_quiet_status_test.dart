import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/domain/chat.dart';
import 'package:jiabu/features/catalog/c5_cases.dart';
import 'package:jiabu/shared/chatweave/user_message_note.dart';
import 'package:jiabu_design/jiabu_design.dart';

import '../support/c3_harness.dart';

/// chat5: under my sticky note only abnormal states say anything; copy /
/// retry / manual entry live in the note's long-press menu.

Message _message() => Message.fromJson({
  'id': 'user',
  'role': 'user',
  'rev': 1,
  'status': 'complete',
  'conversationId': 'conversation',
  'createdAt': '2026-10-29T15:14:00Z',
  'blocks': <Object?>[],
  'fallbackText': '午饭 68',
  'metadata': {
    'input': {'text': '午饭 68', 'images': <String>[]},
  },
});

Future<void> _pump(
  WidgetTester tester,
  ChatDelivery delivery, {
  bool online = true,
  VoidCallback? onRetry,
  VoidCallback? onManual,
  String locale = 'zh',
}) => pumpC3(
  tester,
  locale: locale,
  child: Align(
    alignment: Alignment.topRight,
    child: SizedBox(
      width: 360,
      child: UserMessageNote(
        message: _message(),
        delivery: delivery,
        online: online,
        onRetry: onRetry,
        onManual: onManual,
      ),
    ),
  ),
);

const _oldStatus = [
  '待上传',
  '待 AI 处理',
  '上传失败，可重试',
  '已改为手动填写',
  '改为手动填写',
  '已排队',
  '提交中',
];

Finder _menuItem(String label) => find.descendant(
  of: find.byKey(const Key('chat-note-menu')),
  matching: find.text(label),
);

Future<void> _longPress(WidgetTester tester) async {
  await tester.longPress(find.text('午饭 68'));
  await tester.pumpAndSettle();
}

void main() {
  group('quiet status', () {
    for (final delivery in [
      ChatDelivery.pending,
      ChatDelivery.waitingAi,
      ChatDelivery.complete,
      ChatDelivery.manual,
    ]) {
      testWidgets('normal_${delivery.name}_renders_no_status_text', (
        tester,
      ) async {
        await _pump(tester, delivery, onRetry: () {}, onManual: () {});
        expect(find.byKey(const Key('chat-note-status')), findsNothing);
        for (final text in _oldStatus) {
          expect(find.textContaining(text), findsNothing, reason: text);
        }
        expect(find.text('没发出去'), findsNothing);
        expect(find.text('等联网后发送'), findsNothing);
        expect(find.text('重试'), findsNothing);
        // Only the handwritten time is under the note.
        expect(find.byKey(const Key('chat-note-time')), findsOneWidget);
      });
    }

    testWidgets('pending_while_offline_says_wait_for_network', (tester) async {
      await _pump(tester, ChatDelivery.pending, online: false);
      final line = find.byKey(const Key('chat-note-status'));
      expect(line, findsOneWidget);
      expect(
        find.descendant(of: line, matching: find.text('等联网后发送')),
        findsOneWidget,
      );
      expect(find.text('重试'), findsNothing);
    });

    testWidgets('waiting_ai_while_offline_still_says_nothing', (tester) async {
      await _pump(tester, ChatDelivery.waitingAi, online: false);
      expect(find.byKey(const Key('chat-note-status')), findsNothing);
    });

    testWidgets('failed_says_not_sent_with_a_44_retry_link', (tester) async {
      var retries = 0;
      await _pump(tester, ChatDelivery.failed, onRetry: () => retries++);
      final line = find.byKey(const Key('chat-note-status'));
      expect(
        find.descendant(of: line, matching: find.text('没发出去')),
        findsOneWidget,
      );
      final retry = find.descendant(of: line, matching: find.text('重试'));
      final tap = find.ancestor(of: retry, matching: find.byType(InkWell));
      expect(tester.getSize(tap).height, greaterThanOrEqualTo(44));
      expect(
        tester.getRect(line).top,
        greaterThanOrEqualTo(_noteBottom(tester)),
      );
      await tester.tap(retry);
      expect(retries, 1);
    });

    testWidgets('english_lines', (tester) async {
      await _pump(tester, ChatDelivery.failed, onRetry: () {}, locale: 'en');
      expect(find.text('Not sent'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await _pump(tester, ChatDelivery.pending, online: false, locale: 'en');
      expect(find.text('Sends when back online'), findsOneWidget);
    });

    testWidgets('catalog_waiting_and_pending_are_quiet', (tester) async {
      for (final state in ['user_waiting_ai', 'user_pending', 'thinking']) {
        await pumpC3(
          tester,
          child: C5Preview(key: ValueKey(state), state: state),
        );
        expect(
          find.byKey(const Key('chat-note-status')),
          findsNothing,
          reason: state,
        );
        expect(find.text('待 AI 处理'), findsNothing, reason: state);
      }
    });
  });

  group('long-press menu', () {
    testWidgets('pending_ai_menu_offers_copy_and_manual_fill', (tester) async {
      var manual = 0;
      await _pump(
        tester,
        ChatDelivery.waitingAi,
        onRetry: () {},
        onManual: () => manual++,
      );
      await _longPress(tester);
      expect(_menuItem('复制'), findsOneWidget);
      expect(_menuItem('改为手动填写'), findsOneWidget);
      expect(_menuItem('重试'), findsNothing);
      final row = find.byKey(const ValueKey('chat-note-menu-manual'));
      expect(tester.getSize(row).height, greaterThanOrEqualTo(44));
      await tester.tap(_menuItem('改为手动填写'));
      await tester.pumpAndSettle();
      expect(manual, 1);
      expect(find.byKey(const Key('chat-note-menu')), findsNothing);
    });

    testWidgets('failed_menu_offers_retry', (tester) async {
      var retries = 0;
      await _pump(
        tester,
        ChatDelivery.failed,
        onRetry: () => retries++,
        onManual: () {},
      );
      await _longPress(tester);
      expect(_menuItem('复制'), findsOneWidget);
      expect(_menuItem('重试'), findsOneWidget);
      expect(_menuItem('改为手动填写'), findsOneWidget);
      await tester.tap(_menuItem('重试'));
      await tester.pumpAndSettle();
      expect(retries, 1);
    });

    testWidgets('answered_menu_only_copies', (tester) async {
      await _pump(
        tester,
        ChatDelivery.complete,
        onRetry: () {},
        onManual: () {},
      );
      await _longPress(tester);
      expect(_menuItem('复制'), findsOneWidget);
      expect(_menuItem('重试'), findsNothing);
      expect(_menuItem('改为手动填写'), findsNothing);
    });

    testWidgets('copy_puts_my_text_on_the_clipboard', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _pump(tester, ChatDelivery.waitingAi);
      await _longPress(tester);
      await tester.tap(_menuItem('复制'));
      await tester.pumpAndSettle();
      expect(copied, '午饭 68');
      expect(find.text('已复制'), findsOneWidget);
    });

    testWidgets('read_only_ledger_greys_manual_fill', (tester) async {
      await _pump(tester, ChatDelivery.waitingAi);
      await _longPress(tester);
      expect(_menuItem('改为手动填写'), findsOneWidget);
      final row = tester.widget<InkWell>(
        find.byKey(const ValueKey('chat-note-menu-manual')),
      );
      expect(row.onTap, isNull);
    });

    testWidgets('screen_readers_get_the_menu_as_custom_actions', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var manual = 0;
      var retries = 0;
      await _pump(
        tester,
        ChatDelivery.failed,
        onRetry: () => retries++,
        onManual: () => manual++,
      );
      final node = tester.getSemantics(
        find.byKey(const Key('chat-note-actions')),
      );
      final data = node.getSemanticsData();
      expect(data.hasAction(SemanticsAction.longPress), isTrue);
      expect(data.hasAction(SemanticsAction.customAction), isTrue);
      // The long-press hint is an extra overriding action without a label.
      final ids = [
        for (final id in data.customSemanticsActionIds!)
          if (CustomSemanticsAction.getAction(id)!.label != null) id,
      ];
      final labels = [
        for (final id in ids) CustomSemanticsAction.getAction(id)!.label,
      ];
      expect(
        data.customSemanticsActionIds!.any(
          (id) =>
              CustomSemanticsAction.getAction(id)!.hint == '更多操作' &&
              CustomSemanticsAction.getAction(id)!.action ==
                  SemanticsAction.longPress,
        ),
        isTrue,
      );
      expect(labels, ['复制', '重试', '改为手动填写']);
      node.owner!
        ..performAction(
          node.id,
          SemanticsAction.customAction,
          ids[labels.indexOf('改为手动填写')],
        )
        ..performAction(
          node.id,
          SemanticsAction.customAction,
          ids[labels.indexOf('重试')],
        );
      await tester.pump();
      expect(manual, 1);
      expect(retries, 1);
      semantics.dispose();
    });

    testWidgets('menu_fits_at_text200', (tester) async {
      await pumpC3(
        tester,
        scale: 2,
        child: const C5Preview(state: 'user_menu'),
      );
      expect(tester.takeException(), isNull);
      expect(_menuItem('复制'), findsOneWidget);
      expect(_menuItem('改为手动填写'), findsOneWidget);
    });
  });
}

double _noteBottom(WidgetTester tester) =>
    tester.getRect(find.byType(NoteBubble)).bottom;
